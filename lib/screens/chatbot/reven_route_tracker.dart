import 'package:flutter/material.dart';

/// Tracks the active named route so the global Reven FAB can show/hide reliably.
class RevenRouteTracker extends ChangeNotifier {
  RevenRouteTracker._();

  static final RevenRouteTracker instance = RevenRouteTracker._();

  String? routeName;

  void update(Route<dynamic>? route) {
    final next = route?.settings.name;
    if (next == routeName) {
      return;
    }
    routeName = next;
    notifyListeners();
  }
}
