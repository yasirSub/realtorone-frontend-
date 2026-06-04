import 'package:flutter/material.dart';

import 'reven_chat_overlay.dart';
import 'reven_route_tracker.dart';

/// Tracks the active route for the global Reven FAB and minimizes chat on navigation.
class RevenOverlayNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    RevenRouteTracker.instance.update(route);
    RevenChatOverlay.minimizeIfExpanded();
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
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    RevenRouteTracker.instance.update(previousRoute);
  }
}
