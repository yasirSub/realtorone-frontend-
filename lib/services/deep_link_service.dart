import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Handle initial link if app was closed
    try {
      final initialUri = await _appLinks.getInitialAppLink();
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
    // Example: https://aanantbishthealing.com/verify-otp?email=ABC
    
    final path = uri.path;
    final queryParams = uri.queryParameters;

    if (path == '/reset-password' || path == '/reset-password/') {
      final token = queryParams['token'];
      final email = queryParams['email'];
      
      navigatorKey.currentState?.pushNamed(
        AppRoutes.resetPassword,
        arguments: {'token': token, 'email': email},
      );
    } else if (path == '/verify-otp' || path == '/verify-otp/') {
      final email = queryParams['email'];
      
      navigatorKey.currentState?.pushNamed(
        AppRoutes.verifyOtp,
        arguments: email,
      );
    } else if (path == '/login' || path == '/login/') {
      navigatorKey.currentState?.pushNamed(AppRoutes.login);
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
