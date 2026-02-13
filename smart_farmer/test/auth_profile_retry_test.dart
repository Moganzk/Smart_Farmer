import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:smart_farmer/features/auth/auth_provider.dart';
import 'package:smart_farmer/features/auth/user_service.dart';

// ── Minimal fakes ──

class _FakeUser implements User {
  @override
  String get uid => 'test-uid-123';
  @override
  String? get phoneNumber => '+254700000000';
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  @override
  User get user => _FakeUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FirebaseAuth that always succeeds for email sign-in / sign-up.
class _SuccessAuth implements FirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _FakeUserCredential();

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _FakeUserCredential();

  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UserService that succeeds.
class _SuccessUserService implements UserService {
  int callCount = 0;

  @override
  Future<void> createProfileIfAbsent({
    String? uid,
    String? phone,
    String? email,
  }) async {
    callCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UserService that always throws (simulates Firestore down).
class _FailingUserService implements UserService {
  int callCount = 0;

  @override
  Future<void> createProfileIfAbsent({
    String? uid,
    String? phone,
    String? email,
  }) async {
    callCount++;
    throw Exception('Firestore unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Auth profile retry logic', () {
    test(
      'signInEmail succeeds and profileSyncPending=false when UserService works',
      () async {
        final auth = _SuccessAuth();
        final svc = _SuccessUserService();
        final provider = AuthProvider(auth: auth, userService: svc);

        await provider.signInEmail('test@example.com', 'pass123');

        expect(provider.status, AuthStatus.authenticated);
        expect(provider.profileSyncPending, false);
        expect(svc.callCount, 1);
        expect(provider.errorMessage, isNull);
      },
    );

    test('signInEmail still authenticates when UserService throws', () async {
      final auth = _SuccessAuth();
      final svc = _FailingUserService();
      final provider = AuthProvider(auth: auth, userService: svc);

      await provider.signInEmail('test@example.com', 'pass123');

      expect(
        provider.status,
        AuthStatus.authenticated,
        reason: 'Auth must succeed even when profile write fails',
      );
      expect(
        provider.profileSyncPending,
        true,
        reason: 'Should flag pending sync',
      );
      expect(svc.callCount, 1);
    });

    test(
      'signUpEmail succeeds and profileSyncPending=false when UserService works',
      () async {
        final auth = _SuccessAuth();
        final svc = _SuccessUserService();
        final provider = AuthProvider(auth: auth, userService: svc);

        await provider.signUpEmail('new@example.com', 'pass123');

        expect(provider.status, AuthStatus.authenticated);
        expect(provider.profileSyncPending, false);
        expect(svc.callCount, 1);
      },
    );

    test('signUpEmail still authenticates when UserService throws', () async {
      final auth = _SuccessAuth();
      final svc = _FailingUserService();
      final provider = AuthProvider(auth: auth, userService: svc);

      await provider.signUpEmail('new@example.com', 'pass123');

      expect(
        provider.status,
        AuthStatus.authenticated,
        reason: 'Auth must succeed even when profile write fails',
      );
      expect(
        provider.profileSyncPending,
        true,
        reason: 'Should flag pending sync',
      );
      expect(svc.callCount, 1);
    });

    test(
      'profileSyncPending resets on successful sign-in after failure',
      () async {
        final auth = _SuccessAuth();
        final failSvc = _FailingUserService();
        final provider = AuthProvider(auth: auth, userService: failSvc);

        // First sign-in — profile write fails
        await provider.signInEmail('test@example.com', 'pass123');
        expect(provider.profileSyncPending, true);

        // Now swap to a succeeding service
        final okSvc = _SuccessUserService();
        final provider2 = AuthProvider(auth: auth, userService: okSvc);

        await provider2.signInEmail('test@example.com', 'pass123');
        expect(provider2.profileSyncPending, false);
      },
    );
  });
}
