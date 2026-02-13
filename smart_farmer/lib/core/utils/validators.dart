class Validators {
  const Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!isValidKenyanPhone(cleaned)) {
      return 'Enter a valid Kenyan phone number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP code is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter a valid 6-digit code';
    }
    return null;
  }

  static bool isValidKenyanPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');

    // +2547XXXXXXXX or +2541XXXXXXXX
    if (RegExp(r'^\+254[17]\d{8}$').hasMatch(cleaned)) return true;

    // 2547XXXXXXXX or 2541XXXXXXXX
    if (RegExp(r'^254[17]\d{8}$').hasMatch(cleaned)) return true;

    // 07XXXXXXXX or 01XXXXXXXX
    if (RegExp(r'^0[17]\d{8}$').hasMatch(cleaned)) return true;

    return false;
  }

  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email.trim());
  }

  /// Normalizes a Kenyan phone number to +254 format.
  static String normalizeKenyanPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');

    if (cleaned.startsWith('+254')) return cleaned;
    if (cleaned.startsWith('254')) return '+$cleaned';
    if (cleaned.startsWith('0')) return '+254${cleaned.substring(1)}';

    return '+254$cleaned';
  }
}
