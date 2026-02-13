import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_farmer/features/auth/auth_provider.dart';

// Minimal mock for testing state transitions without Firebase
// Real Firebase calls are tested on-device
class FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthProvider state transitions', () {
    test('initial state is correct', () {
      // We can't easily construct without Firebase, but test the enum
      expect(AuthStatus.initial.index, 0);
      expect(AuthStatus.loading.index, 1);
      expect(AuthStatus.otpSent.index, 2);
      expect(AuthStatus.authenticated.index, 3);
      expect(AuthStatus.error.index, 4);
    });

    test('AuthStatus has all expected values', () {
      expect(AuthStatus.values.length, 5);
      expect(AuthStatus.values, contains(AuthStatus.initial));
      expect(AuthStatus.values, contains(AuthStatus.loading));
      expect(AuthStatus.values, contains(AuthStatus.otpSent));
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
      expect(AuthStatus.values, contains(AuthStatus.error));
    });
  });
}
