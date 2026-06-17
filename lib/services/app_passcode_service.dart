import 'package:flutter/foundation.dart';

/// Tracks whether the user has unlocked the app for this session.
class AppPasscodeService extends ChangeNotifier {
  AppPasscodeService._();
  static final AppPasscodeService instance = AppPasscodeService._();

  bool hasPasscode = false;
  bool _unlocked = false;
  int _suppressLockDepth = 0;

  bool get needsLock => hasPasscode && !_unlocked;

  /// True while external flows (Razorpay, App Store, etc.) temporarily leave the app.
  bool get isLockSuppressed => _suppressLockDepth > 0;

  void beginSuppressLock() {
    _suppressLockDepth++;
  }

  void endSuppressLock() {
    if (_suppressLockDepth > 0) {
      _suppressLockDepth--;
    }
  }

  void configureFromProfile(Map<String, dynamic>? data) {
    if (data == null) {
      hasPasscode = false;
      return;
    }
    hasPasscode = data['has_app_passcode'] == true ||
        data['app_passcode_set_at'] != null;
    notifyListeners();
  }

  void unlock() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    if (!hasPasscode || isLockSuppressed) return;
    _unlocked = false;
    notifyListeners();
  }

  void clear() {
    hasPasscode = false;
    _unlocked = false;
    notifyListeners();
  }
}
