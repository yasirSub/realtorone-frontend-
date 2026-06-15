/// Shared phone formatting and validation (E.164-style).
class PhoneUtils {
  PhoneUtils._();

  static const List<Map<String, String>> countryOptions = [
    {'label': 'AE (+971)', 'code': '+971'},
    {'label': 'IN (+91)', 'code': '+91'},
    {'label': 'US (+1)', 'code': '+1'},
    {'label': 'UK (+44)', 'code': '+44'},
    {'label': 'SA (+966)', 'code': '+966'},
    {'label': 'QA (+974)', 'code': '+974'},
    {'label': 'KW (+965)', 'code': '+965'},
    {'label': 'BH (+973)', 'code': '+973'},
    {'label': 'OM (+968)', 'code': '+968'},
  ];

  /// Local number length (without country code) per dial code.
  static const Map<String, ({int min, int max, String name})> rulesByDialCode = {
    '+971': (min: 9, max: 9, name: 'UAE'),
    '+91': (min: 10, max: 10, name: 'India'),
    '+1': (min: 10, max: 10, name: 'US'),
    '+44': (min: 10, max: 10, name: 'UK'),
    '+966': (min: 9, max: 9, name: 'Saudi Arabia'),
    '+974': (min: 8, max: 8, name: 'Qatar'),
    '+965': (min: 8, max: 8, name: 'Kuwait'),
    '+973': (min: 8, max: 8, name: 'Bahrain'),
    '+968': (min: 8, max: 8, name: 'Oman'),
  };

  static const int fallbackMinLocalDigits = 7;
  static const int fallbackMaxLocalDigits = 15;

  static ({int min, int max, String name}) ruleFor(String dialCode) =>
      rulesByDialCode[dialCode] ??
      (min: fallbackMinLocalDigits, max: fallbackMaxLocalDigits, name: 'phone');

  static int maxInputLengthFor(String dialCode) => ruleFor(dialCode).max;

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static String composeE164(String dialCode, String localDigits) {
    final digits = digitsOnly(localDigits);
    if (digits.isEmpty) return '';
    final code = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    return '$code$digits';
  }

  static bool isValidE164(String phone) {
    final normalized = normalizeFreeform(phone.trim());
    if (!normalized.startsWith('+')) return false;
    final parsed = parseStored(normalized);
    if (parsed.localDigits.isEmpty) return false;
    return validateLocalDigits(
          parsed.localDigits,
          dialCode: parsed.dialCode,
          required: true,
        ) ==
        null;
  }

  /// Validates local digits for the selected country code.
  static String? validateLocalDigits(
    String? value, {
    required String dialCode,
    bool required = true,
  }) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return required ? 'Required' : null;
    }

    final rule = ruleFor(dialCode);
    if (digits.length < rule.min || digits.length > rule.max) {
      if (rule.min == rule.max) {
        return '${rule.name} numbers must be ${rule.min} digits';
      }
      return '${rule.name} numbers must be ${rule.min}–${rule.max} digits';
    }
    return null;
  }

  static String? Function(String?) localDigitsValidator(
    String dialCode, {
    bool required = true,
  }) {
    return (value) =>
        validateLocalDigits(value, dialCode: dialCode, required: required);
  }

  /// Validates a full E.164 number (e.g. +971501234567).
  static String? validateE164(String? value, {bool required = true}) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return required ? 'Required' : null;
    }
    final normalized = normalizeFreeform(trimmed);
    if (!isValidE164(normalized)) {
      final parsed = parseStored(normalized);
      final rule = ruleFor(parsed.dialCode);
      if (rule.min == rule.max) {
        return 'Enter a valid ${rule.name} number (${rule.min} digits after ${parsed.dialCode})';
      }
      return 'Enter a valid phone number with country code';
    }
    return null;
  }

  static String? validateOptionalE164(String? value) =>
      validateE164(value, required: false);

  /// Normalize user-typed phone (may include spaces, dashes, leading 00).
  static String normalizeFreeform(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (value.startsWith('+')) {
      value = '+${value.substring(1).replaceAll('+', '')}';
    } else {
      value = value.replaceAll('+', '');
      if (value.startsWith('00')) {
        value = '+${value.substring(2)}';
      } else if (value.isNotEmpty) {
        value = '+$value';
      }
    }
    return value;
  }

    static bool isIndiaMobile(String? phone) {
    final normalized = normalizeFreeform((phone ?? '').trim());
    return normalized.startsWith('+91');
  }

  /// Split stored E.164 into dial code + local digits for dropdown UIs.
  /// Longer dial codes are matched first (+971 before +97).
  static ({String dialCode, String localDigits}) parseStored(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return (dialCode: '+971', localDigits: '');
    }

    final codes = countryOptions
        .map((e) => e['code']!)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final code in codes) {
      if (value.startsWith(code)) {
        return (
          dialCode: code,
          localDigits: digitsOnly(value.substring(code.length)),
        );
      }
    }

    final normalized = normalizeFreeform(value);
    for (final code in codes) {
      if (normalized.startsWith(code)) {
        return (
          dialCode: code,
          localDigits: digitsOnly(normalized.substring(code.length)),
        );
      }
    }

    return (dialCode: '+971', localDigits: digitsOnly(value));
  }
}
