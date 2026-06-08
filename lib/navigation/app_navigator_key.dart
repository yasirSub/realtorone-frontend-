import 'package:flutter/material.dart';

/// Root navigator for sheets/dialogs from overlays (Reven) that sit outside [Navigator].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

BuildContext rootNavigatorContext(BuildContext fallback) {
  final root = appNavigatorKey.currentContext;
  if (root != null && root.mounted) return root;
  return fallback;
}
