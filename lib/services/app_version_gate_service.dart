import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../navigation/app_navigator_key.dart';
import '../routes/app_routes.dart';
import '../screens/chatbot/reven_chat_overlay.dart';
import '../utils/version_utils.dart';
import 'app_runtime_config_service.dart';

class UpdateRequiredRouteArgs {
  const UpdateRequiredRouteArgs({
    required this.minVersion,
    required this.maxVersion,
    required this.storeUrl,
    required this.apkUrl,
    required this.platformLabel,
  });

  final String minVersion;
  final String maxVersion;
  final String storeUrl;
  final String apkUrl;
  final String platformLabel;

  Map<String, dynamic> toRouteArguments() => {
        'minVersion': minVersion,
        'maxVersion': maxVersion,
        'storeUrl': storeUrl,
        'apkUrl': apkUrl,
        'platformLabel': platformLabel,
      };
}

/// Result of tapping "Check again" on the update screen.
enum VersionRetryOutcome {
  unblocked,
  stillBlocked,
  configUnavailable,
}

/// Enforces remote min/max version rules — blocks the app until the user updates.
class AppVersionGate {
  AppVersionGate._();

  static bool _blocking = false;
  static bool _onUpdateScreen = false;

  static bool get isBlocking => _blocking;

  static bool versionControlEnabledForPlatform(Map<String, dynamic> data) {
    final legacy = AppRuntimeConfigService.flagEnabled(
      data['version_control_enabled'],
      defaultValue: true,
    );
    final android = AppRuntimeConfigService.flagEnabled(
      data['version_control_android_enabled'],
      defaultValue: legacy,
    );
    final ios = AppRuntimeConfigService.flagEnabled(
      data['version_control_ios_enabled'],
      defaultValue: legacy,
    );
    if (kIsWeb) return legacy;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    return legacy;
  }

  static String _platformLabel() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android';
    return 'mobile';
  }

  static Future<UpdateRequiredRouteArgs?> evaluateConfig(
    Map<String, dynamic> data, {
    String? currentVersion,
  }) async {
    final version = currentVersion ??
        (await PackageInfo.fromPlatform()).version.trim();
    if (version.isEmpty) return null;

    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isIos = !kIsWeb && Platform.isIOS;

    final minVersion = (isAndroid
            ? data['min_android_version']
            : isIos
                ? data['min_ios_version']
                : '')
        ?.toString()
        .trim() ??
        '';
    final maxVersion = (isAndroid
            ? data['max_android_version']
            : isIos
                ? data['max_ios_version']
                : '')
        ?.toString()
        .trim() ??
        '';
    final storeUrl = (isAndroid
            ? data['android_store_url']
            : isIos
                ? data['ios_store_url']
                : '')
        ?.toString()
        .trim() ??
        '';
    final apkUrl = data['apk_url']?.toString().trim() ?? '';

    final updateRequired = isVersionUpdateRequired(
      versionControlEnabled: versionControlEnabledForPlatform(data),
      currentVersion: version,
      minVersion: minVersion,
      maxVersion: maxVersion,
    );
    if (!updateRequired) return null;

    return UpdateRequiredRouteArgs(
      minVersion: minVersion,
      maxVersion: maxVersion,
      storeUrl: storeUrl,
      apkUrl: apkUrl,
      platformLabel: _platformLabel(),
    );
  }

  /// Returns `true` when navigation to the blocking update screen occurred.
  static Future<bool> enforceIfRequired({
    Map<String, dynamic>? config,
    bool forceRefresh = false,
  }) async {
    Map<String, dynamic>? data = config;
    if (forceRefresh || data == null) {
      data = await AppRuntimeConfigService.refresh(force: forceRefresh);
    }
    if (data == null) {
      _blocking = false;
      return false;
    }

    final args = await evaluateConfig(data);
    if (args == null) {
      _blocking = false;
      if (_onUpdateScreen) {
        _onUpdateScreen = false;
        _returnToSplashAfterUnblock();
      }
      return false;
    }

    if (_onUpdateScreen) {
      _blocking = true;
      return true;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return false;

    _blocking = true;
    _onUpdateScreen = true;
    RevenChatOverlay.hide();
    nav.pushNamedAndRemoveUntil(
      AppRoutes.updateRequired,
      (_) => false,
      arguments: args.toRouteArguments(),
    );
    return true;
  }

  static void _returnToSplashAfterUnblock() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    _onUpdateScreen = false;
    _blocking = false;
    nav.pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
  }

  /// Call before post-auth navigation so outdated builds cannot enter the app.
  static Future<bool> blockEntryIfRequired() {
    return enforceIfRequired(forceRefresh: true);
  }

  /// Re-fetch `/app-config` from the update screen.
  static Future<({VersionRetryOutcome outcome, UpdateRequiredRouteArgs? latest})>
      retryFromUpdateScreen() async {
    try {
      final data = await AppRuntimeConfigService.refresh(
        force: true,
        enforceVersionGate: false,
      );
      if (data == null) {
        return (
          outcome: VersionRetryOutcome.configUnavailable,
          latest: null,
        );
      }

      final args = await evaluateConfig(data);
      if (args == null) {
        _returnToSplashAfterUnblock();
        return (outcome: VersionRetryOutcome.unblocked, latest: null);
      }

      _blocking = true;
      _onUpdateScreen = true;
      return (outcome: VersionRetryOutcome.stillBlocked, latest: args);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVersionGate] retry failed: $e');
      }
      return (
        outcome: VersionRetryOutcome.configUnavailable,
        latest: null,
      );
    }
  }

  /// @deprecated Use [retryFromUpdateScreen].
  static Future<bool> retryCheck() async {
    final result = await retryFromUpdateScreen();
    return result.outcome != VersionRetryOutcome.unblocked && isBlocking;
  }
}
