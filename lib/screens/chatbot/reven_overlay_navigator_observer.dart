import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import 'reven_chat_overlay.dart';
import 'reven_route_tracker.dart';

/// Tracks the active route for the global Reven FAB and minimizes chat on navigation.
class RevenOverlayNavigatorObserver extends NavigatorObserver {
  static const _authRoutes = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.verifyOtp,
    AppRoutes.resetPassword,
    AppRoutes.onboarding,
    AppRoutes.initial,
  };

  void _syncOverlayForRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && _authRoutes.contains(name)) {
      RevenChatOverlay.hide();
      return;
    }
    RevenChatOverlay.minimizeIfExpanded();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    RevenRouteTracker.instance.update(route);
    _syncOverlayForRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    RevenRouteTracker.instance.update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    RevenRouteTracker.instance.update(newRoute);
    _syncOverlayForRoute(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    RevenRouteTracker.instance.update(previousRoute);
  }
}
