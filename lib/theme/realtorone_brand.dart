import 'package:flutter/material.dart';

/// Brand colors aligned with [MaterialApp] dark theme and splash screen.
abstract final class RealtorOneBrand {
  static const Color scaffoldDark = Color(0xFF020617);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentTeal = Color(0xFF4ECDC4);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color seed = Color(0xFF667eea);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentIndigo, accentTeal],
  );
}

class RealtorOneGridPainter extends CustomPainter {
  RealtorOneGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const double step = 40;

    for (var i = 0.0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (var i = 0.0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RealtorOneGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
