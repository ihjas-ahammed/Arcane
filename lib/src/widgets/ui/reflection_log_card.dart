// lib/src/widgets/ui/reflection_log_card.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ReflectionLogCard extends StatelessWidget {
  final ReflectionLog log;

  const ReflectionLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Use fold to safely sum XP, handles empty maps gracefully
    final totalXp = log.xpGained.values.fold(0, (sum, xp) => sum + xp);

    return Card(
      color: AppTheme.fhBgDark,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.3))
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    log.trigger.isNotEmpty ? log.trigger : "Reflection Log",
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 13
                    ),
                  ),
                ),
                if (totalXp > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.fhAccentGold.withValues(alpha: 0.3))
                    ),
                    child: Text(
                      "+$totalXp XP", 
                      style: const TextStyle(
                        color: AppTheme.fhAccentGold, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              log.aiFeedback.isNotEmpty ? log.aiFeedback : "No feedback recorded.",
              style: const TextStyle(
                color: AppTheme.fhTextSecondary, 
                fontSize: 11, 
                fontStyle: FontStyle.italic
              ),
            ),
          ],
        ),
      ),
    );
  }
}