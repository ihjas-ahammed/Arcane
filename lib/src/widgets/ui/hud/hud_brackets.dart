import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class HudBrackets extends StatelessWidget {
  final Color? color;
  final double size;
  final double thickness;
  final bool all;

  const HudBrackets({
    super.key,
    this.color,
    this.size = 10,
    this.thickness = 1,
    this.all = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? JweTheme.accentAmber;
    return IgnorePointer(
      child: Stack(children: [
        _corner(activeColor, top: 0, left: 0, top1: true, left1: true),
        _corner(activeColor, top: 0, right: 0, top1: true, right1: true, opacity: all ? 1.0 : 0.0),
        _corner(activeColor, bottom: 0, left: 0, bottom1: true, left1: true, opacity: all ? 1.0 : 0.0),
        _corner(activeColor, bottom: 0, right: 0, bottom1: true, right1: true),
      ]),
    );
  }

  Widget _corner(Color activeColor, {double? top, double? bottom, double? left, double? right,
      bool top1 = false, bool bottom1 = false, bool left1 = false, bool right1 = false,
      double opacity = 1.0}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(painter: _BracketPainter(
            color: activeColor, thickness: thickness,
            top: top1, bottom: bottom1, left: left1, right: right1,
          )),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top, bottom, left, right;

  _BracketPainter({required this.color, required this.thickness,
      required this.top, required this.bottom, required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    if (top)    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
    if (bottom) canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
    if (left)   canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
    if (right)  canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
