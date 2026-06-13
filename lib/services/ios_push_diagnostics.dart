import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../utils/phone_otp_debug_log.dart';
import 'ios_phone_auth_apns_bridge.dart';
import 'push_notification_service.dart';

/// Collects iOS push + OTP diagnostic data for debugging delivery issues.
class IosPushDiagnostics {
  IosPushDiagnostics._();

  static const MethodChannel _channel =
      MethodChannel('com.realtorone.app/phone_auth');

  static Future<Map<String, dynamic>> collect() async {
    if (kIsWeb) {
      return {'platform': 'web'};
    }

    if (!Platform.isIOS && !Platform.isAndroid) {
      return {'platform': Platform.operatingSystem};
    }

    if (Platform.isAndroid) {
      await PushNotificationService.initializeApp();
      final settings = await PushNotificationService.messagingSettings();
      String? fcmToken;
      Object? fcmError;
      try {
        fcmToken = await PushNotificationService.getFcmToken(logToConsole: true);
      } catch (e) {
        fcmError = e;
      }
      final lines = <String>[
        '═══ Push / FCM Diagnostics (Android) ═══',
        'permission: ${settings.authorizationStatus.name}',
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken (full):\n$fcmToken',
        if (fcmToken == null || fcmToken.isEmpty) 'fcmToken: null',
        if (fcmError != null) 'fcmError: $fcmError',
      ];
      return {
        'permission': settings.authorizationStatus.name,
        'fcmToken': fcmToken,
        'report': lines.join('\n'),
      };
    }

    final native = await IosPhoneAuthApnsBridge.debugStatus();
    final settings = await PushNotificationService.messagingSettings();
    String? fcmToken;
    String? apnsToken;
    Object? fcmError;
    Object? apnsError;

    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      fcmError = e;
    }
    try {
      apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    } catch (e) {
      apnsError = e;
    }

    Map<String, dynamic> embedded = {};
    try {
      final raw = await _channel.invokeMethod<Object>('embeddedApsEnvironment');
      if (raw is Map) {
        embedded = raw.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      embedded = {'error': e.toString()};
    }

    final lines = <String>[
      '═══ Push / FCM Diagnostics ═══',
      'permission: ${settings.authorizationStatus.name}',
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken (full):\n$fcmToken',
      if (fcmToken == null || fcmToken.isEmpty) 'fcmToken: null',
      if (fcmError != null) 'fcmError: $fcmError',
      'apnsToken: ${apnsToken == null ? "null" : "${apnsToken.substring(0, 12)}…(${apnsToken.length})"}',
      if (apnsError != null) 'apnsError: $apnsError',
      'embeddedAps: ${embedded['apsEnvironment'] ?? embedded}',
      'native: $native',
      '───',
      _rootCauseHint(native, embedded, settings.authorizationStatus),
    ];

    if (fcmToken != null && fcmToken.isNotEmpty) {
      PhoneOtpDebugLog.log('FCM token (full)', fcmToken);
    }

    return {
      'permission': settings.authorizationStatus.name,
      'fcmToken': fcmToken,
      'fcmTokenPrefix': fcmToken != null && fcmToken.length >= 12
          ? fcmToken.substring(0, 12)
          : fcmToken,
      'fcmTokenLength': fcmToken?.length,
      'apnsTokenPrefix': apnsToken?.substring(0, 12),
      'apnsTokenLength': apnsToken?.length,
      'native': native,
      'embedded': embedded,
      'report': lines.join('\n'),
    };
  }

  static String _rootCauseHint(
    Map<String, dynamic> native,
    Map<String, dynamic> embedded,
    AuthorizationStatus permission,
  ) {
    if (permission == AuthorizationStatus.denied) {
      return 'ROOT CAUSE: Notifications denied. Settings → RealtorOne → Notifications → Allow.';
    }
    if (native['authHasApnsToken'] != true) {
      return 'ROOT CAUSE: No APNs token on device. Reopen app and allow notifications.';
    }
    final received = native['remoteNotificationsReceived'] ?? 0;
    final hasToken = native['authHasApnsToken'] == true;
    if (hasToken && received == 0) {
      return 'STATUS: APNs token OK but silent push not received (received=0). '
          'App will try reCAPTCHA fallback (needs reCAPTCHA Enterprise in Firebase Console). '
          'Also verify: Firebase → Cloud Messaging → APNs Key 9AJ6U4P74W, Team XZ6S52GQ8U, '
          'bundle com.realtorone.app, Phone sign-in ON, Blaze billing. '
          'embeddedAps=${embedded['apsEnvironment'] ?? native['apsEnvironment']}, '
          'tokenType=${native['apnsTokenType']}, bundle=${native['bundleId']}.';
    }
    if (received > 0) {
      return 'GOOD: Silent push reached device ($received). OTP path should work.';
    }
    return 'Check notification permission and reopen the app.';
  }

  static Future<Map<String, dynamic>> sendTestPush() async {
    PhoneOtpDebugLog.log('push-test', 'calling backend /user/push-test');
    final result = await ApiClient.post('/user/push-test', {}, requiresAuth: true);
    final statusCode = result['statusCode'];
    final message = (result['message'] ?? '').toString();
    if (statusCode == 404 || message.toLowerCase().contains('could not be found')) {
      return {
        'success': false,
        'message':
            'Backend not deployed yet (/user/push-test missing on server). '
            'OTP does NOT need this route — use Send OTP on phone verification. '
            'Test push only checks webinar/FCM from server.',
      };
    }
    return result;
  }

  static void logReport(Map<String, dynamic> data) {
    final report = data['report']?.toString() ?? data.toString();
    for (final line in report.split('\n')) {
      PhoneOtpDebugLog.log('diagnostics', line);
    }
  }

  /// Prints device name, FCM token, and Firebase OTP hints to the debug console.
  static Future<void> printStartupConsoleReport() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;

    var deviceName = Platform.operatingSystem;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        deviceName = '${ios.name} · ${ios.model} · iOS ${ios.systemVersion}';
      } else {
        final android = await info.androidInfo;
        deviceName = '${android.model} · Android ${android.version.release}';
      }
    } catch (e) {
      deviceName = '$deviceName (device info error: $e)';
    }

    final data = await collect();
    final fcm = data['fcmToken']?.toString() ?? 'null';
    final report = data['report']?.toString() ?? '';

    const banner = '════════════════════════════════════════';
    PhoneOtpDebugLog.log('DEBUG REPORT', banner);
    PhoneOtpDebugLog.log('device', deviceName);
    PhoneOtpDebugLog.log('platform', Platform.operatingSystem);
    PhoneOtpDebugLog.log('FCM token (full)', fcm);
    for (final line in report.split('\n')) {
      if (line.trim().isEmpty) continue;
      PhoneOtpDebugLog.log('firebase/push', line.trim());
    }
    PhoneOtpDebugLog.log(
      'iOS OTP note',
      'OTP needs silent APNs push OR reCAPTCHA Enterprise in Firebase Console '
          '(realtor-one). Android does not need APNs.',
    );
    PhoneOtpDebugLog.log('DEBUG REPORT', banner);
  }
}
