import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app locale: English (default) or Arabic (UAE / Dubai region).
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_locale_code';
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'ar') {
      _locale = const Locale('ar');
    } else {
      _locale = const Locale('en');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'ar'].contains(locale.languageCode)) return;
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }

  Future<void> setEnglish() => setLocale(const Locale('en'));

  Future<void> setArabicUae() => setLocale(const Locale('ar'));
}
