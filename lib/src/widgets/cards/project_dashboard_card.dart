import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectDashboardCard extends StatelessWidget {
  final Project project;
  final String mainTaskId;
  final String mainTaskName;
  final Color accentColor;

  const ProjectDashboardCard({
    super.key,
    required this.project,
    required this.mainTaskId,
    required this.mainTaskName,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = project.calculateProgress();
    final totalSteps = project.steps.length;
    final completedSteps = project.completedStepsCount;
    final int progressPercentage = (progress * 100).toInt();

    // Use ValorantCard for styling
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ValorantCard(
        borderColor: accentColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.title.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: AppTheme.fontDisplay,
                        letterSpacing: 1.0,
                        color: AppTheme.fhTextPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: accentColor.withValues(alpha: 0.2),
                  child: Text(
                    "$progressPercentage%",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontDisplay
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              mainTaskName.toUpperCase(),
              style: TextStyle(
                color: AppTheme.fhTextSecondary.withValues(alpha: 0.7),
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 12),

            // Custom Linear Progress Bar (Sharp)
            Container(
              height: 4,
              width: double.infinity,
              color: AppTheme.fhBgDeepDark,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: accentColor),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (project.description.isNotEmpty)
                  Expanded(
                    child: Text(
                      project.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.fhTextSecondary, fontSize: 11),
                    ),
                  )
                else
                  const Spacer(),
                  
                Text(
                  "$completedSteps / $totalSteps OBJECTIVES",
                  style: TextStyle(
                      color: AppTheme.fhTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}