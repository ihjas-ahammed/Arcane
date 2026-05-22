import 'package:flutter/material.dart';
import 'package:missions/theme/valorant_theme.dart';

/// A container with the signature "cut corner" aesthetic of Valorant.
class ValorantContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool border;
  final Color? backgroundColor;

  const ValorantContainer({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.border = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CutCornerClipper(),
      child: Container(
        width: width,
        height: height,
        color: backgroundColor ?? ValorantColors.darkGrey,
        child: Stack(
          children: [
            Padding(
              padding: padding,
              child: child,
            ),
            if (border)
              Positioned.fill(
                child: CustomPaint(
                  painter: _BorderPainter(),
                ),
              ),
            // Decorative little square in top right
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                color: ValorantColors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CutCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const cutSize = 20.0;

    // Start top left
    path.moveTo(0, 0);
    // Top line to near right corner
    path.lineTo(size.width - cutSize, 0);
    // Cut top-right corner? No, let's cut Bottom-Right for the "card" look
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - cutSize);
    // Cut bottom-right
    path.lineTo(size.width - cutSize, size.height);
    // Bottom line to left
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ValorantColors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const cutSize = 20.0;
    final path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - cutSize);
    path.lineTo(size.width - cutSize, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
