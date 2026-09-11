import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ValorantMarkPainter extends CustomPainter {
  final Color color;
  ValorantMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path1 = Path()
      ..moveTo(w * 0.15, h)
      ..lineTo(w * 0.45, 0)
      ..lineTo(w * 0.55, 0)
      ..lineTo(w * 0.25, h)
      ..close();
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(w * 0.55, h)
      ..lineTo(w * 0.85, 0)
      ..lineTo(w * 0.95, 0)
      ..lineTo(w * 0.65, h)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant ValorantMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Cyberpunk Tactical Background Art matching the SVG canvas from HTML
class TacticalBackgroundPainter extends CustomPainter {
  const TacticalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isLight = JweTheme.isLight;
    final accentRed = isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B);

    // 1. Dot Grid pattern (24x24, circle at cx: 2, cy: 2, r: 0.8)
    final dotColor = isLight
        ? const Color(0xFFC5BCAC).withValues(alpha: 0.45)
        : const Color(0xFF172433).withValues(alpha: 0.6);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    for (double x = 0; x < w; x += 24.0) {
      for (double y = 0; y < h; y += 24.0) {
        canvas.drawCircle(Offset(x + 2, y + 2), 0.9, dotPaint);
      }
    }

    // Scale factors from reference viewBox 440 x 900
    final sx = w / 440.0;
    final sy = h / 900.0;

    // 2. Top Red Slash Gradient Polygon: 340,0 440,0 440,70 370,70
    final slashPath = Path()
      ..moveTo(340 * sx, 0)
      ..lineTo(w, 0)
      ..lineTo(w, 70 * sy)
      ..lineTo(370 * sx, 70 * sy)
      ..close();

    final slashGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accentRed.withValues(alpha: isLight ? 0.2 : 0.3),
        accentRed.withValues(alpha: 0.0),
      ],
    );
    final slashRect = Rect.fromLTRB(340 * sx, 0, w, 70 * sy);
    final slashPaint = Paint()
      ..shader = slashGradient.createShader(slashRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(slashPath, slashPaint);

    // 3. Top Stroke Line: M 330 0 L 365 70 L 440 70
    final topStrokePath = Path()
      ..moveTo(330 * sx, 0)
      ..lineTo(365 * sx, 70 * sy)
      ..lineTo(w, 70 * sy);
    final topStrokePaint = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.35 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(topStrokePath, topStrokePaint);

    // 4. Bottom Polygon 1: 160,900 240,820 260,820 180,900
    final bottomPoly1 = Path()
      ..moveTo(160 * sx, h)
      ..lineTo(240 * sx, h - 80 * sy)
      ..lineTo(260 * sx, h - 80 * sy)
      ..lineTo(180 * sx, h)
      ..close();
    final bottomPaint1 = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.12 : 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPoly1, bottomPaint1);

    // 5. Bottom Polygon 2: 185,900 250,835 255,835 190,900
    final bottomPoly2 = Path()
      ..moveTo(185 * sx, h)
      ..lineTo(250 * sx, h - 65 * sy)
      ..lineTo(255 * sx, h - 65 * sy)
      ..lineTo(190 * sx, h)
      ..close();
    final bottomPaint2 = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.25 : 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPoly2, bottomPaint2);

    // 6. Bottom Line: x1=260 y1=840 x2=340 y2=840
    final bottomLinePaint = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.25 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(260 * sx, h - 60 * sy),
      Offset(340 * sx, h - 60 * sy),
      bottomLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant TacticalBackgroundPainter oldDelegate) => false;
}

/// Clipper for 4-corner chamfer (Layout 1: Full-width row)
class Chamfer4CornerClipper extends CustomClipper<Path> {
  final double chamfer;
  const Chamfer4CornerClipper({this.chamfer = 10.0});

  @override
  Path getClip(Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant Chamfer4CornerClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}

/// Tactical border & bracket painter for planned cards (Card 1, Card 2, Card 3)
class TacticalCardBorderPainter extends CustomPainter {
  final Color themeColor;
  final double chamfer;
  final double bracketSize;

  const TacticalCardBorderPainter({
    required this.themeColor,
    this.chamfer = 10.0,
    this.bracketSize = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    // 1px border around chamfered path
    final borderPaint = Paint()
      ..color = JweTheme.isLight ? JweTheme.border : const Color(0xFF1A2736)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    final resolvedColor = JweTheme.calibrate(themeColor);

    // 3px solid theme color along left edge
    final leftEdgePaint = Paint()
      ..color = resolvedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, c), Offset(0, h - c), leftEdgePaint);

    // Top-left bracket following the chamfer
    if (bracketSize > 0) {
      final bracketPaint = Paint()
        ..color = resolvedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final bracketPath = Path()
        ..moveTo(0, c + bracketSize)
        ..lineTo(0, c)
        ..lineTo(c, 0)
        ..lineTo(c + bracketSize, 0);
      canvas.drawPath(bracketPath, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TacticalCardBorderPainter oldDelegate) =>
      oldDelegate.themeColor != themeColor ||
      oldDelegate.chamfer != chamfer ||
      oldDelegate.bracketSize != bracketSize;
}

/// Custom square checkbox matching HTML .custom-check
class CustomSquareCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const CustomSquareCheck({
    super.key,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cyan = JweTheme.accentCyan;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: checked
              ? cyan.withValues(alpha: JweTheme.isLight ? 0.15 : 0.2)
              : (JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF0B1219)),
          border: Border.all(
            color: checked ? cyan : (JweTheme.isLight ? JweTheme.border : const Color(0xFF334155)),
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: checked
            ? Text(
                '✓',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: cyan,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}
