import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../services/push_notification_service.dart';
import '../services/ios_phone_auth_apns_bridge.dart';
import 'phone_otp_debug_log.dart';

/// Firebase Phone Auth helpers (init + send OTP + technical error detail for logs).
class FirebasePhoneAuthHelper {
  FirebasePhoneAuthHelper._();

  /// Debug keystore SHA-1 for this machine (add in Firebase if `flutter run` fails SMS).
  static const String debugSha1Hint =
      '56:05:05:CB:32:76:4B:6C:88:8B:54:0E:AD:64:04:AB:5F:DA:8B:C7';

  /// iOS phone auth needs a registered APNs token before verifyPhoneNumber.
  static Future<bool> _ensureIosApnsToken() async {
    if (!Platform.isIOS) return true;
    final messaging = FirebaseMessaging.instance;
    for (var attempt = 0; attempt < 12; attempt++) {
      final token = await messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        final preview = '${token.substring(0, 8)}…(${token.length} chars)';
        PhoneOtpDebugLog.log('APNs token', 'ready attempt ${attempt + 1} $preview');
        return true;
      }
      PhoneOtpDebugLog.log('APNs token', 'waiting attempt ${attempt + 1}/12');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    PhoneOtpDebugLog.error('APNs token', 'not available after 6s');
    return false;
  }

