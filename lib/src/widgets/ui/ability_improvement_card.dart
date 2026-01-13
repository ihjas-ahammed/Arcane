import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AbilityImprovementCard extends StatelessWidget {
  final String name;
  final String reason;
  final int score;

  const AbilityImprovementCard({
    super.key,
    required this.name,
    required this.reason,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withOpacity(0.5),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.fhAccentPurple.withOpacity(0.1),
            ),
            child: Icon(MdiIcons.starFourPoints, size: 16, color: AppTheme.fhAccentPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.fhTextPrimary,
                        fontSize: 14,
                        letterSpacing: 0.5
                      ),
                    ),
                    Text(
                      "+$score",
                      style: const TextStyle(
                        color: AppTheme.fhAccentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                    height: 1.3
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}