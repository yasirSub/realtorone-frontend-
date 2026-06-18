import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();

  static const String weeklyReportsEnabledKey = 'weekly_reports_enabled';
  static const String chatbotEnabledKey = 'chatbot_enabled';
  static const String biometricUnlockEnabledKey = 'biometric_unlock_enabled';
  static const String appPasscodeLockDurationMinutesKey =
      'app_passcode_lock_duration_minutes';
  static const String appPasscodeLockDurationLegacyMinutesKey =
      'app_passcode_lock_timeout_minutes';

  static final ValueNotifier<bool> weeklyReportsEnabled = ValueNotifier<bool>(
    true,
  );

  static final ValueNotifier<bool> chatbotEnabled = ValueNotifier<bool>(true);

  static final ValueNotifier<bool> biometricUnlockEnabled =
      ValueNotifier<bool>(false);
  static final ValueNotifier<Duration> appPasscodeLockDuration =
      ValueNotifier<Duration>(Duration.zero);

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    weeklyReportsEnabled.value =
        prefs.getBool(weeklyReportsEnabledKey) ?? true;
    chatbotEnabled.value = prefs.getBool(chatbotEnabledKey) ?? true;
    biometricUnlockEnabled.value =
        prefs.getBool(biometricUnlockEnabledKey) ?? false;
    final durationMinutes =
        prefs.getInt(appPasscodeLockDurationMinutesKey) ??
        prefs.getInt(appPasscodeLockDurationLegacyMinutesKey) ??
        0;
    appPasscodeLockDuration.value = Duration(
      minutes: durationMinutes < 0 ? 0 : durationMinutes,
    );
    _loaded = true;
  }

  static Future<void> setWeeklyReportsEnabled(bool enabled) async {
    weeklyReportsEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(weeklyReportsEnabledKey, enabled);
  }

  static Future<void> setChatbotEnabled(bool enabled) async {
    chatbotEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(chatbotEnabledKey, enabled);
  }

  static Future<void> setBiometricUnlockEnabled(bool enabled) async {
    biometricUnlockEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(biometricUnlockEnabledKey, enabled);
  }

  static Future<void> setAppPasscodeLockDuration(Duration duration) async {
    final clamped = duration.isNegative ? Duration.zero : duration;
    appPasscodeLockDuration.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(appPasscodeLockDurationMinutesKey, clamped.inMinutes);
  }
}
