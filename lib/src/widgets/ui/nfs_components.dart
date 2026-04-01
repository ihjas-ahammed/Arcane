import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';

class NfsHazardBar extends StatelessWidget {
  final String text;
  final Color neonColor;

  const NfsHazardBar({super.key, required this.text, this.neonColor = const Color(0xFF00F0FF)});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
          ),
          child: CustomPaint(
            painter: _HazardStripePainter(neonColor),
          ),
        ),
        Positioned(
          top: -20,
          right: 0,
          child: Transform(
            transform: Matrix4.skewX(-0.1745), // -10 degrees
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                text,
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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

class NfsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color neonColor;
  final VoidCallback onPressed;

  const NfsButton({
    super.key,
    required this.label,
    required this.icon,
    required this.neonColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-0.1745), // -10 deg skew
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: neonColor.withOpacity(0.1),
            border: Border.all(color: neonColor, width: 2),
          ),
          child: Transform(
            transform: Matrix4.skewX(0.1745), // Counter skew text
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: neonColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    color: neonColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NfsPlayButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onTap;

  const NfsPlayButton({
    super.key,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isRunning ? const Color(0xFFFF0055) : const Color(0xFF444444);

    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _PlayBtnClipper(),
        child: Container(
          width: 50,
          height: 50,
          color: bgColor,
          alignment: Alignment.center,
          child: Icon(
            isRunning ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _PlayBtnClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    // clip-path: polygon(10% 0, 100% 0, 100% 90%, 90% 100%, 0 100%, 0 10%);
    final cutX = w * 0.1;
    final cutY = h * 0.1;

    path.moveTo(cutX, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h - cutY);
    path.lineTo(w - cutX, h);
    path.lineTo(0, h);
    path.lineTo(0, cutY);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Background painter for the dotted grid
class NfsGridPainter extends CustomPainter {
  final Color gridColor;
  NfsGridPainter({this.gridColor = const Color(0x1AFFFFFF)}); // 0.1 opacity white

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