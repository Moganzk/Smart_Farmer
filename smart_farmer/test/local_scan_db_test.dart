import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_farmer/features/scan/local_scan_db.dart';
import 'package:smart_farmer/features/scan/scan_record.dart';

/// Tests LocalScanDb using sqflite_common_ffi (in-memory database).
void main() {
  // Use ffi for desktop/CI test environments
  sqfliteFfiInit();

  late Database db;
  late LocalScanDb scanDb;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE scans (
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
      ),
    );
    scanDb = LocalScanDb(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  ScanRecord _makeRecord({
    String id = 'r1',
    String uid = 'user1',
    DateTime? createdAt,
    String diagnosisName = 'Late Blight',
    double confidence = 0.85,
    String severity = 'high',
    String syncStatus = 'local_only',
  }) {
    return ScanRecord(
      id: id,
      uid: uid,
      createdAt: createdAt ?? DateTime(2026, 2, 13, 10, 0),
      imagePath: '/tmp/$id.jpg',
      diagnosisName: diagnosisName,
      confidence: confidence,
      severity: severity,
      recommendations: ['Apply fungicide'],
      syncStatus: syncStatus,
    );
  }

  group('LocalScanDb', () {
    test('insert and fetch by id', () async {
      final record = _makeRecord();
      await scanDb.insertScan(record);

      final fetched = await scanDb.getScanById('r1');
      expect(fetched, isNotNull);
      expect(fetched!.diagnosisName, 'Late Blight');
      expect(fetched.confidence, 0.85);
    });

    test('getScans returns records ordered by createdAt DESC', () async {
      await scanDb.insertScan(
        _makeRecord(id: 'a', createdAt: DateTime(2026, 1, 1)),
      );
      await scanDb.insertScan(
        _makeRecord(id: 'b', createdAt: DateTime(2026, 2, 1)),
      );
      await scanDb.insertScan(
        _makeRecord(id: 'c', createdAt: DateTime(2026, 3, 1)),
      );

      final scans = await scanDb.getScans('user1');
      expect(scans.length, 3);
      expect(scans[0].id, 'c'); // newest first
      expect(scans[2].id, 'a'); // oldest last
    });

    test('getScans filters by uid', () async {
      await scanDb.insertScan(_makeRecord(id: 'x', uid: 'alice'));
      await scanDb.insertScan(_makeRecord(id: 'y', uid: 'bob'));

      final alice = await scanDb.getScans('alice');
      expect(alice.length, 1);
      expect(alice[0].id, 'x');
    });

    test('deleteScan removes record', () async {
      await scanDb.insertScan(_makeRecord());

      await scanDb.deleteScan('r1');
      final fetched = await scanDb.getScanById('r1');
      expect(fetched, isNull);
    });

    test('updateSyncStatus changes status and remoteId', () async {
      await scanDb.insertScan(_makeRecord(syncStatus: 'pending'));

      await scanDb.updateSyncStatus('r1', status: 'synced', remoteId: 'fs-abc');

      final fetched = await scanDb.getScanById('r1');
      expect(fetched!.syncStatus, 'synced');
      expect(fetched.remoteId, 'fs-abc');
    });

    test('getPendingScans returns pending and failed', () async {
      await scanDb.insertScan(_makeRecord(id: 'a', syncStatus: 'pending'));
      await scanDb.insertScan(_makeRecord(id: 'b', syncStatus: 'failed'));
      await scanDb.insertScan(_makeRecord(id: 'c', syncStatus: 'synced'));
      await scanDb.insertScan(_makeRecord(id: 'd', syncStatus: 'local_only'));

      final pending = await scanDb.getPendingScans('user1');
      expect(pending.length, 2);
      expect(pending.map((r) => r.id).toSet(), {'a', 'b'});
    });

    test('insertScan replaces on conflict', () async {
      await scanDb.insertScan(_makeRecord(diagnosisName: 'V1'));
      await scanDb.insertScan(_makeRecord(diagnosisName: 'V2'));

      final fetched = await scanDb.getScanById('r1');
      expect(fetched!.diagnosisName, 'V2');
    });
  });
}
