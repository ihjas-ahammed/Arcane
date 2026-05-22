import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
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
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Indicator
            Container(
              width: 48,
              decoration: BoxDecoration(
                color: AppTheme.fhAccentGreen.withOpacity(0.1),
                border: Border(right: BorderSide(color: AppTheme.fhAccentGreen.withOpacity(0.3))),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.chevronUp, size: 16, color: AppTheme.fhAccentGreen),
                    Text(
                      "$score",
                      style: const TextStyle(
                        color: AppTheme.fhAccentGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.fhTextPrimary,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        fontFamily: AppTheme.fontDisplay,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: const TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}