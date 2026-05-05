import 'package:flutter/material.dart';

/// Responsive layout helper for adapting UI to different screen sizes.
/// Adds iPad-aware padding, max content width, and device detection.
class ResponsiveHelper {
  ResponsiveHelper._();

  /// Breakpoints
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  /// Returns true if the screen is tablet-sized (iPad)
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= phoneMaxWidth;
  }

  /// Returns true if the screen is a large tablet / desktop
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletMaxWidth;
  }

  /// Returns horizontal padding that adapts to screen size.
  /// Phone: 20px, iPad: 40px, Large iPad: 60px
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletMaxWidth) return 60;
    if (width >= phoneMaxWidth) return 40;
    return 20;
  }

  /// Returns symmetric horizontal padding as EdgeInsets
  static EdgeInsets contentPadding(BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final h = horizontalPadding(context);
    return EdgeInsets.fromLTRB(h, top, h, bottom);
  }

  /// Wraps content in a centered, max-width constrained container.
  /// This prevents content from stretching across the full iPad width.
  static Widget constrainWidth({
    required Widget child,
    double maxWidth = 700,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Returns font scale factor for iPad (slightly larger text)
  static double fontScale(BuildContext context) {
    return isTablet(context) ? 1.1 : 1.0;
  }

  /// Returns a padding value that scales with screen size
  static double scaledValue(BuildContext context, double phoneValue) {
    if (isLargeTablet(context)) return phoneValue * 1.5;
    if (isTablet(context)) return phoneValue * 1.25;
    return phoneValue;
  }
}
