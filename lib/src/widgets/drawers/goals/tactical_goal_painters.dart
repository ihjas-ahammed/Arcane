import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

extension GoalColorDarkenX on Color {
  Color darken([double amount = 0.15]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Custom Slanted Progress Bar Painter with Slit Cutouts (///)
class TacticalProgressBarPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final bool isLight;

  TacticalProgressBarPainter({
    required this.progress,
    required this.activeColor,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final clamped = progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.08)
          : const Color(0xFF1B1D28)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.15)
          : JweTheme.lineSoft.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final RRect trackRect =
        RRect.fromLTRBR(0, 0, w, h, const Radius.circular(2));
    canvas.drawRRect(trackRect, trackPaint);
    canvas.drawRRect(trackRect, borderPaint);

    if (clamped <= 0) return;

    final fillW = w * clamped;

    final fillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final RRect fillRect =
        RRect.fromLTRBR(0, 0, fillW, h, const Radius.circular(2));
    canvas.drawRRect(fillRect, fillPaint);

    // Slanted end cap lines /// (if progress fill > 16px)
    if (fillW > 16) {
      final slitPaint = Paint()
        ..color = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      for (int i = 0; i < 3; i++) {
        final x = fillW - 4 - (i * 3.5);
        canvas.drawLine(Offset(x, 0.5), Offset(x - 2.5, h - 0.5), slitPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TacticalProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight;
  }
}

/// Custom Painter for Tactical Goal Card Chassis with Chamfered Corners & Left Color Bar
class TacticalCardPainter extends CustomPainter {
  final Color activeColor;
  final bool isLight;
  final bool isDone;

  TacticalCardPainter({
    required this.activeColor,
    required this.isLight,
    required this.isDone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const chamfer = 12.0;

    final cardColor = isDone ? activeColor.darken(0.15) : activeColor;

    final bgPaint = Paint()
      ..color = isLight ? const Color(0xFFEDE9DF) : const Color(0xFF11121A)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = cardColor.withValues(alpha: isDone ? 0.85 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDone ? 1.4 : 1.2;

    final path = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(w - 4, 0)
      ..lineTo(w, 4)
      ..lineTo(w, h - 4)
      ..lineTo(w - 4, h)
      ..lineTo(4, h)
      ..lineTo(0, h - 4)
      ..lineTo(0, chamfer)
      ..close();

    canvas.drawPath(path, bgPaint);
    canvas.drawPath(path, borderPaint);

    final accentPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final leftBar = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(0, chamfer)
      ..lineTo(0, h / 2);

    canvas.drawPath(leftBar, accentPaint);
  }

  @override
  bool shouldRepaint(covariant TacticalCardPainter oldDelegate) {
    return oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isDone != isDone;
  }
}
