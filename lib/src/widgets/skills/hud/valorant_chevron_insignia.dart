import 'package:flutter/material.dart';
import 'tac_colors.dart';

/// Valorant Tiered Chevron Insignia (3 layered chevrons)
class ValorantChevronInsignia extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const ValorantChevronInsignia({
    super.key,
    this.width = 19,
    this.height = 23,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ChevronInsigniaPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _ChevronInsigniaPainter extends CustomPainter {
  final Color color;
  _ChevronInsigniaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 28.0;

    // Top chevron (0.35 opacity): M12 2 L22 10 L12 18 L2 10 Z
    final p1 = Path()
      ..moveTo(12 * sx, 2 * sy)
      ..lineTo(22 * sx, 10 * sy)
      ..lineTo(12 * sx, 18 * sy)
      ..lineTo(2 * sx, 10 * sy)
      ..close();
    canvas.drawPath(p1, Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.fill);

    // Mid chevron (0.75 opacity): M12 7 L20 13 L12 19 L4 13 Z
    final p2 = Path()
      ..moveTo(12 * sx, 7 * sy)
      ..lineTo(20 * sx, 13 * sy)
      ..lineTo(12 * sx, 19 * sy)
      ..lineTo(4 * sx, 13 * sy)
      ..close();
    canvas.drawPath(p2, Paint()..color = color.withValues(alpha: 0.75)..style = PaintingStyle.fill);

    // Bottom chevron (1.0 opacity): M12 12 L18 16 L12 20 L6 16 Z
    final p3 = Path()
      ..moveTo(12 * sx, 12 * sy)
      ..lineTo(18 * sx, 16 * sy)
      ..lineTo(12 * sx, 20 * sy)
      ..lineTo(6 * sx, 16 * sy)
      ..close();
    canvas.drawPath(p3, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ChevronInsigniaPainter old) => true;
}
