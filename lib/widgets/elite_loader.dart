import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EliteLoader extends StatelessWidget {
  final bool isFullPage;
  final String? message;

  const EliteLoader({super.key, this.isFullPage = false, this.message});

  /// A top-aligned linear loader for use in Stacks
  static Widget top() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: const LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
          minHeight: 4,
        ).animate().fadeIn(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isFullPage) {
      return const LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
        minHeight: 4,
      ).animate().fadeIn();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
              minHeight: 3,
            ).animate().fadeIn().shimmer(duration: 1500.ms),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF64748B),
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
