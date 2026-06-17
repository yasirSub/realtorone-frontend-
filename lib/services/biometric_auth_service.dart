import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Device biometric checks and labels (Face ID / fingerprint).
class BiometricAuthService {
  BiometricAuthService._();

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  /// User-facing label: "Face ID" on iOS when supported, else "Fingerprint".
  static Future<String> unlockLabel() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (Platform.isIOS &&
          types.contains(BiometricType.face)) {
        return 'Face ID';
      }
      if (types.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      }
      if (types.contains(BiometricType.face)) {
        return 'Face ID';
      }
      if (types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak)) {
        return Platform.isIOS ? 'Face ID' : 'Fingerprint';
      }
    } catch (_) {}
    return 'Biometrics';
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('BiometricAuthService: $e');
      return false;
    }
  }
}
