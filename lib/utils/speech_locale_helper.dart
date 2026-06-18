import 'dart:ui';

import 'package:speech_to_text/speech_to_text.dart';

/// Picks the best on-device speech locale (fixes wrong-language recognition).
class SpeechLocaleHelper {
  SpeechLocaleHelper._();

  static String _normalizeTag(String value) =>
      value.trim().replaceAll('_', '-').toLowerCase();

  static String? pickBestLocaleId(
    List<LocaleName> available, {
    String? languageCode,
    String? countryCode,
  }) {
    if (available.isEmpty) return null;

    final device = PlatformDispatcher.instance.locale;
    final lang = (languageCode ?? device.languageCode).toLowerCase();
    final country =
        (countryCode ?? device.countryCode)?.toUpperCase();

    final candidates = <String>[
      if (country != null && country.isNotEmpty) '$lang-$country',
      if (lang == 'en' && (country == 'AE' || country == null)) 'en-AE',
      if (lang == 'en' && country == 'IN') 'en-IN',
      if (lang == 'en' && country == 'US') 'en-US',
      if (lang == 'en' && country == 'GB') 'en-GB',
      if (lang == 'ar') 'ar-AE',
      if (lang == 'ar') 'ar-SA',
      lang,
      'en-US',
      'en-GB',
      'en-AE',
    ];

    final ids = available.map((l) => l.localeId).toList();

    for (final candidate in candidates) {
      final c = _normalizeTag(candidate);
      for (final id in ids) {
        if (_normalizeTag(id) == c) return id;
      }
    }

    for (final candidate in candidates) {
      final prefix = candidate.split('-').first.toLowerCase();
      for (final id in ids) {
        final lower = _normalizeTag(id);
        if (lower == prefix || lower.startsWith('$prefix-')) return id;
      }
    }

    // Never default to arbitrary first locale (can be unrelated language like cmn_CN).
    for (final id in ids) {
      final n = _normalizeTag(id);
      if (n.startsWith('en-') || n == 'en') return id;
    }
    for (final id in ids) {
      final n = _normalizeTag(id);
      if (n.startsWith('ar-') || n == 'ar') return id;
    }

    return available.first.localeId;
  }
}
