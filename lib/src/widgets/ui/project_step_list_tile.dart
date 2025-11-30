import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/screens/step_detail_screen.dart'; 
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectStepListTile extends StatelessWidget {
  final ProjectStep step;
  final String mainTaskId;
  final String projectId;
  final String indexPrefix;

  const ProjectStepListTile({
    super.key,
    required this.step,
    required this.mainTaskId,
    required this.projectId,
    required this.indexPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final double progress = step.calculateProgress();
    final int percentage = (progress * 100).toInt();
    final bool hasSubsteps = step.substeps.isNotEmpty;

    // Status Colors
    Color statusColor = AppTheme.fhAccentTeal;
    if (percentage == 100) statusColor = AppTheme.fhAccentGreen;
    if (percentage == 0) statusColor = AppTheme.fhTextDisabled;

    return Card(
      color: AppTheme.fhBgDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to recursive step detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StepDetailScreen(
                step: step,
                mainTaskId: mainTaskId,
                projectId: projectId,
                stepNumber: indexPrefix,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Checkbox: Only active if leaf node. If parent, it's read-only indicator.
                  RhombusCheckbox(
                    checked: step.isCompleted,
                    size: CheckboxSize.small,
                    disabled: hasSubsteps, // Disable manual toggle if it relies on children
                    onChanged: (val) {
                      if (!hasSubsteps) {
                        final updatedStep = step..isCompleted = !step.isCompleted;
                        provider.projectActions.updateStep(mainTaskId, projectId, updatedStep);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$indexPrefix. ${step.title}",
                          style: TextStyle(
                            color: step.isCompleted ? AppTheme.fhTextSecondary : AppTheme.fhTextPrimary,
                            decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (step.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              step.description,
                              style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Metadata / Arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasSubsteps)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "$percentage%",
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                       const SizedBox(height: 4),
                       Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary, size: 20),
                    ],
                  )
                ],
              ),
              
              // Mini Progress Bar for non-leaf nodes
              if (hasSubsteps)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 34), // Indent to align with text
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.fhBgDeepDark,
                      color: statusColor,
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}