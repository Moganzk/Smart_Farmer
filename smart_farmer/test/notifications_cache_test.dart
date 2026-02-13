import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_farmer/features/notifications/notifications_repository.dart';
import 'package:smart_farmer/features/notifications/local_notifications_cache.dart';

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

  AppNotification _makeNotif({
    String id = 'n1',
    String title = 'Welcome',
    String body = 'Welcome to Smart Farmer!',
    bool read = false,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      read: read,
      createdAt: createdAt ?? DateTime(2026, 2, 13),
    );
  }

  // ── Model tests ──

  group('AppNotification model extensions', () {
    test('toMap produces correct keys and types', () {
      final n = _makeNotif(read: false);
      final map = n.toMap();
      expect(map['id'], 'n1');
      expect(map['title'], 'Welcome');
      expect(map['read'], 0); // int for SQLite
    });

    test('fromMap round-trips correctly', () {
      final n = _makeNotif(read: true);
      final restored = AppNotification.fromMap(n.toMap());
      expect(restored.id, n.id);
      expect(restored.title, n.title);
      expect(restored.read, true);
    });

    test('copyWith toggles read flag', () {
      final n = _makeNotif(read: false);
      final marked = n.copyWith(read: true);
      expect(marked.read, true);
      expect(marked.id, n.id);
      expect(marked.title, n.title);
    });
  });

  // ── Cache tests ──

  group('LocalNotificationsCache', () {
    test('replaceAll + getCachedNotifications round-trips', () async {
      final items = [_makeNotif(id: 'n1'), _makeNotif(id: 'n2', read: true)];
      await cache.replaceAll(items);

      final result = await cache.getCachedNotifications();
      expect(result.length, 2);
    });

    test('unreadCount returns correct count', () async {
      final items = [
        _makeNotif(id: 'n1', read: false),
        _makeNotif(id: 'n2', read: true),
        _makeNotif(id: 'n3', read: false),
      ];
      await cache.replaceAll(items);

      final count = await cache.unreadCount();
      expect(count, 2);
    });

    test('markAsRead decreases unread count', () async {
      await cache.replaceAll([
        _makeNotif(id: 'n1', read: false),
        _makeNotif(id: 'n2', read: false),
      ]);

      await cache.markAsRead('n1');
      final count = await cache.unreadCount();
      expect(count, 1);
    });

    test('clearAll removes everything', () async {
      await cache.replaceAll([_makeNotif(id: 'n1')]);
      expect((await cache.getCachedNotifications()).length, 1);

      await cache.clearAll();
      expect((await cache.getCachedNotifications()).length, 0);
    });

    test('empty cache returns zero unread and empty list', () async {
      expect(await cache.unreadCount(), 0);
      expect(await cache.getCachedNotifications(), isEmpty);
    });
  });
}
