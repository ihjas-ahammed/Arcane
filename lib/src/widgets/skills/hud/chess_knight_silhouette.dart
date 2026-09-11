import 'package:flutter/material.dart';
import 'tac_colors.dart';

/// Chess Knight Silhouette Icon
class ChessKnightSilhouette extends StatelessWidget {
  final double size;
  final Color? color;
  const ChessKnightSilhouette({super.key, this.size = 30, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SvgPathPainter(
        pathString: 'M19 22H5v-2h14v2M17.5 10.5c.3 0 .5-.2.5-.5a3.5 3.5 0 0 0-4.6-3.3c-.6-.7-1.4-1.2-2.4-1.2h-.5c-.3-1.4-1.2-2.7-2.6-3.2-.3-.1-.6.1-.6.4v.3c0 .8-.5 1.5-1.2 1.8-.7.3-1.1 1-1.1 1.7v1c0 1.1.9 2 2 2h.5l-1.5 2.5c-.3.5-.5 1.1-.5 1.7v3.3c0 .8.7 1.5 1.5 1.5h7c.8 0 1.5-.7 1.5-1.5v-2c0-.8-.7-1.5-1.5-1.5h-.5l1.5-2.5c.3-.5.9-.8 1.5-.8h.4z',
        color: color ?? TacColors.primaryRed,
        viewBoxSize: 24,
      ),
    );
  }
}

class _SvgPathPainter extends CustomPainter {
  final String pathString;
  final Color color;
  final double viewBoxSize;

  _SvgPathPainter({required this.pathString, required this.color, required this.viewBoxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / viewBoxSize;
    final sy = size.height / viewBoxSize;

    final path = Path()
      ..moveTo(19 * sx, 22 * sy)
      ..lineTo(5 * sx, 22 * sy)
      ..lineTo(5 * sx, 20 * sy)
      ..lineTo(19 * sx, 20 * sy)
      ..close()
      ..moveTo(17.5 * sx, 10.5 * sy)
      ..cubicTo(17.8 * sx, 10.5 * sy, 18 * sx, 10.3 * sy, 18 * sx, 10 * sy)
      ..cubicTo(18 * sx, 8 * sy, 15.5 * sx, 6.7 * sy, 13.4 * sx, 6.7 * sy)
      ..cubicTo(12.8 * sx, 6 * sy, 12 * sx, 5.5 * sy, 11 * sx, 5.5 * sy)
      ..lineTo(10.5 * sx, 5.5 * sy)
      ..cubicTo(10.2 * sx, 4.1 * sy, 9.3 * sx, 2.8 * sy, 7.9 * sx, 2.3 * sy)
      ..lineTo(7.5 * sx, 2.5 * sy)
      ..cubicTo(7.5 * sx, 3.3 * sy, 7 * sx, 4 * sy, 6.3 * sx, 4.3 * sy)
      ..lineTo(5.5 * sx, 6 * sy)
      ..lineTo(7.5 * sx, 8 * sy)
      ..lineTo(6 * sx, 10.5 * sy)
      ..lineTo(5.5 * sx, 12.2 * sy)
      ..lineTo(5.5 * sx, 15.5 * sy)
      ..cubicTo(5.5 * sx, 16.3 * sy, 6.2 * sx, 17 * sy, 7 * sx, 17 * sy)
      ..lineTo(14 * sx, 17 * sy)
      ..cubicTo(14.8 * sx, 17 * sy, 15.5 * sx, 16.3 * sy, 15.5 * sx, 15.5 * sy)
      ..lineTo(15.5 * sx, 13.5 * sy)
      ..cubicTo(15.5 * sx, 12.7 * sy, 14.8 * sx, 12 * sy, 14 * sx, 12 * sy)
      ..lineTo(15.5 * sx, 9.5 * sy)
      ..close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _SvgPathPainter old) => true;
}
