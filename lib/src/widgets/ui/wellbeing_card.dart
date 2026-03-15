import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/theme/wellbeing_theme.dart';
import 'package:arcane/src/widgets/ui/spidey_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class WellbeingCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback onTap;

  const WellbeingCard({
    super.key,
    required this.skill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = skill.maxXp > 0 ? skill.currentXp / skill.maxXp : 0.0;
    final int level = skill.level;
    final Color color = WellbeingTheme.getColor(skill.name);
    final IconData icon = WellbeingTheme.getIcon(skill.name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PersonInfoTheme.bgPanel,
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        skill.name.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          color: PersonInfoTheme.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "LVL $level",
                        style: GoogleFonts.rajdhani(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SpideyProgressBar(progress: progress, color: color),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "${skill.currentXp} / ${skill.maxXp} XP",
                      style: GoogleFonts.rajdhani(
                        color: PersonInfoTheme.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}