import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EliteLoader extends StatelessWidget {
  final bool isFullPage;
  final String? message;
  final Color? color;

  const EliteLoader({
    super.key,
    this.isFullPage = false,
    this.message,
    this.color,
  });

  /// A top-aligned linear loader for use in Stacks
  static Widget top({Color? color}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(color ?? const Color(0xFF667eea)),
          minHeight: 4,
        ).animate().fadeIn(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loaderColor = color ?? const Color(0xFF667eea);

    if (!isFullPage) {
      return LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation(loaderColor),
        minHeight: 4,
      ).animate().fadeIn();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              backgroundColor: isDark
                  ? Colors.white10
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(loaderColor),
              minHeight: 3,
            ).animate().fadeIn().shimmer(duration: 1500.ms),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }
}
