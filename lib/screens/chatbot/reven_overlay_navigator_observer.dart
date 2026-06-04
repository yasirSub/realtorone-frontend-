import 'package:flutter/material.dart';

import 'reven_chat_overlay.dart';

/// Minimizes the floating chat panel when the user navigates to another screen.
class RevenOverlayNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    RevenChatOverlay.minimizeIfExpanded();
  }
}
