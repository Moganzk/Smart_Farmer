import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_farmer/features/notifications/local_notifications_cache.dart';
import 'package:smart_farmer/features/notifications/notifications_repository.dart';
import 'package:smart_farmer/features/notifications/notifications_service.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalNotificationsCache cache;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notifications (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              read INTEGER NOT NULL DEFAULT 0,
              createdAt TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    cache = LocalNotificationsCache(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationsService', () {
    test('createNotification adds to items and cache', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      final notif = await service.createNotification(
        title: 'Test',
        body: 'Test body',
      );

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Test');
      expect(service.items.first.body, 'Test body');
      expect(service.items.first.read, false);
      expect(notif.id, isNotEmpty);

      // Verify persisted to cache
      final cached = await cache.getCachedNotifications();
      expect(cached.length, 1);
      expect(cached.first.title, 'Test');

      service.dispose();
    });

    test('onScanSaved creates scan notification', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onScanSaved(diagnosisName: 'Leaf Blight');

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Scan Saved');
      expect(service.items.first.body, contains('Leaf Blight'));

      service.dispose();
    });

    test('onSyncSuccess creates sync notification', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onSyncSuccess(scanId: 'abc123');

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Sync Complete');
      expect(service.items.first.body, contains('abc123'));

      service.dispose();
    });

    test('onSyncFailed creates failure notification', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onSyncFailed(scanId: '12345678', reason: 'No internet');

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Sync Failed');
      expect(service.items.first.body, contains('12345678'));
      expect(service.items.first.body, contains('No internet'));

      service.dispose();
    });

    test('onWeatherAlert creates weather notification', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onWeatherAlert(
        condition: 'Heavy rain',
        location: 'Nairobi',
      );

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Weather Alert');
      expect(service.items.first.body, contains('Heavy rain'));
      expect(service.items.first.body, contains('Nairobi'));

      service.dispose();
    });

    test('multiple notifications ordered newest first', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onScanSaved(diagnosisName: 'First');
      await Future.delayed(const Duration(milliseconds: 10));
      await service.onScanSaved(diagnosisName: 'Second');

      expect(service.items.length, 2);
      // Newest first (prepended)
      expect(service.items[0].body, contains('Second'));
      expect(service.items[1].body, contains('First'));

      service.dispose();
    });

    test('markAsRead updates item and cache', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onScanSaved(diagnosisName: 'Test');
      expect(service.unreadCount, 1);

      await service.markAsRead(0);

      expect(service.items[0].read, true);
      expect(service.unreadCount, 0);

      // Verify cache updated
      final cached = await cache.getCachedNotifications();
      // Find the notification with matching id
      final cachedItem = cached.where((n) => n.id == service.items[0].id);
      expect(cachedItem.isNotEmpty, true);

      service.dispose();
    });

    test('clearAll removes all items', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onScanSaved(diagnosisName: 'A');
      await service.onSyncSuccess(scanId: 'B');
      expect(service.items.length, 2);

      await service.clearAll();

      expect(service.items, isEmpty);
      expect(await cache.getCachedNotifications(), isEmpty);

      service.dispose();
    });

    test('load restores from cache when no remote', () async {
      // Pre-populate cache
      final notif = AppNotification(
        id: 'cached-1',
        title: 'Cached',
        body: 'From cache',
        read: false,
        createdAt: DateTime.now(),
      );
      await cache.insertOne(notif);

      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.load();

      expect(service.items.length, 1);
      expect(service.items.first.title, 'Cached');
      expect(service.isOffline, true);

      service.dispose();
    });

    test('stream emits on notification creation', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      final emissions = <List<AppNotification>>[];
      service.stream.listen(emissions.add);

      await service.onScanSaved(diagnosisName: 'StreamTest');

      // Allow stream to propagate
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emissions, isNotEmpty);
      expect(emissions.last.length, 1);
      expect(emissions.last.first.body, contains('StreamTest'));

      service.dispose();
    });

    test('unreadCount reflects actual unread items', () async {
      final service = NotificationsService(cache: cache, uid: 'user1');

      await service.onScanSaved(diagnosisName: 'A');
      await service.onScanSaved(diagnosisName: 'B');
      await service.onScanSaved(diagnosisName: 'C');

      expect(service.unreadCount, 3);

      await service.markAsRead(0);
      expect(service.unreadCount, 2);

      await service.markAsRead(1);
      expect(service.unreadCount, 1);

      service.dispose();
    });
  });

  group('LocalNotificationsCache.insertOne', () {
    test('insertOne adds a single notification', () async {
      final notif = AppNotification(
        id: 'single-1',
        title: 'Single',
        body: 'Body',
        read: false,
        createdAt: DateTime.now(),
      );

      await cache.insertOne(notif);

      final items = await cache.getCachedNotifications();
      expect(items.length, 1);
      expect(items.first.id, 'single-1');
    });

    test('insertOne upserts on conflict', () async {
      final notif = AppNotification(
        id: 'upsert-1',
        title: 'Original',
        body: 'Body',
        read: false,
        createdAt: DateTime.now(),
      );
      await cache.insertOne(notif);

      final updated = AppNotification(
        id: 'upsert-1',
        title: 'Updated',
        body: 'New body',
        read: true,
        createdAt: DateTime.now(),
      );
      await cache.insertOne(updated);

      final items = await cache.getCachedNotifications();
      expect(items.length, 1);
      expect(items.first.title, 'Updated');
    });
  });
}
