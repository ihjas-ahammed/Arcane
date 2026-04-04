import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';
import 'package:arcane/src/screens/step_detail_screen.dart'; 
import 'package:arcane/src/widgets/sheets/link_submission_sheet.dart'; 
import 'package:arcane/src/widgets/ui/jwe_progress_bar.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';

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

    Color statusColor = JweTheme.accentCyan;
    if (percentage == 100) statusColor = JweTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: InkWell(
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
                          "$indexPrefix. ${step.title}".toUpperCase(),
                          style: GoogleFonts.chakraPetch(
                            color: step.isCompleted ? JweTheme.textMuted : JweTheme.textWhite,
                            decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
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
                                   Icon(MdiIcons.linkVariantPlus, size: 12, color: JweTheme.textMuted),
                                  const SizedBox(width: 4),
                                  const Text("LINK TO MISSION", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                        if (step.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              step.description,
                              style: const TextStyle(color: JweTheme.textMuted, fontSize: 12),
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
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "$percentage%",
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                       const SizedBox(height: 4),
                       
                       PopupMenuButton<String>(
                         icon: Icon(Icons.more_vert, size: 18, color: JweTheme.textMuted),
                         color: JweTheme.panel,
                         onSelected: (val) {
                           if (val == 'duplicate') {
                             provider.projectActions.duplicateStep(mainTaskId, projectId, step.id);
                           } else if (val == 'delete') {
                             provider.projectActions.deleteStep(mainTaskId, projectId, step.id);
                           }
                         },
                         itemBuilder: (context) => [
                           PopupMenuItem(
                             value: 'duplicate',
                             child: Row(children: [Icon(MdiIcons.contentCopy, size: 16, color: JweTheme.textWhite), const SizedBox(width: 8), const Text("Duplicate", style: TextStyle(color: JweTheme.textWhite))]),
                           ),
                           PopupMenuItem(
                             value: 'delete',
                             child: Row(children: [Icon(MdiIcons.deleteOutline, size: 16, color: JweTheme.accentRed), const SizedBox(width: 8), const Text("Delete", style: TextStyle(color: JweTheme.accentRed))]),
                           ),
                         ],
                       )
                    ],
                  )
                ],
              ),
              
              if (hasSubsteps)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 34),
                  child: JweProgressBar(progress: progress, color: statusColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}