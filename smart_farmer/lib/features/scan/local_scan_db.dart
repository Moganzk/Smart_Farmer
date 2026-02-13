import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'scan_record.dart';

/// SQLite-backed local store for [ScanRecord].
///
/// All reads/writes happen on-device — no network required.
class LocalScanDb {
  static const _dbName = 'smart_farmer_scans.db';
  static const _table = 'scans';
  static const _version = 1;

  Database? _db;

  /// Allow injecting a database instance for testing.
  LocalScanDb({Database? database}) : _db = database;

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
            uid TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            imagePath TEXT NOT NULL,
            thumbnailPath TEXT,
            cropType TEXT DEFAULT 'Unknown',
            diagnosisName TEXT NOT NULL,
            confidence REAL NOT NULL,
            severity TEXT NOT NULL DEFAULT 'medium',
            recommendations TEXT DEFAULT '',
            syncStatus TEXT DEFAULT 'local_only',
            remoteId TEXT
          )
        ''');
      },
    );
  }

  // ── CRUD ──

  Future<void> insertScan(ScanRecord record) async {
    final db = await database;
    await db.insert(
      _table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScanRecord>> getScans(String uid) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => ScanRecord.fromMap(r)).toList();
  }

  Future<ScanRecord?> getScanById(String id) async {
    final db = await database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ScanRecord.fromMap(rows.first);
  }

  Future<void> deleteScan(String id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncStatus(
    String id, {
    required String status,
    String? remoteId,
  }) async {
    final db = await database;
    final values = <String, dynamic>{'syncStatus': status};
    if (remoteId != null) values['remoteId'] = remoteId;
    await db.update(_table, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScanRecord>> getPendingScans(String uid) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'uid = ? AND (syncStatus = ? OR syncStatus = ?)',
      whereArgs: [uid, 'pending', 'failed'],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => ScanRecord.fromMap(r)).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
