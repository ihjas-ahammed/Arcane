import 'package:flutter/material.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

// Background painter for the dotted grid
class NfsGridPainter extends CustomPainter {
  final Color gridColor;
  NfsGridPainter({Color? gridColor})
      : gridColor = gridColor ?? ArcSurfaces.ink(0.1); // structure dots

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = gridColor;
    const double spacing = 6.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
