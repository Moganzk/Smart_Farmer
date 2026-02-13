import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/logger.dart';
import 'local_notifications_cache.dart';
import 'notifications_repository.dart';

/// Category of auto-generated notification.
enum NotificationCategory {
  scanSaved,
  syncSuccess,
  syncFailed,
  weatherAlert,
  general,
}

/// Service that auto-generates local notifications from app events.
///
/// Notifications are stored locally first (SQLite), then optionally synced
/// to Firestore in the background. The UI listens via [stream] for live
/// updates.
class NotificationsService extends ChangeNotifier {
  final LocalNotificationsCache _cache;
  final NotificationsRepository? _remote;
  final String? uid;

  List<AppNotification> _items = [];
  bool _loading = false;
  bool _isOffline = false;
  String? _error;

  /// Stream controller for push-based updates.
  final _controller = StreamController<List<AppNotification>>.broadcast();

  NotificationsService({
    required LocalNotificationsCache cache,
    NotificationsRepository? remote,
    this.uid,
  }) : _cache = cache,
       _remote = remote;

  // ── Getters ──

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  Stream<List<AppNotification>> get stream => _controller.stream;
  LocalNotificationsCache get cacheForReinit => _cache;

  int get unreadCount => _items.where((n) => !n.read).length;

  // ── Load ──

  /// Initial load: try Firestore first, fallback to cache.
  Future<void> load() async {
    if (uid == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (_remote != null) {
        final remoteItems = await _remote.fetchNotifications(uid!);
        // Merge remote with any local-only items not yet in Firestore
        final localItems = await _cache.getCachedNotifications();
        final remoteIds = remoteItems.map((i) => i.id).toSet();
        final localOnly = localItems.where((i) => !remoteIds.contains(i.id));
        _items = [...remoteItems, ...localOnly];
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _cache.replaceAll(_items);
        _isOffline = false;
      } else {
        _items = await _cache.getCachedNotifications();
        _isOffline = true;
      }
    } catch (e) {
      if (kDebugMode) Log.w('NotifService', 'Remote load failed: $e');
      _error = 'Firestore read failed';
      _items = await _cache.getCachedNotifications();
      _isOffline = true;
    }

    _loading = false;
    _controller.add(_items);
    notifyListeners();
  }

  // ── Create local notification from app events ──

  /// Create a notification and persist it locally immediately.
  Future<AppNotification> createNotification({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.general,
  }) async {
    final notification = AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      read: false,
      createdAt: DateTime.now(),
    );

    // Prepend to local list
    _items.insert(0, notification);
    await _cache.insertOne(notification);

    if (kDebugMode) {
      Log.i('NotifService', 'Created: ${category.name} → "$title"');
    }

    // Push update to listeners
    _controller.add(_items);
    notifyListeners();

    // Try to sync to Firestore in background (fire-and-forget)
    _trySyncToRemote(notification);

    return notification;
  }

  // ── Convenience creators for specific events ──

  /// Call after a scan is successfully saved locally.
  Future<void> onScanSaved({required String diagnosisName}) {
    return createNotification(
      title: 'Scan Saved',
      body: 'Diagnosis "$diagnosisName" has been saved successfully.',
      category: NotificationCategory.scanSaved,
    ).then((_) {});
  }

  /// Call after scan sync to Firestore succeeds.
  Future<void> onSyncSuccess({required String scanId}) {
    return createNotification(
      title: 'Sync Complete',
      body: 'Scan $scanId synced to cloud successfully.',
      category: NotificationCategory.syncSuccess,
    ).then((_) {});
  }

  /// Call when scan sync to Firestore fails.
  Future<void> onSyncFailed({required String scanId, String? reason}) {
    return createNotification(
      title: 'Sync Failed',
      body:
          'Could not sync scan $scanId.${reason != null ? ' $reason' : ''} '
          'Will retry later.',
      category: NotificationCategory.syncFailed,
    ).then((_) {});
  }

  /// Call when weather indicates severe conditions.
  Future<void> onWeatherAlert({
    required String condition,
    required String location,
  }) {
    return createNotification(
      title: 'Weather Alert',
      body:
          '$condition in $location. Take necessary precautions for your crops.',
      category: NotificationCategory.weatherAlert,
    ).then((_) {});
  }

  // ── Mark as read ──

  Future<void> markAsRead(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (item.read) return;

    _items[index] = item.copyWith(read: true);
    await _cache.markAsRead(item.id);

    // Best-effort Firestore update
    if (_remote != null && uid != null) {
      try {
        await _remote.markAsRead(uid!, item.id);
      } catch (_) {}
    }

    _controller.add(_items);
    notifyListeners();
  }

  // ── Clear all ──

  Future<void> clearAll() async {
    await _cache.clearAll();
    if (_remote != null && uid != null) {
      try {
        await _remote.clearAll(uid!);
      } catch (_) {}
    }
    _items = [];
    _controller.add(_items);
    notifyListeners();
  }

  // ── Private ──

  /// Try to push a notification to Firestore (best-effort).
  Future<void> _trySyncToRemote(AppNotification notification) async {
    if (_remote == null || uid == null) return;
    try {
      // We need to add a write method to the repository
      await _remote.writeNotification(uid!, notification);
    } catch (e) {
      if (kDebugMode) {
        Log.w('NotifService', 'Could not sync notification to Firestore: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
