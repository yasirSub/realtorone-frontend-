import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Firebase Phone Auth helpers (init + user-facing errors).
class FirebasePhoneAuthHelper {
  FirebasePhoneAuthHelper._();

  static Future<bool> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (e) {
      if (e.toString().contains('duplicate-app') && Firebase.apps.isNotEmpty) {
        return true;
      }
      return false;
    }
  }

  static String userMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. For UAE use +971 and 9 digits (e.g. 501234567).';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'SMS limit reached. Link billing in Google Cloud (Firebase project realtor-one) or use a test number in Firebase Console.';
      case 'billing-not-enabled':
        return 'Firebase SMS billing is not enabled. Link a billing account to project realtor-one in Google Cloud, or use server SMS (Brevo) by fixing BREVO_SMS_SENDER on the API server.';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'This app build is not authorized for SMS. Add SHA-1 and SHA-256 in Firebase → Project settings → Android app.';
      case 'captcha-check-failed':
        return 'Security check failed. Try on a physical phone (not emulator) or add a test phone in Firebase.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      default:
        final msg = e.message?.trim() ?? '';
        if (msg.toUpperCase().contains('BILLING_NOT_ENABLED')) {
          return 'Firebase phone SMS needs billing on Google Cloud (project realtor-one). Enable billing or fix Brevo SMS on the server.';
        }
        if (msg.isNotEmpty) {
          return '$msg (${e.code})';
        }
        return 'Failed to send SMS code (${e.code}).';
    }
  }
}
