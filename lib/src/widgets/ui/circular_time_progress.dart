import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui; // Needed for gradient shaders

class CircularTimeProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final Color color;

  const CircularTimeProgress({
    super.key,
    required this.progress,
    this.isCompleted = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // The HTML container was 300x300, but viewBox was 200x200.
    // We maintain aspect ratio.
    return SizedBox(
      width: 50, 
      height: 50,
      child: CustomPaint(
        painter: _DendroElementPainter(
          progress: isCompleted ? 1.0 : progress,
          baseColor: isCompleted ? const Color(0xFF3bfeb9) : color,
          isCompleted: isCompleted,
        ),
      ),
    );
  }
}

class _DendroElementPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final bool isCompleted;

  _DendroElementPainter({
    required this.progress,
    required this.baseColor,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Setup Coordinate System
    // The SVG viewBox is 0 0 200 200. We scale our drawing to fit the widget size.
    final scale = math.min(size.width, size.height) / 200.0;
    canvas.translate(size.width / 2, size.height / 2); // Move origin to center
    canvas.scale(scale); // Scale to match SVG coordinates

    // --- COLORS FROM HTML ---
    const Color cSpikes = Color(0xFF445561);
    const Color cRingInactive = Color(0xFF5d727d);
    // Gradient definition for Active Ring
    const List<Color> dendroGradientColors = [
      Color(0xFF3bfeb9),
      Color(0xFF7affbd),
      Color(0xFF3bfeb9)
    ];
    const List<double> dendroGradientStops = [0.0, 0.5, 1.0];

    // --- GROUP 1: BACKGROUND ORNAMENT (The dark grey pattern) ---
    final spikePaint = Paint()
      ..color = cSpikes.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final spikeStrokePaint = Paint()
      ..color = cSpikes.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // 1a. Spikes
    // Main Cardinal Spikes (Paths from HTML)
    // d="M0,-85 L10,-55 L0,-45 L-10,-55 Z" ... rotated 4 times
    final Path cardinalSpike = Path()
      ..moveTo(0, -85)
      ..lineTo(10, -55)
      ..lineTo(0, -45)
      ..lineTo(-10, -55)
      ..close();

    // Diagonal Spikes (Smaller)
    // d="M45,-45 L55,-55 L65,-45 L55,-35 Z" ... rotated 4 times
    final Path diagonalSpike = Path()
      ..moveTo(45, -45)
      ..lineTo(55, -55)
      ..lineTo(65, -45)
      ..lineTo(55, -35)
      ..close();

    // Draw Cardinals (0, 90, 180, 270)
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawPath(cardinalSpike, spikePaint);
      canvas.restore();
    }

    // Draw Diagonals (0, 90, 180, 270 relative to their start pos)
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawPath(diagonalSpike, spikePaint);
      canvas.restore();
    }

    // 1b. Inner decorative circle
    final circlePaint = Paint()
      ..color = cSpikes.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(Offset.zero, 42, circlePaint);

    // 1c. Swirl approximations
    // HTML: d="M-20,-20 Q0,-40 20,-20 Q40,0 20,20 Q0,40 -20,20 Q-40,0 -20,-20"
    final Path swirls = Path()
      ..moveTo(-20, -20)
      ..quadraticBezierTo(0, -40, 20, -20)
      ..quadraticBezierTo(40, 0, 20, 20)
      ..quadraticBezierTo(0, 40, -20, 20)
      ..quadraticBezierTo(-40, 0, -20, -20);
    canvas.drawPath(swirls, spikeStrokePaint);


    // --- GROUP 2: THE RINGS ---

    // 2a. Faint Background Ring
    // HTML: d="M 30,100 A 70,70 0 1,1 170,100" (This is an arc from bottom-left to bottom-right going over top)
    // SVG coords are relative to 0,0 top-left.
    // In our centered canvas:
    // 30,100 -> (-70, 0)  | 170,100 -> (70, 0) | Radius 70
    // The SVG path draws the TOP half (180 deg).
    // Note: Standard progress bars usually go 360. The HTML example seemed to be a specialized UI element.
    // However, for a general Task Progress, a full 360 ring is usually expected.
    // I will adapt the "Style" to a full 360 ring for usability, but keep the exact stroke style.
    
    final bgRingPaint = Paint()
      ..color = cRingInactive.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset.zero, 70, bgRingPaint);


    // 2b. The Bright Active Ring (Progress)
    // Gradient Shader
    final Rect arcRect = Rect.fromCircle(center: Offset.zero, radius: 70);
    final gradient = ui.Gradient.sweep(
      Offset.zero,
      dendroGradientColors,
      dendroGradientStops,
      TileMode.clamp,
      -math.pi / 2, // Start angle alignment
      math.pi * 2, // End angle alignment
    );

    final Paint activeRingPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;

    // Glow Filter (Blur)
    final Paint glowPaint = Paint()
      ..color = dendroGradientColors[0]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5); // SVG stdDeviation="2.5" approx

    // Calculate Sweep Angle
    final double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      // Draw Glow Layer
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, glowPaint);
      // Draw Core Layer
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, activeRingPaint);

      // Decorative Caps (Start and End) - replicating the "L 22,100..." logic from SVG
      // Start Cap
      _drawCap(canvas, startAngle, 70, dendroGradientColors[0]);
      // End Cap
      _drawCap(canvas, startAngle + sweepAngle, 70, dendroGradientColors[0]);
    }


    // --- GROUP 3: THE CENTER ICON (Dendro Symbol) ---
    // HTML: transform="translate(100, 100) scale(0.9)"
    // We are already at 100,100 (0,0 in our translated canvas). We just scale.
    canvas.save();
    canvas.scale(0.9);

    final iconStrokePaint = Paint()
      ..color = const Color(0xFF4fffa8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    // Add Glow to Icon
    final iconGlowPaint = Paint()
      ..color = const Color(0xFF4fffa8).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // 3a. Teardrop
    // d="M0,15 Q-12,5 -12,-8 Q-12,-25 0,-35 Q12,-25 12,-8 Q12,5 0,15 Z"
    final Path teardrop = Path()
      ..moveTo(0, 15)
      ..quadraticBezierTo(-12, 5, -12, -8)
      ..quadraticBezierTo(-12, -25, 0, -35)
      ..quadraticBezierTo(12, -25, 12, -8)
      ..quadraticBezierTo(12, 5, 0, 15)
      ..close();

    // 3b. Inner Fill
    // d="M0,8 Q-6,2 -6,-8 Q-6,-18 0,-25 Q6,-18 6,-8 Q6,2 0,8 Z"
    final Path innerFill = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(-6, 2, -6, -8)
      ..quadraticBezierTo(-6, -18, 0, -25)
      ..quadraticBezierTo(6, -18, 6, -8)
      ..quadraticBezierTo(6, 2, 0, 8)
      ..close();
    
    final Paint fillPaint = Paint()
      ..color = const Color(0xFF4fffa8)
      ..style = PaintingStyle.fill;

    // 3c. U Shape / Leaves
    // d="M-22,-5 Q-22,25 0,38 Q22,25 22,-5"
    final Path uShape = Path()
      ..moveTo(-22, -5)
      ..quadraticBezierTo(-22, 25, 0, 38)
      ..quadraticBezierTo(22, 25, 22, -5);

    // 3d. Stem
    // d="M0,38 L0,45"
    final Path stem = Path()
      ..moveTo(0, 38)
      ..lineTo(0, 45);

    // Draw Glows first
    canvas.drawPath(teardrop, iconGlowPaint);
    canvas.drawPath(uShape, iconGlowPaint);
    canvas.drawPath(stem, iconGlowPaint);

    // Draw Strokes
    canvas.drawPath(teardrop, iconStrokePaint);
    canvas.drawPath(innerFill, fillPaint); // Filled
    canvas.drawPath(uShape, iconStrokePaint);
    canvas.drawPath(stem, iconStrokePaint);

    canvas.restore(); // Undo scale(0.9)
  }

  void _drawCap(Canvas canvas, double angle, double radius, Color color) {
    // Replicating the little diamond/square caps from the SVG
    // SVG: L 22,100 L 30,108 Z (small triangles)
    // We'll calculate the position on the circle
    final double x = radius * math.cos(angle);
    final double y = radius * math.sin(angle);

    final Paint capPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Paint capGlow = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle); // Rotate to align with the ring tangent

    // Draw a small rhombus/diamond shape at the tip
    final Path capPath = Path()
      ..moveTo(0, -4)
      ..lineTo(4, 0)
      ..lineTo(0, 4)
      ..lineTo(-4, 0)
      ..close();

    canvas.drawPath(capPath, capGlow);
    canvas.drawPath(capPath, capPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DendroElementPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.baseColor != baseColor ||
           oldDelegate.isCompleted != isCompleted;
  }
}