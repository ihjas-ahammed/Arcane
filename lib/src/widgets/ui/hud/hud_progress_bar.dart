import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'hud_types.dart';

class HudProgressBar extends StatelessWidget {
  final double value; // 0-100
  final HudTone tone;
  final int segments;
  final double height;
  final bool showLabel;

  const HudProgressBar({
    super.key,
    required this.value,
    this.tone = HudTone.amber,
    this.segments = 24,
    this.height = 6,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = hudToneFg(tone);
    final filled = (value / 100 * segments).round().clamp(0, segments);
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(segments, (i) {
              final on = i < filled;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                  decoration: BoxDecoration(
                    color: on ? c : ArcStrokes.hairline,
                    boxShadow: on ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 3)] : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      if (showLabel) ...[
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text('${value.round()}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
        ),
      ],
    ]);
  }
}
