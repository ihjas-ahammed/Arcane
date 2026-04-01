import 'package:flutter/material.dart';
import 'dart:math' as math;

class HexCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const cut = 15.0;

    path.moveTo(cut, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - cut);
    path.lineTo(size.width - cut, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, cut);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexButtonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    // Polygon: 10% 0, 90% 0, 100% 50%, 90% 100%, 10% 100%, 0% 50%
    final cutX = w * 0.1;
    final halfY = h * 0.5;

    path.moveTo(cutX, 0);
    path.lineTo(w - cutX, 0);
    path.lineTo(w, halfY);
    path.lineTo(w - cutX, h);
    path.lineTo(cutX, h);
    path.lineTo(0, halfY);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

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
      ..color = Colors.white.withOpacity(0.1)
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
        activePaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant HexProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color;
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