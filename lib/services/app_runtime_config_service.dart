import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'support_contact_service.dart';

/// Shared `/app-config` payload so home refresh and Reven chat use the same flags.
class AppRuntimeConfigService {
  AppRuntimeConfigService._();

  static final ValueNotifier<Map<String, dynamic>?> config =
      ValueNotifier<Map<String, dynamic>?>(null);

  static bool _refreshing = false;

  static bool flagEnabled(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value == false || value == 0) return false;
    if (value == true || value == 1) return true;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on') {
      return true;
    }
    return defaultValue;
  }

  static Future<Map<String, dynamic>?> refresh({bool force = false}) async {
    if (_refreshing && !force) {
      return config.value;
    }
    _refreshing = true;
    try {
      if (force) {
        await ApiClient.invalidateEndpointCache('/app-config');
      }
      final res = await ApiClient.getPublic(
        '/app-config',
        useCache: !force,
        revalidateInBackground: !force,
      );
      final raw = res['data'];
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        config.value = data;
        await SupportContactService.cacheFromAppConfig(data);
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppRuntimeConfig] refresh failed: $e');
      }
    } finally {
      _refreshing = false;
    }
    return config.value;
  }

  static Future<void> ensureLoaded() async {
    if (config.value != null) return;
    await refresh();
  }
}
