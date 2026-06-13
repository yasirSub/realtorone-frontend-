import 'package:flutter/foundation.dart';

/// In-memory OTP trace for terminal / Xcode console ([OTP_DEBUG] via debugPrint).
class PhoneOtpDebugLog {
  PhoneOtpDebugLog._();

  static final List<String> _lines = [];
  static String? _lastError;

  static void start(String flow) {
    _lines.clear();
    _lastError = null;
    log('START', flow);
  }

  static void log(String step, [String? detail]) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = detail == null || detail.isEmpty
        ? '[$ts] $step'
        : '[$ts] $step — $detail';
    _lines.add(line);
    final out = '[OTP_DEBUG] $line';
    debugPrint(out);
    // Visible in Xcode → Devices console and `flutter run` on a plugged-in iPhone.
    print(out);
  }

  static void error(String step, Object? err) {
    _lastError = err?.toString();
    log('ERROR', '$step: $_lastError');
  }

  /// Dump full trace to console (call after failed OTP on iOS).
  static void dumpReport() {
    for (final line in report().split('\n')) {
      final out = '[OTP_DEBUG] $line';
      debugPrint(out);
      print(out);
    }
  }

  static String maskPhone(String phone) {
    final p = phone.trim();
    if (p.length <= 6) return '***';
    final head = p.length >= 4 ? p.substring(0, 4) : p;
    return '$head***${p.substring(p.length - 3)}';
  }

  static String report() {
    final buffer = StringBuffer('Phone OTP Debug Report\n');
    buffer.writeln('iOS: Brevo SMS via backend /phone/send-otp');
    buffer.writeln('Android: Firebase Phone Auth');
    buffer.writeln('─' * 40);
    for (final line in _lines) {
      buffer.writeln(line);
    }
    if (_lastError != null) {
      buffer.writeln('─' * 40);
      buffer.writeln('Last error: $_lastError');
    }
    return buffer.toString();
  }

  static List<String> get lines => List.unmodifiable(_lines);
  static String? get lastError => _lastError;
}
