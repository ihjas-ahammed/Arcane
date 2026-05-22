import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD trait tile — telemetry row with segmented bar.
class WellbeingCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback onTap;

  const WellbeingCard({super.key, required this.skill, required this.onTap});

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  @override
  Widget build(BuildContext context) {
    final progress = skill.maxXp > 0 ? skill.currentXp / skill.maxXp : 0.0;
    final level = skill.level;
    final color = WellbeingTheme.getColor(skill.name);
    final icon = WellbeingTheme.getIcon(skill.name);
    final tone = _toneFor(color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: HudPanel(
          clip: HudClip.br,
          accent: color,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.40), width: 1),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skill.name.toUpperCase(),
                  style: GoogleFonts.saira(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                'LVL $level',
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            HudProgressBar(value: progress * 100, tone: tone, segments: 18, height: 4),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                '${skill.currentXp.toString().padLeft(4)} / ${skill.maxXp} XP',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
