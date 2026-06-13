import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../api/user_api.dart';
import 'firebase_phone_auth_helper.dart';
import 'phone_otp_debug_log.dart';

/// Routes phone OTP: iOS → backend Brevo SMS; Android → Firebase Phone Auth.
class PhoneOtpSendCoordinator {
  PhoneOtpSendCoordinator._();

  static bool get iosUsesBackendSms => !kIsWeb && Platform.isIOS;

  /// Sends phone OTP using the platform-appropriate provider.
  static Future<FirebasePhoneSendResult> send({
    required FirebaseAuth auth,
    required String phoneE164,
    String? accountEmail,
  }) async {
    if (iosUsesBackendSms) {
      return _sendViaBackend(phoneE164: phoneE164, accountEmail: accountEmail);
    }
    return FirebasePhoneAuthHelper.sendOtp(
      auth: auth,
      phoneE164: phoneE164,
    );
  }

  static Future<FirebasePhoneSendResult> _sendViaBackend({
    required String phoneE164,
    String? accountEmail,
  }) async {
    final email = accountEmail?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return FirebasePhoneSendResult.failure(
        'Account email is required to send phone verification on iPhone.',
      );
    }

    PhoneOtpDebugLog.log(
      'sendOtp',
      'iOS — backend Brevo SMS via /phone/send-otp (no APNs/reCAPTCHA)',
    );

    try {
      final response = await UserApi.sendPhoneOtp(email, phoneE164.trim());
      if (response['status'] == 'ok' || response['success'] == true) {
        PhoneOtpDebugLog.log(
          'codeSent',
          'provider=${response['provider'] ?? 'brevo'} (backend SMS)',
        );
        return FirebasePhoneSendResult.backendSmsSent();
      }
      final message = response['message']?.toString() ??
          'Could not send SMS. Check Brevo SMS is configured on the server.';
      PhoneOtpDebugLog.error('backend sendOtp', message);
      return FirebasePhoneSendResult.failure(message);
    } catch (e) {
      PhoneOtpDebugLog.error('backend sendOtp', e);
      return FirebasePhoneSendResult.failure(e.toString());
    }
  }
}
