import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../services/push_notification_service.dart';

/// Firebase Phone Auth helpers (init + send OTP + user-facing errors).
class FirebasePhoneAuthHelper {
  FirebasePhoneAuthHelper._();

  /// Debug keystore SHA-1 for this machine (add in Firebase if `flutter run` fails SMS).
  static const String debugSha1Hint =
      '56:05:05:CB:32:76:4B:6C:88:8B:54:0E:AD:64:04:AB:5F:DA:8B:C7';

  static Future<bool> ensureInitialized() async {
    final ok = await PushNotificationService.initializeApp();
    if (ok) return true;
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
      debugPrint('FirebasePhoneAuthHelper.ensureInitialized failed: $e');
      return false;
    }
  }

  /// Sends OTP via Firebase (Google) SMS. Returns verificationId on success.
  static Future<FirebasePhoneSendResult> sendOtp({
    required FirebaseAuth auth,
    required String phoneE164,
    // Shorter timeout to reduce "robot"/Play Integrity waiting.
    Duration timeout = const Duration(seconds: 45),
    int? forceResendingToken,
  }) async {
    final trimmed = phoneE164.trim();
    if (!trimmed.startsWith('+') || trimmed.length < 10) {
      return FirebasePhoneSendResult.failure(
        'Use full international format, e.g. +918271819813.',
      );
    }

    final completer = Completer<FirebasePhoneSendResult>();
    Timer? timer;

    void complete(FirebasePhoneSendResult result) {
      if (!completer.isCompleted) {
        timer?.cancel();
        completer.complete(result);
      }
    }

    timer = Timer(timeout, () {
      complete(
        FirebasePhoneSendResult.failure(
          'No SMS response from Firebase after ${timeout.inSeconds}s. '
          'Check Firebase Console → Android app SHA-1 (debug: $debugSha1Hint), '
          'Phone sign-in enabled, and billing on project realtor-one.',
        ),
      );
    });

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: trimmed,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) {
          debugPrint('Firebase phone: verificationCompleted (auto)');
          complete(FirebasePhoneSendResult.autoVerified(credential));
        },
        verificationFailed: (e) {
          debugPrint('Firebase phone: verificationFailed ${e.code} ${e.message}');
          complete(
            FirebasePhoneSendResult.failure(
              userMessage(e),
              billingBlocked: isBillingNotEnabled(e),
            ),
          );
        },
        codeSent: (verificationId, resendToken) {
          debugPrint('Firebase phone: codeSent');
          complete(
            FirebasePhoneSendResult.codeSent(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          debugPrint('Firebase phone: auto retrieval timeout');
        },
      );
    } catch (e) {
      complete(FirebasePhoneSendResult.failure(e.toString()));
    }

    return completer.future;
  }

  static bool isBillingNotEnabled(FirebaseAuthException e) {
    final blob = '${e.code} ${e.message ?? ''}'.toUpperCase();
    return blob.contains('BILLING_NOT_ENABLED') || e.code == 'billing-not-enabled';
  }

  static String billingNotEnabledMessage() =>
      'Firebase Phone SMS still reports billing off for project realtor-one (790178174861). '
      'Enabling billing in Google Cloud is not enough — open Firebase Console → realtor-one → '
      'Upgrade → Blaze (pay as you go) and link the same billing account. '
      'Wait up to 30 minutes, then try again.';

  static String userMessage(FirebaseAuthException e) {
    if (isBillingNotEnabled(e)) return billingNotEnabledMessage();

    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. For India use +91 and 10 digits (e.g. +918271819813).';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many OTP requests. Firebase temporarily blocked this device/number due to unusual activity. Try again later (do not spam OTP).';
      case 'billing-not-enabled':
        return billingNotEnabledMessage();
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'This app build is not authorized for Firebase SMS. In Firebase Console → Project settings → '
            'Your apps → Android com.realtorone.app, add SHA-1: $debugSha1Hint '
            '(run: cd android && gradlew signingReport). Download a fresh google-services.json after saving.';
      case 'captcha-check-failed':
        return 'Firebase security check failed. Use a real phone (not emulator), stable internet, and correct SHA keys.';
      case 'network-request-failed':
        return 'Network error. Check internet and try again.';
      default:
        final msg = e.message?.trim() ?? '';
        if (msg.toUpperCase().contains('BILLING_NOT_ENABLED')) {
          return billingNotEnabledMessage();
        }
        if (msg.toUpperCase().contains('APP_NOT_AUTHORIZED') ||
            msg.toUpperCase().contains('INVALID_APP_CREDENTIAL')) {
          return 'Firebase rejected this app. Add debug SHA-1 $debugSha1Hint to Firebase Android app settings.';
        }
        if (msg.isNotEmpty) {
          return '$msg (${e.code})';
        }
        return 'Failed to send SMS code (${e.code}).';
    }
  }
}

class FirebasePhoneSendResult {
  const FirebasePhoneSendResult._({
    required this.ok,
    this.verificationId,
    this.resendToken,
    this.autoCredential,
    this.errorMessage,
    this.billingBlocked = false,
  });

  final bool ok;
  final String? verificationId;
  final int? resendToken;
  final PhoneAuthCredential? autoCredential;
  final String? errorMessage;
  final bool billingBlocked;

  factory FirebasePhoneSendResult.codeSent({
    required String verificationId,
    int? resendToken,
  }) =>
      FirebasePhoneSendResult._(
        ok: true,
        verificationId: verificationId,
        resendToken: resendToken,
      );

  factory FirebasePhoneSendResult.autoVerified(PhoneAuthCredential credential) =>
      FirebasePhoneSendResult._(ok: true, autoCredential: credential);

  factory FirebasePhoneSendResult.failure(
    String message, {
    bool billingBlocked = false,
  }) =>
      FirebasePhoneSendResult._(
        ok: false,
        errorMessage: message,
        billingBlocked: billingBlocked,
      );
}
