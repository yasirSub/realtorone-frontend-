import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences_service.dart';

/// Tracks whether the user has unlocked the app for this session.
class AppPasscodeService extends ChangeNotifier {
  AppPasscodeService._();
  static final AppPasscodeService instance = AppPasscodeService._();
  static const String _lastBackgroundedAtMsKey =
      'app_passcode_last_backgrounded_at_ms';

  bool hasPasscode = false;
  bool _unlocked = false;
  int _suppressLockDepth = 0;
  DateTime? _lastBackgroundedAt;

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
    _lastBackgroundedAt = null;
    unawaited(_clearLastBackgroundedAt());
    notifyListeners();
  }

  void lock() {
    if (!hasPasscode || isLockSuppressed) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<void> noteBackgroundedNow() async {
    if (!hasPasscode || isLockSuppressed) return;
    final now = DateTime.now();
    _lastBackgroundedAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackgroundedAtMsKey, now.millisecondsSinceEpoch);
  }

  Future<bool> shouldLockAfterResume() async {
    if (!hasPasscode || isLockSuppressed) return false;
    if (!_unlocked) return true;
    await AppPreferencesService.ensureLoaded();

    final prefs = await SharedPreferences.getInstance();
    final lastMs =
        _lastBackgroundedAt?.millisecondsSinceEpoch ??
        prefs.getInt(_lastBackgroundedAtMsKey);
    if (lastMs == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
    final threshold = AppPreferencesService.appPasscodeLockDuration.value;
    if (threshold <= Duration.zero) {
      return true;
    }
    return elapsed >= threshold;
  }

  Future<void> lockIfExpired() async {
    final shouldLock = await shouldLockAfterResume();
    if (shouldLock) {
      lock();
    }
  }

  void clear() {
    hasPasscode = false;
    _unlocked = false;
    _lastBackgroundedAt = null;
    unawaited(_clearLastBackgroundedAt());
    notifyListeners();
  }

  Future<void> _clearLastBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastBackgroundedAtMsKey);
  }
}
