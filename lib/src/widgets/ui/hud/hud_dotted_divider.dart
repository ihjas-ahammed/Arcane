import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class HudDottedDivider extends StatelessWidget {
  final Color? color;
  final double height;
  const HudDottedDivider({super.key, this.color, this.height = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _DottedPainter(color: color ?? JweTheme.lineAmber), size: Size.fromHeight(height)),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 3, size.height / 2), p);
      x += 6;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
