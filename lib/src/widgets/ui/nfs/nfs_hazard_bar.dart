import 'package:flutter/material.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class NfsHazardBar extends StatelessWidget {
  final String text;
  final Color? neonColor;

  const NfsHazardBar({super.key, required this.text, this.neonColor});

  @override
  Widget build(BuildContext context) {
    final Color neon = neonColor ?? ArcAccents.neonCyan;
    // "Chrome" of the hazard bar: primary content color as the solid chip,
    // with the mode-correct contrast color for the label on it.
    final Color chrome = ArcContent.primary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: chrome),
          ),
          child: CustomPaint(
            painter: _HazardStripePainter(neon),
          ),
        ),
        Positioned(
          top: -20,
          right: 0,
          child: Transform(
            transform: Matrix4.skewX(-0.1745), // -10 degrees
            child: Container(
              color: chrome,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                text,
                style: TextStyle(color: ArcContent.onSwatch(chrome), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  final Color color;
  _HazardStripePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    // Draw repeating diagonal lines
    for (double i = -size.height; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0), 
        Offset(i + size.height, size.height), 
        paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) => oldDelegate.color != color;
}
