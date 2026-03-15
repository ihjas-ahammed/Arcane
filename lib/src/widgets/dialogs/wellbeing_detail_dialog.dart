import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/theme/wellbeing_theme.dart';
import 'package:arcane/src/widgets/ui/spidey_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

class WellbeingDetailDialog extends StatelessWidget {
  final Skill skill;
  final int xpGainedToday;

  const WellbeingDetailDialog({
    super.key,
    required this.skill,
    required this.xpGainedToday,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = skill.maxXp > 0 ? skill.currentXp / skill.maxXp : 0.0;
    final Color color = WellbeingTheme.getColor(skill.name);
    final IconData icon = WellbeingTheme.getIcon(skill.name);

    return Dialog(
      backgroundColor: PersonInfoTheme.bgPanel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              skill.name.toUpperCase(),
              style: GoogleFonts.rajdhani(
                color: PersonInfoTheme.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              skill.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PersonInfoTheme.textGrey,
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "LEVEL ${skill.level}",
                  style: GoogleFonts.rajdhani(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${skill.currentXp} / ${skill.maxXp} XP",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SpideyProgressBar(progress: progress, color: color),
            
            const SizedBox(height: 24),
            
            // Daily Momentum
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PersonInfoTheme.bgDark,
                border: Border.all(color: const Color(0xFF1f2f40)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "7-DAY MOMENTUM",
                    style: GoogleFonts.rajdhani(
                      color: PersonInfoTheme.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    "+$xpGainedToday XP",
                    style: GoogleFonts.rajdhani(
                      color: xpGainedToday > 0 ? PersonInfoTheme.spideyCyan : PersonInfoTheme.textGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: "ACKNOWLEDGE",
                color: color,
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }
}