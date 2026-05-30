import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../api/user_api.dart';
import '../routes/app_routes.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Handle initial link if app was closed
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, navigatorKey);
      }
    } catch (e) {
      debugPrint('DeepLink Error: $e');
    }

    // 2. Listen for links while app is running/backgrounded
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('DeepLink Received: $uri');
        _handleUri(uri, navigatorKey);
      },
      onError: (err) {
        debugPrint('DeepLink Stream Error: $err');
      },
    );
  }

  static void _handleUri(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    // Example: https://aanantbishthealing.com/reset-password?token=XYZ&email=ABC
    // Example: https://api.aanantbishthealing.com/verify-otp?email=ABC
    // Example: realtorone://reset-password?token=XYZ&email=ABC

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isHttpsDomainLink =
        host == 'aanantbishthealing.com' || host == 'api.aanantbishthealing.com';
    final isCustomSchemeLink = scheme == 'realtorone';

    if (!isHttpsDomainLink && !isCustomSchemeLink) {
      return;
    }

    // For custom scheme links like realtorone://reset-password, Flutter parses
    // "reset-password" as host and path as "/". Normalize both forms.
    final normalizedPath = isCustomSchemeLink
        ? (uri.path == '/' || uri.path.isEmpty ? '/${uri.host}' : uri.path)
        : uri.path;
    final queryParams = uri.queryParameters;

    if (normalizedPath == '/reset-password' ||
        normalizedPath == '/reset-password/') {
      final token = queryParams['token'];
      final email = queryParams['email'];
      
      navigatorKey.currentState?.pushNamed(
        AppRoutes.resetPassword,
        arguments: {'token': token, 'email': email},
      );
    } else if (normalizedPath == '/verify-otp' ||
        normalizedPath == '/verify-otp/') {
      final email = queryParams['email'];

      navigatorKey.currentState?.pushNamed(
        AppRoutes.verifyOtp,
        arguments: email,
      );
    } else if (normalizedPath == '/verify-email' ||
        normalizedPath == '/verify-email/' ||
        normalizedPath == '/email/verify' ||
        normalizedPath == '/email/verify/') {
      _handleEmailVerificationLink(queryParams, navigatorKey);
    } else if (normalizedPath == '/login' || normalizedPath == '/login/') {
      navigatorKey.currentState?.pushNamed(AppRoutes.login);
    }
  }

  static Future<void> _handleEmailVerificationLink(
    Map<String, String> queryParams,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (queryParams['verified'] == '1') {
      navigator.pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
      return;
    }

    final email = queryParams['email']?.trim() ?? '';
    final token = queryParams['token']?.trim() ?? '';
    if (email.isEmpty || token.isEmpty) {
      navigator.pushNamed(AppRoutes.login);
      return;
    }

    try {
      final result = await UserApi.verifyEmailOtp(
        email,
        token,
        requiresAuth: false,
      );
      if (result['status'] == 'ok' || result['success'] == true) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
      } else {
        navigator.pushNamed(
          AppRoutes.verifyOtp,
          arguments: email,
        );
      }
    } catch (e) {
      debugPrint('Email verify deep link error: $e');
      navigator.pushNamed(
        AppRoutes.verifyOtp,
        arguments: email,
      );
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
