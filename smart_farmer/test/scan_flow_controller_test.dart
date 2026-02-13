import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_farmer/features/scan/ai_diagnosis_service.dart';
import 'package:smart_farmer/features/scan/local_scan_db.dart';
import 'package:smart_farmer/features/scan/scan_flow_controller.dart';
import 'package:smart_farmer/features/scan/scan_record.dart';

/// Fake AI provider for testing.
class FakeAiSuccess implements AiDiagnosisProvider {
  @override
  Future<DiagnosisResult> diagnose(File imageFile) async {
    return const DiagnosisResult(
      diagnosisName: 'Test Blight',
      confidence: 0.9,
      severity: 'high',
      recommendations: ['Spray fungicide', 'Remove leaves'],
    );
  }
}

class FakeAiFailure implements AiDiagnosisProvider {
  @override
  Future<DiagnosisResult> diagnose(File imageFile) async {
    throw const AiDiagnosisException('Network error');
  }
}

void main() {
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

  group('ScanFlowController', () {
    test('analyzeImage saves record on AI success', () async {
      final ctrl = ScanFlowController(
        db: scanDb,
        ai: FakeAiSuccess(),
        uid: 'user1',
      );

      // Create a temp file to simulate an image
      final tmpDir = Directory.systemTemp.createTempSync('scan_test_');
      final imgFile = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]); // minimal JPEG header

      await ctrl.analyzeImage(imgFile);

      expect(ctrl.status, ScanFlowStatus.done);
      expect(ctrl.lastRecord, isNotNull);
      expect(ctrl.lastRecord!.diagnosisName, 'Test Blight');
      expect(ctrl.lastRecord!.confidence, 0.9);
      expect(ctrl.lastRecord!.severity, 'high');
      expect(ctrl.lastRecord!.syncStatus, 'pending');

      // Verify it was saved to DB
      final scans = await scanDb.getScans('user1');
      expect(scans.length, 1);
      expect(scans.first.diagnosisName, 'Test Blight');

      // Cleanup
      tmpDir.deleteSync(recursive: true);
    });

    test('analyzeImage saves Unanalyzed on AI failure', () async {
      final ctrl = ScanFlowController(
        db: scanDb,
        ai: FakeAiFailure(),
        uid: 'user1',
      );

      final tmpDir = Directory.systemTemp.createTempSync('scan_test_');
      final imgFile = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      await ctrl.analyzeImage(imgFile);

      expect(ctrl.status, ScanFlowStatus.done);
      expect(ctrl.lastRecord, isNotNull);
      expect(ctrl.lastRecord!.diagnosisName, 'Unanalyzed');
      expect(ctrl.lastRecord!.confidence, 0.0);
      expect(ctrl.lastRecord!.syncStatus, 'local_only');
      expect(ctrl.lastRecord!.debugReason, isNotNull);
      expect(ctrl.lastRecord!.debugReason, contains('Network error'));
      expect(ctrl.error, isNotNull);

      // Still saved to DB
      final scans = await scanDb.getScans('user1');
      expect(scans.length, 1);

      tmpDir.deleteSync(recursive: true);
    });

    test('getHistory returns records', () async {
      final ctrl = ScanFlowController(
        db: scanDb,
        ai: FakeAiSuccess(),
        uid: 'user1',
      );

      // Insert directly
      await scanDb.insertScan(
        ScanRecord(
          id: 'x',
          uid: 'user1',
          createdAt: DateTime(2026, 1, 1),
          imagePath: '/tmp/x.jpg',
          diagnosisName: 'Rust',
          confidence: 0.7,
          severity: 'medium',
          recommendations: ['Spray'],
        ),
      );

      final history = await ctrl.getHistory();
      expect(history.length, 1);
      expect(history.first.diagnosisName, 'Rust');
    });

    test('deleteScan removes from DB', () async {
      final ctrl = ScanFlowController(
        db: scanDb,
        ai: FakeAiSuccess(),
        uid: 'user1',
      );

      await scanDb.insertScan(
        ScanRecord(
          id: 'del',
          uid: 'user1',
          createdAt: DateTime.now(),
          imagePath: '/tmp/del.jpg',
          diagnosisName: 'Test',
          confidence: 0.5,
          severity: 'low',
          recommendations: [],
        ),
      );

      await ctrl.deleteScan('del');
      final result = await scanDb.getScanById('del');
      expect(result, isNull);
    });

    test('reset clears status', () {
      final ctrl = ScanFlowController(
        db: scanDb,
        ai: FakeAiSuccess(),
        uid: 'user1',
      );

      ctrl.reset();
      expect(ctrl.status, ScanFlowStatus.idle);
      expect(ctrl.lastRecord, isNull);
      expect(ctrl.error, isNull);
    });
  });
}