  static Future<bool> ensureInitialized() async {
    PhoneOtpDebugLog.log('Firebase init', 'checking apps=${Firebase.apps.length}');
    final ok = await PushNotificationService.initializeApp();
    PhoneOtpDebugLog.log('PushNotificationService.initializeApp', ok ? 'ok' : 'failed');
    if (!ok && Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        PhoneOtpDebugLog.log('Firebase.initializeApp', 'success');
      } catch (e) {
        if (e.toString().contains('duplicate-app') && Firebase.apps.isNotEmpty) {
          PhoneOtpDebugLog.log('Firebase.initializeApp', 'duplicate-app, continuing');
          return await _ensureIosPhoneAuthReady();
        }
        PhoneOtpDebugLog.error('Firebase.initializeApp', e);
        return false;
      }
    }
    return _ensureIosPhoneAuthReady();
  }

  static Future<bool> _ensureIosPhoneAuthReady() async {
    if (kIsWeb || !Platform.isIOS) return true;
    return PushNotificationService.ensureIosReadyForPhoneAuth();
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
    PhoneOtpDebugLog.log(
      'sendOtp',
      'phone=${PhoneOtpDebugLog.maskPhone(trimmed)} platform=${Platform.operatingSystem}',
    );
    if (!trimmed.startsWith('+') || trimmed.length < 10) {
      PhoneOtpDebugLog.error('sendOtp', 'invalid E.164 format');
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
      PhoneOtpDebugLog.error('timeout', 'no Firebase response in ${timeout.inSeconds}s');
      final hint = (!kIsWeb && Platform.isIOS)
          ? 'On iPhone: allow notifications, use a real device (not simulator), '
              'and upload APNs key in Firebase Console → Cloud Messaging.'
          : 'Check Firebase Console → Android app SHA-1 (debug: $debugSha1Hint), '
              'Phone sign-in enabled, and billing on project realtor-one.';
      complete(
        FirebasePhoneSendResult.failure(
          'No SMS response from Firebase after ${timeout.inSeconds}s. $hint',
        ),
      );
    });

    if (!kIsWeb && Platform.isIOS) {
      PhoneOtpDebugLog.log('iOS preflight', 'checking notification + APNs');
      await IosPhoneAuthApnsBridge.resetNotificationCounter();

      final nativePrep = await IosPhoneAuthApnsBridge.prepareForPhoneAuth();
      PhoneOtpDebugLog.log('native prepareForPhoneAuth', nativePrep.toString());
      if (nativePrep['authorized'] == false) {
        PhoneOtpDebugLog.error('iOS preflight', 'notification permission denied');
        return FirebasePhoneSendResult.failure(_iosNotificationPermissionMessage());
      }

      final iosReady = await PushNotificationService.ensureIosReadyForPhoneAuth();
      if (!iosReady) {
        PhoneOtpDebugLog.error('iOS preflight', 'notification permission or FCM not ready');
        return FirebasePhoneSendResult.failure(_iosNotificationPermissionMessage());
      }
      final apnsReady = await _ensureIosApnsToken();
      if (!apnsReady) {
        return FirebasePhoneSendResult.failure(
          'iOS push token not ready. Fully quit the app, reopen it, allow notifications, '
          'then try again. Also upload your APNs .p8 key in Firebase Console → Cloud Messaging.',
        );
      }
      try {
        await auth.initializeRecaptchaConfig();
        PhoneOtpDebugLog.log('iOS preflight', 'reCAPTCHA config initialized (silent-push fallback)');
      } catch (e) {
        PhoneOtpDebugLog.log(
          'iOS preflight',
          'reCAPTCHA not configured in Firebase Console (enable reCAPTCHA Enterprise for iOS in '
          'Project settings → App Check / Authentication). Silent APNs push is still required: $e',
        );
      }

      final beforeSync = await IosPhoneAuthApnsBridge.debugStatus();
      PhoneOtpDebugLog.log('native APNs (before sync)', beforeSync.toString());

      final afterSync = await IosPhoneAuthApnsBridge.syncApnsToAuth();
      PhoneOtpDebugLog.log('native APNs (after sync)', afterSync.toString());

      if (afterSync['authHasApnsToken'] != true) {
        PhoneOtpDebugLog.error(
          'native APNs',
          'Firebase Auth has no APNs token — check Push capability + notification permission',
        );
        return FirebasePhoneSendResult.failure(
          'Firebase Auth on iPhone has no push token yet. '
          'Settings → RealtorOne → Notifications → Allow, then fully quit and reopen the app.',
        );
      }

      final tokenType = afterSync['apnsTokenType'] ?? 'unknown';
      final apsEnv = afterSync['apsEnvironment'] ?? 'unknown';
      PhoneOtpDebugLog.log(
        'iOS APNs environment',
        'type=$tokenType aps=$apsEnv — Firebase Console must have .p8 key for com.realtorone.app',
      );
    }

    PhoneOtpDebugLog.log('verifyPhoneNumber', 'calling Firebase Auth…');
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: trimmed,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) {
          PhoneOtpDebugLog.log('verificationCompleted', 'auto-verify (silent push worked)');
          complete(FirebasePhoneSendResult.autoVerified(credential));
        },
        verificationFailed: (e) {
          PhoneOtpDebugLog.error(
            'verificationFailed',
            'code=${e.code} message=${e.message}',
          );
          if (isNotificationNotForwarded(e)) {
            IosPhoneAuthApnsBridge.debugStatus().then((status) {
              final received = status['remoteNotificationsReceived'] ?? 0;
              PhoneOtpDebugLog.log(
                'hint',
                'silent push never reached app (received=$received). '
                'Upload APNs .p8 in Firebase Console → Project settings → Cloud Messaging '
                'AND Authentication → Sign-in method → Phone for com.realtorone.app. '
                'Release builds need production APNs (type=${status['apnsTokenType']}).',
              );
            });
          }
          if (isBillingNotEnabled(e)) {
            PhoneOtpDebugLog.log('hint', 'Firebase Blaze billing required');
          }
          complete(
            FirebasePhoneSendResult.failure(
              technicalMessage(e),
              billingBlocked: isBillingNotEnabled(e),
              notificationNotForwarded: isNotificationNotForwarded(e),
            ),
          );
        },
        codeSent: (verificationId, resendToken) {
          PhoneOtpDebugLog.log(
            'codeSent',
            'verificationId=${verificationId.substring(0, 8)}… resend=${resendToken != null}',
          );
          complete(
            FirebasePhoneSendResult.codeSent(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          PhoneOtpDebugLog.log('codeAutoRetrievalTimeout', verificationId);
        },
      );
    } catch (e) {
      PhoneOtpDebugLog.error('verifyPhoneNumber exception', e);
      complete(FirebasePhoneSendResult.failure(e.toString()));
    }

    return completer.future;
  }

  static bool isBillingNotEnabled(FirebaseAuthException e) {
    final blob = '${e.code} ${e.message ?? ''}'.toUpperCase();
    return blob.contains('BILLING_NOT_ENABLED') || e.code == 'billing-not-enabled';
  }

  static bool isNotificationNotForwarded(FirebaseAuthException e) =>
      e.code == 'notification-not-forwarded' ||
      (e.message ?? '').toLowerCase().contains('notification-not-forwarded');

  static String billingNotEnabledMessage() =>
      'Firebase Phone SMS still reports billing off for project realtor-one (790178174861). '
      'Enabling billing in Google Cloud is not enough — open Firebase Console → realtor-one → '
      'Upgrade → Blaze (pay as you go) and link the same billing account. '
      'Wait up to 30 minutes, then try again.';

  static String _iosNotificationPermissionMessage() =>
      'iPhone needs notification permission for Firebase phone verification. '
      'Open Settings → RealtorOne → Notifications → Allow Notifications, '
      'then try again on a real iPhone (simulator does not support this).';

  /// Full technical detail for [PhoneOtpDebugLog] — never show directly in UI.
  static String technicalMessage(FirebaseAuthException e) {
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
      case 'notification-not-forwarded':
        return _iosNotificationPermissionMessage() +
            ' In Firebase Console (project realtor-one), upload your Apple APNs Authentication Key (.p8) '
            'with Key ID and Team ID under Cloud Messaging and ensure Phone sign-in is enabled. '
            'Test on a real iPhone (not simulator).';
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
    this.notificationNotForwarded = false,
  });

  final bool ok;
  final String? verificationId;
  final int? resendToken;
  final PhoneAuthCredential? autoCredential;
  final String? errorMessage;
  final bool billingBlocked;
  final bool notificationNotForwarded;

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
    bool notificationNotForwarded = false,
  }) =>
      FirebasePhoneSendResult._(
        ok: false,
        errorMessage: message,
        billingBlocked: billingBlocked,
        notificationNotForwarded: notificationNotForwarded,
      );
}
