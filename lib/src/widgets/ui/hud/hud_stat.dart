import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'hud_types.dart';

class HudStat extends StatelessWidget {
  final String? label;
  final String value;
  final String? unit;
  final String? sub;
  final HudTone tone;
  final double size;

  const HudStat({
    super.key,
    this.label,
    required this.value,
    this.unit,
    this.sub,
    this.tone = HudTone.amber,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final c = hudToneFg(tone);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null)
        Text(label!.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.8)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: GoogleFonts.saira(fontSize: size, fontWeight: FontWeight.w700, color: c, height: 1)),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(unit!, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: JweTheme.textMuted)),
        ],
      ]),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.0)),
      ],
    ]);
  }
}
