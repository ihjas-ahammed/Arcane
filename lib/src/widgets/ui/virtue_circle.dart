// lib/src/widgets/ui/virtue_circle.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class VirtueCircle extends StatefulWidget {
  final Skill skill;
  final VoidCallback? onTap;
  final int? momentumLevel;
  final double? momentumProgress;

  const VirtueCircle({
    super.key,
    required this.skill,
    this.onTap,
    this.momentumLevel,
    this.momentumProgress,
  });

  @override
  State<VirtueCircle> createState() => _VirtueCircleState();
}

class _VirtueCircleState extends State<VirtueCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Initial animation setup
    _updateAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(VirtueCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.momentumProgress != widget.momentumProgress ||
        oldWidget.skill.currentXp != widget.skill.currentXp) {
      _updateAnimation();
      _controller.forward(from: 0);
    }
  }

  void _updateAnimation() {
    final double targetProgress = widget.momentumProgress ??
        (widget.skill.currentXp / widget.skill.maxXp);

    _animation = Tween<double>(begin: 0, end: targetProgress.clamp(0.0, 1.0))
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get color => _getSkillColor(widget.skill.name);
  IconData get icon => _getSkillIcon(widget.skill.name);

  static Color _getSkillColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return Colors.blueAccent;
      case 'courage':
        return Colors.redAccent;
      case 'humanity':
        return Colors.pinkAccent;
      case 'justice':
        return Colors.amber;
      case 'temperance':
        return Colors.tealAccent;
      case 'transcendence':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  static IconData _getSkillIcon(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return MdiIcons.brain;
      case 'courage':
        return MdiIcons.sword;
      case 'humanity':
        return MdiIcons.handHeart;
      case 'justice':
        return MdiIcons.scaleBalance;
      case 'temperance':
        return MdiIcons.yinYang;
      case 'transcendence':
        return MdiIcons.starFourPoints;
      default:
        return MdiIcons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int displayLevel = widget.momentumLevel ?? widget.skill.level;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.transparent)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(60, 60),
                        painter: _CircularProgressPainter(
                          progress: _animation.value,
                          color: color,
                          trackColor: AppTheme.fhBgDeepDark,
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(height: 2),
                      Text(displayLevel.toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.skill.name.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.fhTextSecondary,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          ],
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3; // Padding for stroke
    const startAngle = -3.14159 / 2; // Start from top
    final sweepAngle = 2 * 3.14159 * progress;

    // Draw Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 // Slightly thicker
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Draw Progress
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Add explicit glow/shadow for "better" feel if progress > 0
    if (progress > 0) {
      progressPaint.shader = null; // Reset shader
      // Simple glow using shadow
      final shadowPath = Path();
      shadowPath.addArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepAngle);
      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = color.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
