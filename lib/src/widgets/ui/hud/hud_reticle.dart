import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class HudReticle extends StatelessWidget {
  final double size;
  final Color? color;
  const HudReticle({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _ReticlePainter(color: color ?? JweTheme.accentAmber));
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3;
    final ring = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1;
    final dot = Paint()..color = color..style = PaintingStyle.fill;
    final tick = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), r, ring);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.1, dot);
    final t = size.width * 0.15;
    canvas.drawLine(Offset(cx, 0), Offset(cx, t), tick);
    canvas.drawLine(Offset(cx, size.height - t), Offset(cx, size.height), tick);
    canvas.drawLine(Offset(0, cy), Offset(t, cy), tick);
    canvas.drawLine(Offset(size.width - t, cy), Offset(size.width, cy), tick);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
