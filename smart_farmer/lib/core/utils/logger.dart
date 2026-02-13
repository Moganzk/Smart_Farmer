import 'dart:developer' as dev;

/// Lightweight logger with timestamps and level tags.
///
/// Calls `dart:developer` log() so output appears in the debug console.
class Log {
  const Log._();

  static void i(String tag, String message) {
    dev.log('[INFO] $tag: $message', name: 'SmartFarmer');
  }

  static void w(String tag, String message) {
    dev.log('[WARN] $tag: $message', name: 'SmartFarmer');
  }

  static void e(String tag, String message, [Object? error]) {
    dev.log('[ERROR] $tag: $message', name: 'SmartFarmer', error: error);
  }
}
