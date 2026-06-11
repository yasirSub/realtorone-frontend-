import 'package:flutter/foundation.dart';

/// Tracks whether the user has unlocked the app for this session.
class AppPasscodeService extends ChangeNotifier {
  AppPasscodeService._();
  static final AppPasscodeService instance = AppPasscodeService._();

  bool hasPasscode = false;
  bool _unlocked = false;

  bool get needsLock => hasPasscode && !_unlocked;

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
    if (!hasPasscode) return;
    _unlocked = false;
    notifyListeners();
  }

  void clear() {
    hasPasscode = false;
    _unlocked = false;
    notifyListeners();
  }
}
