// lib/src/widgets/dialogs/skill_detail_dialog.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class SkillDetailDialog extends StatelessWidget {
  final Skill skill;
  final int xpGainedToday;
  final Color color;
  final IconData icon;

  const SkillDetailDialog({
    super.key,
    required this.skill,
    required this.xpGainedToday,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = skill.currentXp / skill.maxXp;
    
    return Dialog(
      backgroundColor: AppTheme.fhBgMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              skill.name.toUpperCase(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.fhTextPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5
              ),
            ),
            const SizedBox(height: 8),
            Text(
              skill.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.fhTextSecondary,
                fontStyle: FontStyle.italic
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("LEVEL ${skill.level}", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text("${skill.currentXp} / ${skill.maxXp} XP", style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppTheme.fhBgDeepDark,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Improved Today", style: TextStyle(color: AppTheme.fhTextSecondary)),
                  Text(
                    "+$xpGainedToday XP", 
                    style: TextStyle(
                      color: xpGainedToday > 0 ? AppTheme.fhAccentGreen : AppTheme.fhTextDisabled,
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fhBgDark,
                side: BorderSide(color: color),
                minimumSize: const Size(double.infinity, 44)
              ),
              child: Text("CLOSE", style: TextStyle(color: color)),
            )
          ],
        ),
      ),
    );
  }
}