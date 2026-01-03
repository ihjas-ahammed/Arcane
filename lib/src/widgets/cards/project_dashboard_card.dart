import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/sheets/project_options_sheet.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectDashboardCard extends StatelessWidget {
  final Project project;
  final String mainTaskId;
  final String mainTaskName;
  final Color accentColor;
  final VoidCallback onTap;

  const ProjectDashboardCard({
    super.key,
    required this.project,
    required this.mainTaskId,
    required this.mainTaskName,
    required this.accentColor,
    required this.onTap,
  });

  void _openOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProjectOptionsSheet(
        project: project,
        currentMainTaskId: mainTaskId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = project.calculateProgress();
    final totalSteps = project.steps.length;
    final completedSteps = project.completedStepsCount;
    final int progressPercentage = (progress * 100).toInt();
    
    // Visual tweak for inactive projects
    final effectiveBorderColor = project.isActive ? accentColor.withValues(alpha: 0.3) : AppTheme.fhBorderColor.withValues(alpha: 0.1);
    final effectiveTextColor = project.isActive ? AppTheme.fhTextPrimary : AppTheme.fhTextDisabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ValorantCard(
        borderColor: effectiveBorderColor,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title.toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: AppTheme.fontDisplay,
                        letterSpacing: 1.0,
                        color: effectiveTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: project.isActive 
                      ? accentColor.withValues(alpha: 0.2) 
                      : Colors.black12,
                  child: Text(
                    "$progressPercentage%",
                    style: TextStyle(
                      color: project.isActive ? accentColor : AppTheme.fhTextDisabled,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontDisplay
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Options Button
                GestureDetector(
                  onTap: () => _openOptions(context),
                  child: Icon(
                    MdiIcons.dotsVertical,
                    size: 20,
                    color: AppTheme.fhTextSecondary,
                  ),
                ),
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

            // Progress Bar
            Container(
              height: 4,
              width: double.infinity,
              color: AppTheme.fhBgDeepDark,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: project.isActive ? accentColor : AppTheme.fhTextDisabled),
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