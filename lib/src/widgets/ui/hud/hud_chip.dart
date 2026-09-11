import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'hud_types.dart';
import 'hud_cut_clipper.dart';

class HudChip extends StatelessWidget {
  final String label;
  final HudTone tone;
  final bool large;
  final IconData? icon;

  const HudChip({super.key, required this.label, this.tone = HudTone.neutral, this.large = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = hudToneFg(tone);
    final bg = hudToneBg(tone);
    return ClipPath(
      clipper: HudCutClipper(clip: HudClip.br, cut: 4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 9 : 7, vertical: large ? 5 : 3),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: fg.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: large ? 12 : 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: fg,
                fontSize: large ? 11 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              )),
        ]),
      ),
    );
  }
}
