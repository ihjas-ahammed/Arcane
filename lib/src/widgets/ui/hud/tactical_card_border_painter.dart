import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Tactical border & bracket painter for planned cards (Card 1, Card 2, Card 3, Hero, Homescreen Widget)
class TacticalCardBorderPainter extends CustomPainter {
  final Color themeColor;
  final double chamfer;
  final double bracketSize;
  final double leftBarWidth;
  final Color? borderColor;

  const TacticalCardBorderPainter({
    required this.themeColor,
    this.chamfer = 10.0,
    this.bracketSize = 12.0,
    this.leftBarWidth = 3.0,
    this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;
    final isLight = JweTheme.isLight;

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    // 1px border around chamfered path
    final borderPaint = Paint()
      ..color = borderColor ?? (isLight ? JweTheme.border : const Color(0xFF1A2736))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    final effectiveThemeColor = isLight ? JweTheme.calibrate(themeColor) : themeColor;

    // Solid theme color along left edge
    if (leftBarWidth > 0) {
      final leftEdgePaint = Paint()
        ..color = effectiveThemeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = leftBarWidth;
      canvas.drawLine(Offset(0, c), Offset(0, h - c), leftEdgePaint);
    }

    // Top-left bracket following the chamfer
    if (bracketSize > 0) {
      final bracketPaint = Paint()
        ..color = effectiveThemeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final bracketPath = Path()
        ..moveTo(0, c + bracketSize)
        ..lineTo(0, c)
        ..lineTo(c, 0)
        ..lineTo(c + bracketSize, 0);
      canvas.drawPath(bracketPath, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TacticalCardBorderPainter oldDelegate) =>
      oldDelegate.themeColor != themeColor ||
      oldDelegate.chamfer != chamfer ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.leftBarWidth != leftBarWidth ||
      oldDelegate.borderColor != borderColor;
}
