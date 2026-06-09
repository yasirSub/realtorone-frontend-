import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native iOS bridge: sync APNs token into Firebase Auth before phone OTP.
class IosPhoneAuthApnsBridge {
  IosPhoneAuthApnsBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.realtorone.app/phone_auth');

  static Future<Map<String, dynamic>> debugStatus() async {
    if (kIsWeb || !Platform.isIOS) return {};
    try {
      final raw = await _channel.invokeMethod<Object>('debugStatus');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      return {'error': e.toString()};
    }
    return {};
  }

  /// Copies Messaging APNs token → Firebase Auth (native). Returns post-sync status.
  static Future<Map<String, dynamic>> syncApnsToAuth() async {
    if (kIsWeb || !Platform.isIOS) return {'skipped': true};
    try {
      final raw = await _channel.invokeMethod<Object>('syncApnsToAuth');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      return {'error': e.toString()};
    }
    return {};
  }
}
