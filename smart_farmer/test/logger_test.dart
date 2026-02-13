import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer/core/utils/logger.dart';

void main() {
  group('Log utility', () {
    test('Log.i does not throw', () {
      expect(() => Log.i('Test', 'info message'), returnsNormally);
    });

    test('Log.w does not throw', () {
      expect(() => Log.w('Test', 'warning message'), returnsNormally);
    });

    test('Log.e does not throw', () {
      expect(
        () => Log.e('Test', 'error message', Exception('fail')),
        returnsNormally,
      );
    });

    test('Log.e without error object does not throw', () {
      expect(() => Log.e('Test', 'error only'), returnsNormally);
    });
  });
}
