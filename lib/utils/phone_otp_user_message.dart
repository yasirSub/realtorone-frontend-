import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_phone_auth_helper.dart';
import 'phone_otp_debug_log.dart';

/// User-safe OTP strings for snackbars and dialogs. Technical detail stays in [PhoneOtpDebugLog].
class PhoneOtpUserMessage {
  PhoneOtpUserMessage._();

  static const somethingWentWrong =
      'Something went wrong. Please wait a moment and try again.';
  static const serverUnavailable =
      'Server is temporarily unavailable. Please try again later.';
  static const tryAgainLater =
      'Too many requests. Please wait a while and try again.';
  static const invalidCode = 'Invalid code. Try again.';
  static const connectionError = 'Connection error. Please try again.';
  static const codeSent = 'Verification code sent to your phone.';
  static const sending = 'Sending verification code…';
  static const couldNotResend = 'Could not resend code. Try again.';

  static bool isRateLimited(String? technical) {
    if (technical == null || technical.isEmpty) return false;
    final upper = technical.toUpperCase();
    return upper.contains('TOO MANY') ||
        upper.contains('TOO-MANY-REQUESTS') ||
        upper.contains('TOO_MANY_REQUESTS') ||
        upper.contains('UNUSUAL ACTIVITY') ||
        upper.contains('QUOTA-EXCEEDED') ||
        upper.contains('17010');
  }

  static bool looksTechnical(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final lower = raw.toLowerCase();
    const needles = [
      'brevo',
      'firebase',
      'billing',
      'blaze',
      'apns',
      'notification-not-forwarded',
      'google-services',
      'sha-1',
      'sha1',
      'recaptcha',
      'verifyphonenumber',
      'id token',
      'silent push',
      'cloud messaging',
      'play integrity',
      'app-not-authorized',
      'invalid_app_credential',
    ];
    return needles.any(lower.contains);
  }

  static String forSendFailure({String? technical}) {
    _logTechnical('send failure', technical);
    if (isRateLimited(technical)) return tryAgainLater;
    return somethingWentWrong;
  }

  static String forInitFailure({String? technical}) {
    _logTechnical('init failure', technical);
    return somethingWentWrong;
  }

  static String forVerifyFailure({
    String? technical,
    FirebaseAuthException? exception,
  }) {
    if (exception != null) {
      _logTechnical(
        'verify failure',
        FirebasePhoneAuthHelper.technicalMessage(exception),
      );
    } else {
      _logTechnical('verify failure', technical);
    }
    return somethingWentWrong;
  }

  static String forResendFailure({String? technical}) {
    _logTechnical('resend failure', technical);
    if (isRateLimited(technical)) return tryAgainLater;
    return couldNotResend;
  }

  /// Maps dialog/API error text to a safe user string.
  static String forDialogError(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return invalidCode;
    final lower = trimmed.toLowerCase();
    if (lower.contains('invalid') && lower.contains('code')) return invalidCode;
    if (looksTechnical(trimmed) || isRateLimited(trimmed)) {
      _logTechnical('dialog error', trimmed);
      return isRateLimited(trimmed) ? tryAgainLater : somethingWentWrong;
    }
    _logTechnical('dialog error (non-technical)', trimmed);
    return invalidCode;
  }

  static void _logTechnical(String context, String? detail) {
    if (detail == null || detail.isEmpty) return;
    PhoneOtpDebugLog.log('UI hidden ($context)', detail);
  }
}
