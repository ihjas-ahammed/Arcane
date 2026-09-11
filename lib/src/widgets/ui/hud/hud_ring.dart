import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'hud_types.dart';

class HudRing extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final double stroke;
  final HudTone tone;
  final String? label;
  final String? sub;

  const HudRing({
    super.key,
    required this.value,
    this.max = 100,
    this.size = 64,
    this.stroke = 5,
    this.tone = HudTone.amber,
    this.label,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final c = hudToneFg(tone);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(size, size), painter: _RingPainter(value: value / max, color: c, stroke: stroke)),
        if (label != null || sub != null)
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (label != null)
              SizedBox(
                width: size - stroke * 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(label!,
                      style: GoogleFonts.saira(
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.w700,
                        color: c,
                        height: 1,
                      )),
                ),
              ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, color: JweTheme.textMuted, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
            ],
          ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;

  _RingPainter({required this.value, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final track = Paint()..color = ArcStrokes.hairline..style = PaintingStyle.stroke..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(c, r, track);
    final sweep = (value.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}
