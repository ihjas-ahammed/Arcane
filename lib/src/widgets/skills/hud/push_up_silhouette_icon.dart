import 'package:flutter/material.dart';
import 'tac_colors.dart';

class PushUpSilhouetteIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const PushUpSilhouetteIcon({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PushUpPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _PushUpPainter extends CustomPainter {
  final Color color;
  _PushUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    final paintHead = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(27 * sx, 11 * sy), 2.5 * sx, paintHead);

    final pathBody = Path()
      ..moveTo(25 * sx, 14.5 * sy)
      ..lineTo(16.5 * sx, 19 * sy)
      ..lineTo(7.5 * sx, 17.5 * sy)
      ..lineTo(3 * sx, 21.5 * sy)
      ..lineTo(4.5 * sx, 23 * sy)
      ..lineTo(8 * sx, 20 * sy)
      ..lineTo(16 * sx, 21.5 * sy)
      ..lineTo(24.5 * sx, 16.5 * sy)
      ..lineTo(26 * sx, 21 * sy)
      ..lineTo(28 * sx, 20.5 * sy)
      ..lineTo(26 * sx, 14.5 * sy)
      ..close();
    canvas.drawPath(pathBody, paintHead);

    final paintFloor = Paint()
      ..color = TacColors.borderOuter
      ..strokeWidth = 1.5 * sy;
    canvas.drawLine(Offset(2 * sx, 26 * sy), Offset(30 * sx, 26 * sy), paintFloor);
  }

  @override
  bool shouldRepaint(covariant _PushUpPainter old) => true;
}
