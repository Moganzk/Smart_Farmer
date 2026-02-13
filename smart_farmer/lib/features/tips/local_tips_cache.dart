import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'tips_repository.dart';

/// SQLite-backed local cache for [Tip] documents.
///
/// Tips fetched from Firestore are stored locally so they remain
/// accessible offline.
class LocalTipsCache {
  static const _dbName = 'smart_farmer_tips.db';
  static const _table = 'tips';
  static const _version = 1;

  Database? _db;

  /// Allow injecting a database instance for testing.
  LocalTipsCache({Database? database}) : _db = database;

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
            category TEXT NOT NULL DEFAULT 'General',
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Replace the entire cache with [tips].
  Future<void> replaceAll(List<Tip> tips) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_table);
      for (final tip in tips) {
        await txn.insert(
          _table,
          tip.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Return all cached tips, optionally filtered by [category].
  Future<List<Tip>> getCachedTips({String? category}) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: category != null ? 'category = ?' : null,
      whereArgs: category != null ? [category] : null,
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => Tip.fromMap(r)).toList();
  }

  /// Return distinct cached categories.
  Future<List<String>> getCachedCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM $_table ORDER BY category',
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
