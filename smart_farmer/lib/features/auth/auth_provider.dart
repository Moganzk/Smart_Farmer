import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/logger.dart';
import 'user_service.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final UserService? _userService;
  final bool _testMode;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;

  AuthProvider({FirebaseAuth? auth, UserService? userService})
    : _auth = auth ?? FirebaseAuth.instance,
      _userService = userService ?? UserService(),
      _testMode = false;

  /// Creates an AuthProvider without Firebase dependencies, for widget tests.
  AuthProvider.forTesting()
    : _auth = null,
      _userService = null,
      _testMode = true;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  User? get currentUser => _testMode ? null : _auth?.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// True when auth succeeded but Firestore profile write failed.
  bool _profileSyncPending = false;
  bool get profileSyncPending => _profileSyncPending;

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.initial;
    }
    notifyListeners();
  }

  // ── Phone OTP ──

  Future<void> sendOtp(String phoneNumber) async {
    _setStatus(AuthStatus.loading);
    _errorMessage = null;

    try {
      await _auth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential, phone: phoneNumber);
        },
        verificationFailed: (FirebaseAuthException e) {
          _setError(_mapFirebaseError(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _setStatus(AuthStatus.otpSent);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Failed to send OTP. Please try again.');
    }
  }

  Future<void> verifyOtp(String smsCode, {String? phone}) async {
    if (_verificationId == null) {
      _setError('Verification session expired. Please resend OTP.');
      return;
    }

    _setStatus(AuthStatus.loading);
    _errorMessage = null;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _signInWithCredential(credential, phone: phone);
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Verification failed. Please try again.');
    }
  }

  Future<void> _signInWithCredential(
    AuthCredential credential, {
    String? phone,
  }) async {
    try {
      final result = await _auth!.signInWithCredential(credential);
      if (result.user != null) {
        try {
          await _userService!.createProfileIfAbsent(
            uid: result.user!.uid,
            phone: phone ?? result.user!.phoneNumber,
          );
          _profileSyncPending = false;
        } catch (e) {
          // Auth succeeded but profile write failed — still authenticate
          _profileSyncPending = true;
          if (kDebugMode) {
            Log.w('AuthProvider', 'Profile write failed (will retry): $e');
          }
        }
        _setStatus(AuthStatus.authenticated);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    }
  }

  // ── Email/Password ──

  Future<void> signInEmail(String email, String password) async {
    _setStatus(AuthStatus.loading);
    _errorMessage = null;

    try {
      final result = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        try {
          await _userService!.createProfileIfAbsent(
            uid: result.user!.uid,
            email: email,
          );
          _profileSyncPending = false;
        } catch (e) {
          _profileSyncPending = true;
          if (kDebugMode) {
            Log.w('AuthProvider', 'Profile write failed (will retry): $e');
          }
        }
        _setStatus(AuthStatus.authenticated);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Sign in failed. Please try again.');
    }
  }

  Future<void> signUpEmail(String email, String password) async {
    _setStatus(AuthStatus.loading);
    _errorMessage = null;

    try {
      final result = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        try {
          await _userService!.createProfileIfAbsent(
            uid: result.user!.uid,
            email: email,
          );
          _profileSyncPending = false;
        } catch (e) {
          _profileSyncPending = true;
          if (kDebugMode) {
            Log.w('AuthProvider', 'Profile write failed (will retry): $e');
          }
        }
        _setStatus(AuthStatus.authenticated);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Registration failed. Please try again.');
    }
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    await _auth?.signOut();
    _verificationId = null;
    _resendToken = null;
    _status = AuthStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Error mapping ──

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'session-expired':
        return 'OTP session expired. Please resend.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication error. Please try again.';
    }
  }
}
