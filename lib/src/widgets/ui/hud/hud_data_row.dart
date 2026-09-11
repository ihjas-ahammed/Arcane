import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'hud_types.dart';

class HudDataRow extends StatelessWidget {
  final String label;
  final String value;
  final HudTone? tone;
  final bool accent;

  const HudDataRow({super.key, required this.label, required this.value, this.tone, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final c = accent ? JweTheme.accentAmber : (tone == null ? JweTheme.textWhite : hudToneFg(tone!));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: JweTheme.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: c,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}
