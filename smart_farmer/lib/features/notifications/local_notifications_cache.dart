import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'notifications_repository.dart';

/// SQLite-backed local cache for [AppNotification] documents.
///
/// Provides offline access, unread count, and mark-as-read support.
class LocalNotificationsCache {
  static const _dbName = 'smart_farmer_notifications.db';
  static const _table = 'notifications';
  static const _version = 1;

  Database? _db;

  /// Allow injecting a database instance for testing.
  LocalNotificationsCache({Database? database}) : _db = database;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Replace the entire cache with [items].
  Future<void> replaceAll(List<AppNotification> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_table);
      for (final item in items) {
        await txn.insert(
          _table,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Insert or update a single notification.
  Future<void> insertOne(AppNotification item) async {
    final db = await database;
    await db.insert(
      _table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Return all cached notifications, newest first.
  Future<List<AppNotification>> getCachedNotifications() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map((r) => AppNotification.fromMap(r)).toList();
  }

  /// Return the count of unread notifications.
  Future<int> unreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE read = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark a notification as read locally.
  Future<void> markAsRead(String id) async {
    final db = await database;
    await db.update(_table, {'read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all cached notifications.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_table);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
