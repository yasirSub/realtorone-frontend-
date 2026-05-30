import 'package:flutter/foundation.dart';

import '../api/activities_api.dart';
import '../api/api_client.dart';
import '../api/user_api.dart';
import 'support_contact_service.dart';

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
        ApiClient.getPublic(
          '/app-config',
          useCache: true,
          cacheMaxAge: const Duration(minutes: 15),
        ),
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

      final config = await ApiClient.getPublic(
        '/app-config',
        useCache: true,
        revalidateInBackground: false,
      );
      final data = config['data'];
      if (data is Map<String, dynamic>) {
        await SupportContactService.cacheFromAppConfig(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppWarmCache] warmAfterLogin: $e');
      }
    } finally {
      _warming = false;
    }
  }
}
