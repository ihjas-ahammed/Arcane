import 'package:flutter/material.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class NfsPlayButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onTap;

  const NfsPlayButton({
    super.key,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isRunning ? ArcAccents.neonPink : ArcSurfaces.disabledFill;

    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _PlayBtnClipper(),
        child: Container(
          width: 50,
          height: 50,
          color: bgColor,
          alignment: Alignment.center,
          child: Icon(
            isRunning ? Icons.pause : Icons.play_arrow,
            color: ArcContent.onSwatch(bgColor),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _PlayBtnClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    // clip-path: polygon(10% 0, 100% 0, 100% 90%, 90% 100%, 0 100%, 0 10%);
    final cutX = w * 0.1;
    final cutY = h * 0.1;

    path.moveTo(cutX, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h - cutY);
    path.lineTo(w - cutX, h);
    path.lineTo(0, h);
    path.lineTo(0, cutY);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
