import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../utils/version_utils.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.currentVersion,
    required this.buildNumber,
    required this.minVersionForPlatform,
    required this.storeUrl,
    required this.apkUrl,
    required this.releaseNotes,
    required this.updatedAt,
    required this.updateRequired,
  });

  final String currentVersion;
  final String buildNumber;
  final String minVersionForPlatform;
  final String storeUrl;
  final String apkUrl;
  final String releaseNotes;
  final String updatedAt;
  final bool updateRequired;

  String get displayVersion =>
      buildNumber.isEmpty ? currentVersion : '$currentVersion ($buildNumber)';
}

class AppVersionService {
  static Future<AppVersionInfo> load({bool bustCache = true}) async {
    final package = await PackageInfo.fromPlatform();
    final endpoint = bustCache
        ? '/app-config?_=${DateTime.now().millisecondsSinceEpoch}'
        : '/app-config';

    var minAndroid = '';
    var minIos = '';
    var androidStore = '';
    var iosStore = '';
    var apkUrl = '';
    var releaseNotes = '';
    var updatedAt = '';
    var versionControlEnabled = true;

    try {
      final response = await ApiClient.getPublic(endpoint);
      final data = response['data'];
      if (data is Map) {
        versionControlEnabled = data['version_control_enabled'] != false &&
            data['version_control_enabled'] != 0 &&
            data['version_control_enabled']?.toString() != 'false';
        minAndroid = data['min_android_version']?.toString().trim() ?? '';
        minIos = data['min_ios_version']?.toString().trim() ?? '';
        androidStore = data['android_store_url']?.toString().trim() ?? '';
        iosStore = data['ios_store_url']?.toString().trim() ?? '';
        apkUrl = data['apk_url']?.toString().trim() ?? '';
        releaseNotes = data['release_notes']?.toString().trim() ?? '';
        updatedAt = data['updated_at']?.toString().trim() ?? '';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppVersionService] failed to load config: $e');
      }
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isIos = !kIsWeb && Platform.isIOS;

    final minForPlatform = isAndroid
        ? minAndroid
        : isIos
            ? minIos
            : '';
    final storeForPlatform = isAndroid
        ? androidStore
        : isIos
            ? iosStore
            : '';

    final updateRequired = versionControlEnabled &&
        minForPlatform.isNotEmpty &&
        compareSemanticVersions(package.version, minForPlatform) < 0;

    return AppVersionInfo(
      currentVersion: package.version,
      buildNumber: package.buildNumber,
      minVersionForPlatform: minForPlatform,
      storeUrl: storeForPlatform,
      apkUrl: apkUrl,
      releaseNotes: releaseNotes,
      updatedAt: updatedAt,
      updateRequired: updateRequired,
    );
  }
}
