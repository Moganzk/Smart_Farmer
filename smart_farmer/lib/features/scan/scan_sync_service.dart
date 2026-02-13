import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../notifications/notifications_service.dart';
import 'local_scan_db.dart';
import 'scan_record.dart';

/// Non-blocking Firestore + Storage sync for scan records.
///
/// Works on a best-effort basis — never throws to the UI.
class ScanSyncService {
  final LocalScanDb _db;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final NotificationsService? _notifications;

  ScanSyncService({
    required LocalScanDb db,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    NotificationsService? notifications,
  }) : _db = db,
       _firestore =
           firestore ??
           FirebaseFirestore.instanceFor(
             app: FirebaseFirestore.instance.app,
             databaseId: 'smart-farmer-kenya',
           ),
       _storage = storage ?? FirebaseStorage.instance,
       _notifications = notifications;

  /// Try to sync a single record. Updates local syncStatus.
  Future<void> trySync(ScanRecord record) async {
    try {
      // 1) Upload image to Storage
      final imageFile = File(record.imagePath);
      String? downloadUrl;
      if (await imageFile.exists()) {
        final ref = _storage.ref('scans/${record.uid}/${record.id}.jpg');
        await ref.putFile(imageFile);
        downloadUrl = await ref.getDownloadURL();
      }

      // 2) Write to Firestore
      final docRef = _firestore
          .collection('users')
          .doc(record.uid)
          .collection('scans')
          .doc(record.id);

      final data = record.toFirestore();
      if (downloadUrl != null) data['imageUrl'] = downloadUrl;

      await docRef.set(data);

      // 3) Update local status
      await _db.updateSyncStatus(
        record.id,
        status: 'synced',
        remoteId: docRef.id,
      );

      // Notify user of successful sync
      _notifications?.onSyncSuccess(scanId: record.id.substring(0, 8));
    } catch (e) {
      // Mark as failed — will be retried later
      await _db.updateSyncStatus(record.id, status: 'failed');

      // Notify user of failed sync
      _notifications?.onSyncFailed(
        scanId: record.id.substring(0, 8),
        reason: e.toString(),
      );
    }
  }

  /// Retry all pending/failed scans for a user.
  Future<void> retryFailed(String uid) async {
    final pending = await _db.getPendingScans(uid);
    for (final record in pending) {
      await trySync(record);
    }
  }
}
