import 'package:flutter/foundation.dart';

class AppConfig {
  static const String liveApiBaseUrl = 'http://aanantbishthealing.com/api';

  /// Production website origin for Privacy / Terms (HTTPS). Used in release for Play Console and in-app browser links.
  static const String liveWebOrigin = 'https://aanantbishthealing.com';

  static const String _legalPrivacyOverride =
      String.fromEnvironment('LEGAL_PRIVACY_URL', defaultValue: '');
  static const String _legalTermsOverride =
      String.fromEnvironment('LEGAL_TERMS_URL', defaultValue: '');

  static String get privacyPolicyUrl {
    if (_legalPrivacyOverride.isNotEmpty) return _legalPrivacyOverride;
    if (kReleaseMode) return '$liveWebOrigin/privacy';
    return '${_legalDevOrigin()}/privacy';
  }

  static String get termsOfServiceUrl {
    if (_legalTermsOverride.isNotEmpty) return _legalTermsOverride;
    if (kReleaseMode) return '$liveWebOrigin/terms';
    return '${_legalDevOrigin()}/terms';
  }

  /// Local Vite dev server (`npm run dev` in realtorone-website). Override with LEGAL_*_URL to use Laravel on :8000 instead.
  static String _legalDevOrigin() {
    if (kIsWeb) return 'http://127.0.0.1:5173';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5173';
      default:
        return 'http://127.0.0.1:5173';
    }
  }

  /// Full API root including `/api`, e.g. `http://192.168.1.10:8000/api`
  /// Physical device on Wi‑Fi: `flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000/api`
  static const String _dartDefineApiBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Android emulator: host machine’s localhost (not 127.0.0.1 on the device)
  static const String _androidEmulatorApi = 'http://10.0.2.2:8000/api';

  /// iOS Simulator, desktop, Chrome: Laravel on same machine
  static const String _loopbackApi = 'http://127.0.0.1:8000/api';

  static String get apiBaseUrl {
    if (_dartDefineApiBase.isNotEmpty) {
      return _dartDefineApiBase;
    }

    if (kReleaseMode) {
      return liveApiBaseUrl;
    }

    if (kIsWeb) return _loopbackApi;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidEmulatorApi;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _loopbackApi;
    }
  }

  /// Site origin for `WebViewController.loadHtmlString` baseUrl (API base without trailing `/api`).
  static String get apiOrigin {
    var base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }
}

