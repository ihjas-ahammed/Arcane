import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD inspect-date pill.
class JweDateSelector extends StatelessWidget {
  final String dateStr;
  final VoidCallback onTap;
  final Color? accentColor;

  const JweDateSelector({
    super.key,
    required this.dateStr,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? JweTheme.accentCyan;

    return InkWell(
      onTap: onTap,
      child: HudPanel(
        clip: HudClip.br,
        accent: accent,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          HudReticle(size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '// INSPECT DATE',
                  style: GoogleFonts.jetBrainsMono(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr.toUpperCase(),
                  style: GoogleFonts.saira(
                    color: JweTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.40), width: 1),
            ),
            child: Icon(MdiIcons.calendarBlank, size: 14, color: accent),
          ),
        ]),
      ),
    );
  }
}
