import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../notifications/notifications_service.dart';
import 'ai_diagnosis_service.dart';
import 'local_scan_db.dart';
import 'scan_record.dart';
import 'scan_sync_service.dart';

enum ScanFlowStatus { idle, picking, analyzing, saving, done, error }

/// Orchestrates: pick image → AI diagnose → save local → optional sync.
class ScanFlowController extends ChangeNotifier {
  final LocalScanDb _db;
  final AiDiagnosisProvider _ai;
  final ScanSyncService? _sync;
  final NotificationsService? _notifications;
  final String uid;

  ScanFlowController({
    required LocalScanDb db,
    required AiDiagnosisProvider ai,
    ScanSyncService? sync,
    NotificationsService? notifications,
    required this.uid,
  }) : _db = db,
       _ai = ai,
       _sync = sync,
       _notifications = notifications;

  ScanFlowStatus _status = ScanFlowStatus.idle;
  ScanRecord? _lastRecord;
  String? _error;

  ScanFlowStatus get status => _status;
  ScanRecord? get lastRecord => _lastRecord;
  String? get error => _error;

  /// Run the full diagnosis flow on an image file.
  Future<void> analyzeImage(File imageFile) async {
    _status = ScanFlowStatus.analyzing;
    _error = null;
    notifyListeners();

    DiagnosisResult result;
    String syncStatus;
    String? debugReason;

    try {
      result = await _ai.diagnose(imageFile);
      syncStatus = 'pending'; // will try to sync
    } on AiDiagnosisException catch (e) {
      // AI failed — save as unanalyzed
      debugReason = e.message;
      result = DiagnosisResult.unanalyzed(debugReason: debugReason);
      syncStatus = 'local_only';
      _error = e.message;
    } catch (e) {
      debugReason = e.toString();
      result = DiagnosisResult.unanalyzed(debugReason: debugReason);
      syncStatus = 'local_only';
      _error = 'Unable to analyze. Saved for later.';
    }

    // Save locally — always
    _status = ScanFlowStatus.saving;
    notifyListeners();

    final record = ScanRecord(
      id: const Uuid().v4(),
      uid: uid,
      createdAt: DateTime.now(),
      imagePath: imageFile.path,
      diagnosisName: result.diagnosisName,
      confidence: result.confidence,
      severity: result.severity,
      recommendations: result.recommendations,
      syncStatus: syncStatus,
      debugReason: debugReason,
    );

    await _db.insertScan(record);
    _lastRecord = record;
    _status = ScanFlowStatus.done;
    notifyListeners();

    // Auto-generate notification
    _notifications?.onScanSaved(diagnosisName: record.diagnosisName);

    // Background sync (non-blocking)
    if (syncStatus == 'pending' && _sync != null) {
      _sync.trySync(record); // fire-and-forget
    }
  }

  /// Load history for the current user.
  Future<List<ScanRecord>> getHistory() => _db.getScans(uid);

  /// Get a single record.
  Future<ScanRecord?> getRecord(String id) => _db.getScanById(id);

  /// Delete a scan.
  Future<void> deleteScan(String id) async {
    await _db.deleteScan(id);
    notifyListeners();
  }

  void reset() {
    _status = ScanFlowStatus.idle;
    _lastRecord = null;
    _error = null;
    notifyListeners();
  }
}
