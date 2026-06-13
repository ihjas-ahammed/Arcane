import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD classified-access tiles.
class JweQuickAccessGrid extends StatelessWidget {
  final VoidCallback onArchive;
  final VoidCallback onAdvanced;

  const JweQuickAccessGrid({
    super.key,
    required this.onArchive,
    required this.onAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const HudSectionHead(
        label: 'CLASSIFIED ACCESS',
        code: 'PIN-LOCKED',
        accent: HudTone.amber,
        padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
      ),
      _Tile(
        title: 'REFLECTION ARCHIVE',
        sub: 'Filter, multi-select, export',
        icon: MdiIcons.archiveOutline,
        accent: JweTheme.accentCyan,
        tone: HudTone.cyan,
        code: 'A-01',
        onTap: onArchive,
      ),
      const SizedBox(height: 6),
      _Tile(
        title: 'ADVANCED TOOLS',
        sub: 'Therapy · simulate · prompts',
        icon: MdiIcons.hexagonMultipleOutline,
        accent: JweTheme.accentTeal,
        tone: HudTone.teal,
        code: 'A-02',
        onTap: onAdvanced,
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  final Color accent;
  final HudTone tone;
  final String code;
  final VoidCallback onTap;

  const _Tile({
    required this.title,
    required this.sub,
    required this.icon,
    required this.accent,
    required this.tone,
    required this.code,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: HudPanel(
        clip: HudClip.br,
        accent: accent,
        brackets: false,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.40), width: 1),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(
                  code,
                  style: GoogleFonts.jetBrainsMono(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 6),
                Container(width: 4, height: 1, color: accent.withValues(alpha: 0.40)),
              ]),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.saira(
                  color: JweTheme.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.inter(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ]),
          ),
          Icon(MdiIcons.chevronRight, size: 18, color: accent.withValues(alpha: 0.60)),
        ]),
      ),
    );
  }
}
