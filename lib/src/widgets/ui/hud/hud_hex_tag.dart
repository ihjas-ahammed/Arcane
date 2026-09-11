import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'hud_types.dart';

class HudHexTag extends StatelessWidget {
  final String code;
  final HudTone tone;
  final Color? color;

  const HudHexTag({
    super.key,
    required this.code,
    this.tone = HudTone.amber,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? hudToneFg(tone);
    return SizedBox(
      width: 28, height: 32,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(28, 32), painter: _HexPainter(color: c)),
        Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 1)
      ..lineTo(w - 1, h * 0.25)
      ..lineTo(w - 1, h * 0.75)
      ..lineTo(w / 2, h - 1)
      ..lineTo(1, h * 0.75)
      ..lineTo(1, h * 0.25)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
