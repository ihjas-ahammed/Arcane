import 'package:flutter/material.dart';
import 'tac_colors.dart';

class PullUpRigSilhouetteIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const PullUpRigSilhouetteIcon({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PullUpPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _PullUpPainter extends CustomPainter {
  final Color color;
  _PullUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    // Top Bar: (4,8) to (28,8)
    final barPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * sy
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4 * sx, 8 * sy), Offset(28 * sx, 8 * sy), barPaint);

    // Left and Right Rig Legs
    final legPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5 * sx;
    canvas.drawLine(Offset(6 * sx, 8 * sy), Offset(6 * sx, 28 * sy), legPaint);
    canvas.drawLine(Offset(26 * sx, 8 * sy), Offset(26 * sx, 28 * sy), legPaint);

    // Head circle at (16, 14)
    canvas.drawCircle(Offset(16 * sx, 14 * sy), 2.2 * sx, Paint()..color = color..style = PaintingStyle.fill);

    // Body strokes
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final bodyPath = Path()
      ..moveTo(11 * sx, 9.5 * sy)
      ..lineTo(14 * sx, 14 * sy)
      ..lineTo(14 * sx, 20 * sy)
      ..lineTo(13 * sx, 25 * sy)
      ..lineTo(15 * sx, 25 * sy)
      ..lineTo(16 * sx, 20.5 * sy)
      ..lineTo(17 * sx, 25 * sy)
      ..lineTo(19 * sx, 25 * sy)
      ..lineTo(18 * sx, 20 * sy)
      ..lineTo(18 * sx, 14 * sy)
      ..lineTo(21 * sx, 9.5 * sy);
    canvas.drawPath(bodyPath, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _PullUpPainter old) => true;
}
