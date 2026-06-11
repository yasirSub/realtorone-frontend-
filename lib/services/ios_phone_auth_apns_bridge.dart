import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;

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

  /// Native permission + APNs registration wait before phone OTP.
  /// Returns empty map if native plugin not rebuilt yet (MissingPluginException).
  static Future<Map<String, dynamic>> prepareForPhoneAuth() async {
    if (kIsWeb || !Platform.isIOS) return {'skipped': true};
    try {
      final raw = await _channel.invokeMethod<Object>('prepareForPhoneAuth');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
    } on MissingPluginException {
      return {'skipped': true, 'reason': 'native_rebuild_required'};
    } catch (e) {
      return {'error': e.toString()};
    }
    return {};
  }

  static Future<void> resetNotificationCounter() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('resetNotificationCounter');
    } catch (_) {}
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
