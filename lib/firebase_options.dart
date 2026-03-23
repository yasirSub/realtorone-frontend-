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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCElQRXMWT-JfhJ8jJMWFZbIzDrKkpvvUg',
    appId: '1:790178174861:android:359f15b03cd3e16b7ccfc4',
    messagingSenderId: '790178174861',
    projectId: 'realtor-one',
    storageBucket: 'realtor-one.firebasestorage.app',
  );

  // iOS still needs a real GoogleService-Info.plist and values from flutterfire configure.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_KEY',
    appId: '1:790178174861:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '790178174861',
    projectId: 'realtor-one',
    storageBucket: 'realtor-one.firebasestorage.app',
    iosBundleId: 'com.example.realtorone',
  );
}
