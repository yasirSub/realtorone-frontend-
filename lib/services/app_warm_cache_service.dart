import 'package:flutter/foundation.dart';

import '../api/activities_api.dart';
import '../api/api_client.dart';
import '../api/user_api.dart';
import 'app_runtime_config_service.dart';

/// Prefetches common API payloads into on-device cache after login so screens
/// open quickly and the server sees fewer repeat reads.
class AppWarmCacheService {
  AppWarmCacheService._();

  static bool _warming = false;

  static Future<void> warmAfterLogin() async {
    if (_warming) return;
    _warming = true;
    try {
      await Future.wait([
        UserApi.getProfile(useCache: true),
        ActivitiesApi.getActivityTypes(),
        AppRuntimeConfigService.refresh(),
        ApiClient.get(
          '/tasks/today',
          requiresAuth: true,
          useCache: true,
          cacheMaxAge: const Duration(minutes: 10),
        ),
        ApiClient.get(
          '/webinars',
          requiresAuth: true,
          useCache: true,
          cacheMaxAge: const Duration(hours: 2),
        ),
      ], eagerError: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppWarmCache] warmAfterLogin: $e');
      }
    } finally {
      _warming = false;
    }
  }
}
