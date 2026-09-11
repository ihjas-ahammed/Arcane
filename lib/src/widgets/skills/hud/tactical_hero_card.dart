import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'tac_colors.dart';

/// Tactical Hero Card with Radial Glow and Red L-Brackets at Top-Left & Bottom-Right
class TacticalHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const TacticalHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TacColors.cardBgEnd,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TacColors.borderOuter, width: 1),
        gradient: RadialGradient(
          center: const Alignment(0.7, 0.0),
          radius: 1.2,
          colors: [
            effectiveAccent.withValues(alpha: JweTheme.isLight ? 0.10 : 0.14),
            TacColors.heroBgEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Top-Left Red L-Bracket
          Positioned(
            top: -1,
            left: -1,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CornerBracketPainter(color: effectiveAccent, isTopLeft: true),
            ),
          ),
          // Bottom-Right Red L-Bracket
          Positioned(
            bottom: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CornerBracketPainter(color: effectiveAccent, isTopLeft: false),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final bool isTopLeft;
  _CornerBracketPainter({required this.color, required this.isTopLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTopLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) => true;
}
