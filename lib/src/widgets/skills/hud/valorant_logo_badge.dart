import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'tac_colors.dart';

/// Valorant SVG Crest (Red & White triangles)
class ValorantLogoBadge extends StatelessWidget {
  final double width;
  final double height;
  final Color? primaryColor;

  const ValorantLogoBadge({
    super.key,
    this.width = 22,
    this.height = 18,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ValorantLogoPainter(primaryColor: primaryColor ?? TacColors.primaryRed),
    );
  }
}

class _ValorantLogoPainter extends CustomPainter {
  final Color primaryColor;
  _ValorantLogoPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 80.0;

    // Left red polygon: M40 0 L0 80 L20 80 L50 20 Z
    final leftPath = Path()
      ..moveTo(40 * scaleX, 0)
      ..lineTo(0, 80 * scaleY)
      ..lineTo(20 * scaleX, 80 * scaleY)
      ..lineTo(50 * scaleX, 20 * scaleY)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = primaryColor..style = PaintingStyle.fill);

    // Right white / dark polygon: M60 0 L100 80 L80 80 L50 20 Z
    final rightPath = Path()
      ..moveTo(60 * scaleX, 0)
      ..lineTo(100 * scaleX, 80 * scaleY)
      ..lineTo(80 * scaleX, 80 * scaleY)
      ..lineTo(50 * scaleX, 20 * scaleY)
      ..close();
    canvas.drawPath(
      rightPath,
      Paint()
        ..color = JweTheme.isLight ? const Color(0xFF1E242F) : Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ValorantLogoPainter old) => true;
}
