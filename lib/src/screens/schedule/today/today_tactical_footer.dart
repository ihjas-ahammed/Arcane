import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'tactical_planner_painters.dart';

class TacticalFooter extends StatelessWidget {
  const TacticalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: ValorantMarkPainter(
                color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SMALL STEPS BIG RESULTS —',
              style: GoogleFonts.rajdhani(
                color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF62778D),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
