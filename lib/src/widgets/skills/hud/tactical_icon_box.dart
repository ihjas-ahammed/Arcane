import 'package:flutter/material.dart';
import 'tac_colors.dart';

/// Tactical Icon Container with 4 Corner Red L-Brackets (Matching HTML tech-icon-container)
class TacticalIconBox extends StatelessWidget {
  final Widget icon;
  final double size;
  final Color? accent;

  const TacticalIconBox({
    super.key,
    required this.icon,
    this.size = 58,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TacColors.iconBorder, width: 1),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [TacColors.iconBgStart, TacColors.iconBgEnd],
        ),
      ),
      child: Stack(
        children: [
          // 4 Corner L-Brackets
          Positioned(top: -1, left: -1, child: _buildBracket(true, true, effectiveAccent)),
          Positioned(top: -1, right: -1, child: _buildBracket(true, false, effectiveAccent)),
          Positioned(bottom: -1, left: -1, child: _buildBracket(false, true, effectiveAccent)),
          Positioned(bottom: -1, right: -1, child: _buildBracket(false, false, effectiveAccent)),
          Center(child: icon),
        ],
      ),
    );
  }

  Widget _buildBracket(bool isTop, bool isLeft, Color color) {
    return CustomPaint(
      size: const Size(5, 5),
      painter: _FourCornerPainter(color: color, isTop: isTop, isLeft: isLeft),
    );
  }
}

class _FourCornerPainter extends CustomPainter {
  final Color color;
  final bool isTop;
  final bool isLeft;

  _FourCornerPainter({required this.color, required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourCornerPainter old) => true;
}
