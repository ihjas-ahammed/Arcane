import 'package:flutter/material.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'hud_types.dart';

class HudBar extends StatelessWidget {
  final double value;
  final double max;
  final HudTone tone;
  final double height;
  final Color? color;

  const HudBar({
    super.key,
    required this.value,
    this.max = 100,
    this.tone = HudTone.amber,
    this.height = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? hudToneFg(tone);
    final pct = (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      color: ArcStrokes.hairline,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            decoration: BoxDecoration(
              color: c,
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}
