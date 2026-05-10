import 'package:flutter/material.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/sheets/project_options_sheet.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
    
    final effectiveBorderColor = project.isActive ? accentColor : JweTheme.border;
    final effectiveTextColor = project.isActive ? JweTheme.textWhite : JweTheme.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: JweTheme.panel,
            border: Border(left: BorderSide(color: effectiveBorderColor, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title.toUpperCase(),
                      style: GoogleFonts.chakraPetch(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.0,
                          color: effectiveTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: project.isActive 
                        ? accentColor.withOpacity(0.1) 
                        : Colors.transparent,
                      border: Border.all(color: project.isActive ? accentColor.withOpacity(0.5) : JweTheme.border)
                    ),
                    child: Text(
                      "$progressPercentage%",
                      style: TextStyle(
                        color: project.isActive ? accentColor : JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openOptions(context),
                    child:  Icon(
                      MdiIcons.dotsVertical,
                      size: 20,
                      color: JweTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                mainTaskName.toUpperCase(),
                style: TextStyle(
                  color: JweTheme.textMuted.withOpacity(0.7),
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 16),

              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(color: JweTheme.bgBase, border: Border.all(color: JweTheme.border)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: project.isActive ? accentColor : AppTheme.fhTextDisabled),
                ),
              ),
              
              const SizedBox(height: 12),
              
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
                            color: JweTheme.textMuted, fontSize: 11),
                      ),
                    )
                  else
                    const Spacer(),
                    
                  Text(
                    "$completedSteps / $totalSteps OBJECTIVES",
                    style: const TextStyle(
                        color: JweTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}