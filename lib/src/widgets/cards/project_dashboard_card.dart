import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
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
    // Force recalc to update UI
    final progress = project.calculateProgress();
    final totalSteps = project.steps.length;
    final completedSteps = project.completedStepsCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark, // Dark card background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.fhTextPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Row
            Row(
              children: [
                // Circular Progress
                SizedBox(
                  width: 40, 
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.fhBgDeepDark,
                    color: accentColor,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$completedSteps/$totalSteps Steps Completed",
                        style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (project.description.isNotEmpty)
                        Text(
                          project.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
                        )
                      else 
                          Text(
                          "Linked to: $mainTaskName",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.6), fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}