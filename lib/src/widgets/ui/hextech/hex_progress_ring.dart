import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class HexProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  HexProgressRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    // Background Ring
    final bgPaint = Paint()
      ..color = ArcSurfaces.ink(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      // Active Ring
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2); // Glow

      final startAngle = -math.pi / 2; // Start from top
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HexProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class HexProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;

  const HexProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: HexProgressRingPainter(
          progress: progress,
          color: color,
        ),
      ),
    );
  }
}
