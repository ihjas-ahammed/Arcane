import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

class LauncherWallpaperPainter extends CustomPainter {
  final bool isLight;
  final double animationValue;

  LauncherWallpaperPainter({
    required this.isLight,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── 1. Sky Gradient ──────────────────────────────────────────
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? const [
                Color(0xFFEDE8E0),
                Color(0xFFDFD9CE),
                Color(0xFFEDE8E0),
              ]
            : const [
                Color(0xFF050608),
                Color(0xFF0B0B0F),
                Color(0xFF050608),
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, skyPaint);

    // Coordinate space mapping (300 x 380 SVG base)
    final double scaleX = size.width / 300.0;
    final double scaleY = size.height / 380.0;

    Offset pt(double x, double y) => Offset(x * scaleX, y * scaleY);

    // ── 2. Mountain Layer 1 (Back) ────────────────────────────────
    final mtn1Path = Path()
      ..moveTo(pt(0, 250).dx, pt(0, 250).dy)
      ..lineTo(pt(35, 205).dx, pt(35, 205).dy)
      ..lineTo(pt(60, 218).dx, pt(60, 218).dy)
      ..lineTo(pt(95, 160).dx, pt(95, 160).dy)
      ..lineTo(pt(125, 190).dx, pt(125, 190).dy)
      ..lineTo(pt(165, 110).dx, pt(165, 110).dy)
      ..lineTo(pt(200, 150).dx, pt(200, 150).dy)
      ..lineTo(pt(235, 95).dx, pt(235, 95).dy)
      ..lineTo(pt(270, 140).dx, pt(270, 140).dy)
      ..lineTo(pt(300, 120).dx, pt(300, 120).dy)
      ..lineTo(pt(300, 380).dx, pt(300, 380).dy)
      ..lineTo(pt(0, 380).dx, pt(0, 380).dy)
      ..close();

    final mtn1Paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isLight ? const Color(0xFFDCD6CA) : const Color(0xFF141519);
    canvas.drawPath(mtn1Path, mtn1Paint);

    // ── 3. Mountain Layer 2 (Middle) ──────────────────────────────
    final mtn2Path = Path()
      ..moveTo(pt(0, 290).dx, pt(0, 290).dy)
      ..lineTo(pt(40, 245).dx, pt(40, 245).dy)
      ..lineTo(pt(75, 262).dx, pt(75, 262).dy)
      ..lineTo(pt(120, 200).dx, pt(120, 200).dy)
      ..lineTo(pt(150, 232).dx, pt(150, 232).dy)
      ..lineTo(pt(190, 185).dx, pt(190, 185).dy)
      ..lineTo(pt(225, 222).dx, pt(225, 222).dy)
      ..lineTo(pt(262, 190).dx, pt(262, 190).dy)
      ..lineTo(pt(300, 225).dx, pt(300, 225).dy)
      ..lineTo(pt(300, 380).dx, pt(300, 380).dy)
      ..lineTo(pt(0, 380).dx, pt(0, 380).dy)
      ..close();

    final mtn2Paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isLight ? const Color(0xFFD0C9BC) : const Color(0xFF0D0E12);
    canvas.drawPath(mtn2Path, mtn2Paint);

    // ── 4. Mountain Layer 3 (Foreground) ──────────────────────────
    final mtn3Path = Path()
      ..moveTo(pt(0, 330).dx, pt(0, 330).dy)
      ..lineTo(pt(50, 290).dx, pt(50, 290).dy)
      ..lineTo(pt(95, 312).dx, pt(95, 312).dy)
      ..lineTo(pt(140, 270).dx, pt(140, 270).dy)
      ..lineTo(pt(185, 300).dx, pt(185, 300).dy)
      ..lineTo(pt(230, 268).dx, pt(230, 268).dy)
      ..lineTo(pt(300, 310).dx, pt(300, 310).dy)
      ..lineTo(pt(300, 380).dx, pt(300, 380).dy)
      ..lineTo(pt(0, 380).dx, pt(0, 380).dy)
      ..close();

    final mtn3Paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isLight ? const Color(0xFFC4BCAD) : const Color(0xFF08090C);
    canvas.drawPath(mtn3Path, mtn3Paint);

    // ── 5. Red Ridge Lines with Soft Glow ─────────────────────────
    final redColor = LauncherTheme.red;

    final ridgePaintGlow = Paint()
      ..color = redColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * math.min(scaleX, scaleY)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final ridgePaintCore = Paint()
      ..color = redColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * math.min(scaleX, scaleY)
      ..strokeCap = StrokeCap.round;

    final ridges = <List<Offset>>[
      [pt(165, 110), pt(178, 150), pt(170, 185), pt(186, 215)],
      [pt(235, 95), pt(228, 130), pt(240, 160), pt(232, 190)],
      [pt(95, 160), pt(104, 195), pt(96, 228)],
      [pt(120, 200), pt(132, 225), pt(126, 250), pt(140, 270)],
      [pt(190, 185), pt(200, 210), pt(194, 240)],
      [pt(262, 190), pt(256, 215), pt(268, 240)],
      [pt(40, 245), pt(52, 270), pt(46, 290)],
    ];

    for (final ridge in ridges) {
      final p = Path()..moveTo(ridge.first.dx, ridge.first.dy);
      for (int i = 1; i < ridge.length; i++) {
        p.lineTo(ridge[i].dx, ridge[i].dy);
      }
      canvas.drawPath(p, ridgePaintGlow);
      canvas.drawPath(p, ridgePaintCore);
    }

    // ── 6. Diagonal Neon Laser Lines with Glow ────────────────────
    final beamPaintGlow = Paint()
      ..color = redColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * math.min(scaleX, scaleY)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final beamPaintCore = Paint()
      ..color = redColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * math.min(scaleX, scaleY)
      ..strokeCap = StrokeCap.round;

    final beamPaintSubtle = Paint()
      ..color = redColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * math.min(scaleX, scaleY)
      ..strokeCap = StrokeCap.round;

    // Line 1: (20, 60) -> (225, 360)
    canvas.drawLine(pt(20, 60), pt(225, 360), beamPaintGlow);
    canvas.drawLine(pt(20, 60), pt(225, 360), beamPaintCore);

    // Line 2: (135, 130) -> (245, 240)
    canvas.drawLine(pt(135, 130), pt(245, 240), beamPaintGlow);
    canvas.drawLine(pt(135, 130), pt(245, 240), beamPaintCore);

    // Line 3: (300, 30) -> (165, 300)
    canvas.drawLine(pt(300, 30), pt(165, 300), beamPaintGlow);
    canvas.drawLine(pt(300, 30), pt(165, 300), beamPaintSubtle);
  }

  @override
  bool shouldRepaint(covariant LauncherWallpaperPainter oldDelegate) {
    return oldDelegate.isLight != isLight ||
        oldDelegate.animationValue != animationValue;
  }
}
