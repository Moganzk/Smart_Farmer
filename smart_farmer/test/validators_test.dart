import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('returns error for empty input', () {
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone(null), isNotNull);
      expect(Validators.phone('  '), isNotNull);
    });

    test('accepts 07XXXXXXXX format', () {
      expect(Validators.phone('0712345678'), isNull);
      expect(Validators.phone('0798765432'), isNull);
    });

    test('accepts 01XXXXXXXX format', () {
      expect(Validators.phone('0112345678'), isNull);
    });

    test('accepts 2547XXXXXXXX format', () {
      expect(Validators.phone('254712345678'), isNull);
    });

    test('accepts +2547XXXXXXXX format', () {
      expect(Validators.phone('+254712345678'), isNull);
    });

    test('accepts +2541XXXXXXXX format', () {
      expect(Validators.phone('+254112345678'), isNull);
    });

    test('rejects invalid numbers', () {
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.phone('0512345678'), isNotNull);
      expect(Validators.phone('+12025551234'), isNotNull);
      expect(Validators.phone('abcdefghij'), isNotNull);
    });

    test('handles numbers with spaces and dashes', () {
      expect(Validators.phone('0712 345 678'), isNull);
      expect(Validators.phone('071-234-5678'), isNull);
      expect(Validators.phone('+254 712 345678'), isNull);
    });
  });

  group('Validators.normalizeKenyanPhone', () {
    test('normalizes 07... to +254...', () {
      expect(Validators.normalizeKenyanPhone('0712345678'), '+254712345678');
    });

    test('normalizes 254... to +254...', () {
      expect(Validators.normalizeKenyanPhone('254712345678'), '+254712345678');
    });

    test('keeps +254... as-is', () {
      expect(Validators.normalizeKenyanPhone('+254712345678'), '+254712345678');
    });
  });

  group('Validators.email', () {
    test('returns error for empty input', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
    });

    test('accepts valid emails', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('user.name+tag@domain.co.ke'), isNull);
      expect(Validators.email('farmer@smart.farm'), isNull);
    });

    test('rejects invalid emails', () {
      expect(Validators.email('notanemail'), isNotNull);
      expect(Validators.email('missing@'), isNotNull);
      expect(Validators.email('@nodomain.com'), isNotNull);
      expect(Validators.email('spaces in@email.com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('returns error for empty input', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password(null), isNotNull);
    });

    test('returns error for short passwords', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('abc'), isNotNull);
    });

    test('accepts valid passwords', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('strongPassword!'), isNull);
    });
  });

  group('Validators.otp', () {
    test('returns error for empty input', () {
      expect(Validators.otp(''), isNotNull);
      expect(Validators.otp(null), isNotNull);
    });

    test('accepts 6-digit codes', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('000000'), isNull);
    });

    test('rejects non-6-digit codes', () {
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('1234567'), isNotNull);
      expect(Validators.otp('abcdef'), isNotNull);
    });
  });
}
