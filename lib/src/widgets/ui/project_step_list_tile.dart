import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';
import 'package:arcane/src/screens/step_detail_screen.dart'; 
import 'package:arcane/src/widgets/sheets/link_submission_sheet.dart'; // Import Link Sheet
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

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

    // Resolve Linked Task Name
    String? linkedName;
    if (step.linkedTaskId != null && step.linkedParentTaskId != null) {
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == step.linkedParentTaskId);
      if (task != null) {
        if (step.linkedTaskType == 'subtask') {
          final st = task.subTasks.firstWhereOrNull((s) => s.id == step.linkedTaskId);
          linkedName = st?.name;
        } else if (step.linkedTaskType == 'checkpoint') {
          // Flatten search
          for (var sub in task.subTasks) {
            final sst = sub.subSubTasks.firstWhereOrNull((s) => s.id == step.linkedTaskId);
            if (sst != null) {
              linkedName = sst.name;
              break;
            }
          }
        }
      }
    }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: RhombusCheckbox(
                      checked: step.isCompleted,
                      size: CheckboxSize.small,
                      disabled: hasSubsteps || step.linkedTaskId != null, 
                      onChanged: (val) {
                        if (!hasSubsteps && step.linkedTaskId == null) {
                          final updatedStep = step..isCompleted = !step.isCompleted;
                          provider.projectActions.updateStep(mainTaskId, projectId, updatedStep);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  
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
                        if (linkedName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: LinkedTaskIndicator(
                              label: linkedName,
                              onUnlink: () {
                                provider.projectActions.unlinkStep(mainTaskId, projectId, step.id);
                              },
                            ),
                          )
                        else 
                          // Link Button (Small)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context, 
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => LinkSubmissionSheet(
                                    initialMainTaskId: mainTaskId,
                                    initialProjectId: projectId,
                                    initialStepId: step.id,
                                  )
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.linkVariantPlus, size: 12, color: AppTheme.fhTextSecondary),
                                  const SizedBox(width: 4),
                                  const Text("LINK TO TASK", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
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
              
              if (hasSubsteps)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 34),
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