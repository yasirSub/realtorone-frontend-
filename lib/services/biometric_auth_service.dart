import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricAuthResult {
  const BiometricAuthResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

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
    final result = await authenticateWithDetails(reason: reason);
    return result.success;
  }

  static Future<BiometricAuthResult> authenticateWithDetails({
    required String reason,
  }) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) return const BiometricAuthResult(success: true);
      return const BiometricAuthResult(
        success: false,
        message: 'Authentication canceled or not recognized.',
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
          return const BiometricAuthResult(
            success: false,
            message: 'Biometric hardware is not available on this device.',
          );
        case auth_error.notEnrolled:
          return const BiometricAuthResult(
            success: false,
            message: 'No fingerprint/Face ID enrolled. Add it in phone settings first.',
          );
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return const BiometricAuthResult(
            success: false,
            message: 'Biometrics temporarily locked. Unlock your phone with PIN and try again.',
          );
        case auth_error.passcodeNotSet:
          return const BiometricAuthResult(
            success: false,
            message: 'Set a device screen lock (PIN/Passcode) before enabling biometrics.',
          );
        default:
          return BiometricAuthResult(
            success: false,
            message: (e.message != null && e.message!.isNotEmpty)
                ? e.message
                : 'Biometric authentication failed.',
          );
      }
    } catch (e) {
      debugPrint('BiometricAuthService: $e');
      return const BiometricAuthResult(
        success: false,
        message: 'Could not access biometric authentication on this device.',
      );
    }
  }
}
