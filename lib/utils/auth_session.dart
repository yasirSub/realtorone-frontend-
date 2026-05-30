import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';

/// Persist token and route user into the app after a successful auth response.
class AuthSession {
  AuthSession._();

  static Future<void> establishAndNavigate(
    BuildContext context,
    Map<String, dynamic> response,
  ) async {
    final token = response['token']?.toString();
    if (token == null || token.isEmpty) return;

    await ApiClient.setToken(token);
    await PushNotificationService.syncTokenWithBackend();
    await ApiClient.clearCache();

    final user = response['user'];
    if (user is Map) {
      final prefs = await SharedPreferences.getInstance();
      final name = user['name']?.toString();
      final email = user['email']?.toString();
      if (name != null && name.isNotEmpty) {
        await prefs.setString('user_name', name);
      }
      if (email != null && email.isNotEmpty) {
        await prefs.setString('user_email', email);
      }
      await prefs.setBool('hasSeenOnboarding', true);
    }

    if (!context.mounted) return;

    final profile = await ApiClient.get('/user/profile', requiresAuth: true);
    if (!context.mounted) return;

    if (profile['success'] == true) {
      final userData = profile['data'];
      if (userData is Map && userData['is_profile_complete'] != true) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.profileSetup,
          (_) => false,
        );
        return;
      }
      if (userData is Map && userData['has_completed_diagnosis'] != true) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.diagnosis,
          (_) => false,
        );
        return;
      }
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
  }
}
