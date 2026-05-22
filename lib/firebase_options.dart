// Generated-style file. Replace with `flutterfire configure` when you add iOS/web apps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web in this Flutter app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // com.realtorone.app — from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCElQRXMWT-JfhJ8jJMWFZbIzDrKkpvvUg',
    appId: '1:790178174861:android:ea2bcd806e5996417ccfc4',
    messagingSenderId: '790178174861',
    projectId: 'realtor-one',
    storageBucket: 'realtor-one.firebasestorage.app',
  );

  // Matches ios/Runner/GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA5u5m67g1Y2U0OQTz7n1mIdxgpPWiDsy0',
    appId: '1:790178174861:ios:fd52983e364439237ccfc4',
    messagingSenderId: '790178174861',
    projectId: 'realtor-one',
    storageBucket: 'realtor-one.firebasestorage.app',
    iosBundleId: 'com.realtorone.app',
  );
}
