import 'package:flutter/material.dart';

/// Current named route (MaterialApp builder cannot read [ModalRoute] reliably).
class RevenRouteTracker {
  RevenRouteTracker._();

  static String? routeName;

  static void update(Route<dynamic>? route) {
    routeName = route?.settings.name;
  }
}
