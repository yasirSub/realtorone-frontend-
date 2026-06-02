import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();

  static const String weeklyReportsEnabledKey = 'weekly_reports_enabled';

  static final ValueNotifier<bool> weeklyReportsEnabled = ValueNotifier<bool>(
    true,
  );

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    weeklyReportsEnabled.value =
        prefs.getBool(weeklyReportsEnabledKey) ?? true;
    _loaded = true;
  }

  static Future<void> setWeeklyReportsEnabled(bool enabled) async {
    weeklyReportsEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(weeklyReportsEnabledKey, enabled);
  }
}
