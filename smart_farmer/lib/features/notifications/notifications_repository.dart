import 'package:cloud_firestore/cloud_firestore.dart';

/// A notification document from `notifications/{uid}/items`.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppNotification(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// SQLite / cache serialisation.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'read': read ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    read: (m['read'] is int)
        ? (m['read'] as int) == 1
        : (m['read'] as bool? ?? false),
    createdAt:
        DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
  );
}

/// Reads per-user notifications from `notifications/{uid}/items`.
class NotificationsRepository {
  final FirebaseFirestore _db;

  NotificationsRepository({FirebaseFirestore? firestore})
    : _db =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: FirebaseFirestore.instance.app,
            databaseId: 'smart-farmer-kenya',
          );

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('notifications').doc(uid).collection('items');

  /// Fetch notifications for [uid], newest first.
  Future<List<AppNotification>> fetchNotifications(String uid) async {
    final snapshot = await _items(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((d) => AppNotification.fromDoc(d)).toList();
  }

  /// Mark a single notification as read in Firestore.
  Future<void> markAsRead(String uid, String notificationId) async {
    await _items(uid).doc(notificationId).update({'read': true});
  }

  /// Write a notification to Firestore (for local→remote sync).
  Future<void> writeNotification(String uid, AppNotification n) async {
    await _items(uid).doc(n.id).set({
      'title': n.title,
      'body': n.body,
      'read': n.read,
      'createdAt': Timestamp.fromDate(n.createdAt),
    });
  }

  /// Delete all notifications for [uid].
  Future<void> clearAll(String uid) async {
    final snapshot = await _items(uid).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
