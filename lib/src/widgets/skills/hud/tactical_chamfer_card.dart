import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tac_colors.dart';

/// 8-Corner Chamfer Polygon Clipper
class TacticalChamferClipper extends CustomClipper<Path> {
  final double cut;
  const TacticalChamferClipper({this.cut = 8.0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final c = math.min(cut, math.min(w / 4, h / 4));

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
    return path;
  }

  @override
  bool shouldReclip(covariant TacticalChamferClipper oldClipper) => oldClipper.cut != cut;
}

/// Tactical HUD Card with Chamfered Edges, 1px border, and top center notch
class TacticalChamferCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double cut;
  final Color? borderColor;
  final Color? bgStart;
  final Color? bgEnd;
  final bool showNotch;

  const TacticalChamferCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.onLongPress,
    this.cut = 8.0,
    this.borderColor,
    this.bgStart,
    this.bgEnd,
    this.showNotch = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: CustomPaint(
        painter: _ChamferCardPainter(
          cut: cut,
          borderColor: borderColor ?? TacColors.borderOuter,
          bgStart: bgStart ?? TacColors.cardBgStart,
          bgEnd: bgEnd ?? TacColors.cardBgEnd,
          showNotch: showNotch,
        ),
        child: ClipPath(
          clipper: TacticalChamferClipper(cut: cut),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              splashColor: TacColors.primaryRed.withValues(alpha: 0.15),
              highlightColor: TacColors.primaryRed.withValues(alpha: 0.08),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChamferCardPainter extends CustomPainter {
  final double cut;
  final Color borderColor;
  final Color bgStart;
  final Color bgEnd;
  final bool showNotch;

  _ChamferCardPainter({
    required this.cut,
    required this.borderColor,
    required this.bgStart,
    required this.bgEnd,
    required this.showNotch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = math.min(cut, math.min(w / 4, h / 4));

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

    // Background Gradient Fill
    final paintFill = Paint()
      ..shader = LinearGradient(
        colors: [bgStart, bgEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    // Border
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, paintBorder);

    // Top center notch
    if (showNotch && w > 80) {
      final notchPaint = Paint()
        ..color = TacColors.notchColor
        ..strokeWidth = 1.5;
      final centerX = w / 2;
      canvas.drawLine(Offset(centerX - 20, 0), Offset(centerX + 20, 0), notchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChamferCardPainter oldDelegate) => true;
}
