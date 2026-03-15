import 'package:flutter/material.dart';

class SpideyProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const SpideyProgressBar({
    super.key,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-0.3),
      child: Container(
        height: 6,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}