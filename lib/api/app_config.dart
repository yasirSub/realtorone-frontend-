import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _localAndroidApiBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _localHostApiBaseUrl = 'http://127.0.0.1:8000/api';

  static String get apiBaseUrl {
    if (kIsWeb) return _localHostApiBaseUrl;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _localAndroidApiBaseUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _localHostApiBaseUrl;
    }
  }
}
