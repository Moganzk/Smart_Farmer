import 'package:flutter/foundation.dart';
import '../scan/local_scan_db.dart';
import '../scan/scan_record.dart';

/// ChangeNotifier that holds the scan history list.
///
/// Avoids full-screen rebuilds by exposing [records] which can be
/// diffed by the UI layer.
class HistoryNotifier extends ChangeNotifier {
  final LocalScanDb _db;
  final String uid;

  List<ScanRecord> _records = [];
  bool _initialLoading = true;
  String? _error;

  HistoryNotifier({required LocalScanDb db, required this.uid}) : _db = db {
    load();
  }

  List<ScanRecord> get records => _records;
  bool get initialLoading => _initialLoading;
  String? get error => _error;

  Future<void> load() async {
    try {
      final scans = await _db.getScans(uid);
      _records = scans;
      _initialLoading = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _initialLoading = false;
    }
    notifyListeners();
  }

  /// Smooth refresh that does NOT blank the list.
  Future<void> refresh() async {
    try {
      final scans = await _db.getScans(uid);
      _records = scans;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}
