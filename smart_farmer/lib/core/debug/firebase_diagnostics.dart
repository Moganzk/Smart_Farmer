import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// Result of a Firestore connectivity check.
class FirebaseDiagnosticsResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;

  const FirebaseDiagnosticsResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  static const ok = FirebaseDiagnosticsResult(success: true);
}

/// Runs a deterministic Firebase + Firestore diagnostic check.
///
/// Logs Firebase app name, project ID, current user, and attempts
/// a Firestore read/write to `diagnostics/{uid}`.
/// Returns a [FirebaseDiagnosticsResult] with error details on failure.
Future<FirebaseDiagnosticsResult> runFirebaseDiagnostics() async {
  if (!kDebugMode) return FirebaseDiagnosticsResult.ok;

  try {
    // 1. Firebase App info
    final app = Firebase.app();
    Log.i('FirebaseDiag', 'App name: ${app.name}');
    Log.i('FirebaseDiag', 'Project ID: ${app.options.projectId}');

    // 2. Current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Log.i('FirebaseDiag', 'User UID: ${user.uid}');
      Log.i('FirebaseDiag', 'User email: ${user.email ?? "(none)"}');
      Log.i('FirebaseDiag', 'User phone: ${user.phoneNumber ?? "(none)"}');
    } else {
      Log.w('FirebaseDiag', 'No authenticated user');
    }

    // 3. Firestore read/write test
    final uid = user?.uid ?? '_anon_diag';
    final db = FirebaseFirestore.instanceFor(
      app: app,
      databaseId: 'smart-farmer-kenya',
    );
    final docRef = db.collection('diagnostics').doc(uid);

    // Write
    await docRef.set({
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'ok',
    });
    Log.i('FirebaseDiag', 'Firestore WRITE to diagnostics/$uid: SUCCESS');

    // Read back
    final snap = await docRef.get();
    if (snap.exists) {
      Log.i('FirebaseDiag', 'Firestore READ diagnostics/$uid: SUCCESS');
    } else {
      Log.w('FirebaseDiag', 'Firestore READ returned no document');
    }

    return FirebaseDiagnosticsResult.ok;
  } on FirebaseException catch (e) {
    final code = e.code;
    final msg = e.message ?? e.toString();
    Log.e('FirebaseDiag', 'Firebase error [$code]: $msg');
    return FirebaseDiagnosticsResult(
      success: false,
      errorCode: code,
      errorMessage: msg,
    );
  } catch (e) {
    final msg = e.toString();
    Log.e('FirebaseDiag', 'Unexpected error: $msg');
    return FirebaseDiagnosticsResult(
      success: false,
      errorCode: 'unknown',
      errorMessage: msg,
    );
  }
}
