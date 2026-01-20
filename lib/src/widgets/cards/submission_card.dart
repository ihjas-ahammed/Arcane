import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/utils/task_calculations.dart'; // Import calculations
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart'; // Import indicator
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class SubmissionCard extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionCard({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  void _openDetailScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubmissionDetailScreen(
          parentTask: parentTask,
          subTask: subTask,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[subTask.id];

    // FIX: Retrieve the live subtask from the provider to ensure we have the latest state (e.g. isCompleted)
    SubTask currentSubTask = subTask;
    try {
      final liveParent =
          provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      currentSubTask =
          liveParent.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (_) {
      // Fallback if not found (e.g. deleted/filtered out momentarily)
    }

    // Check for linked project step info
    final linkedInfo = provider.findLinkedProjectStepInfo(currentSubTask.id);

    // Calculate time spent TODAY instead of total
    final double displayTimeSeconds = TaskCalculations.getTodaySeconds(currentSubTask, timerState);

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    Color borderColor = AppTheme.fhBorderColor.withValues(alpha: 0.3);
    if (isRunning) borderColor = parentTask.taskColor;
    if (currentSubTask.completed) borderColor = parentTask.taskColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ValorantCard(
        borderColor: borderColor,
        isSelected: isRunning,
        onTap: () => _openDetailScreen(context),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: RhombusCheckbox(
                checked: currentSubTask.completed,
                onChanged: (val) {
                  if (val == true) {
                    provider.completeSubtask(parentTask.id, currentSubTask.id);
                  } else {
                    provider.taskActions.uncompleteSubtask(parentTask.id, currentSubTask.id);
                  }
                },
                size: CheckboxSize.small,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSubTask.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      height: 1.1,
                      decoration: currentSubTask.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: currentSubTask.completed
                          ? AppTheme.fhTextDisabled
                          : AppTheme.fhTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (linkedInfo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: LinkedTaskIndicator(
                        label: "${linkedInfo['projectTitle']} - ${linkedInfo['stepTitle']}",
                        onUnlink: () {
                          // Unlink action
                          provider.projectActions.unlinkStep(
                            linkedInfo['mainTaskId'], 
                            linkedInfo['projectId'], 
                            linkedInfo['stepId']
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!currentSubTask.completed) ...[
              Text(
                formattedTime, // Shows Today's Time
                style: TextStyle(
                    fontFamily: "RobotoMono",
                    color: isRunning
                        ? AppTheme.fhAccentTeal
                        : AppTheme.fhTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  if (isRunning) {
                    provider.pauseTimer(subTask.id);
                    provider.logTimerAndReset(subTask.id);
                  } else {
                    provider.startTimer(subTask.id, 'subtask', parentTask.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? AppTheme.fhAccentTeal.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                        color: isRunning
                            ? AppTheme.fhAccentTeal
                            : AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    isRunning ? MdiIcons.pause : MdiIcons.play,
                    size: 16,
                    color: isRunning
                        ? AppTheme.fhAccentTeal
                        : AppTheme.fhTextPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(MdiIcons.dotsVertical,
                  color: AppTheme.fhTextSecondary, size: 18),
              color: AppTheme.fhBgDark,
              onSelected: (value) {
                if (value == 'delete') {
                  provider.deleteSubtask(parentTask.id, currentSubTask.id);
                } else if (value == 'duplicate') {
                  provider.duplicateCompletedSubtask(
                      parentTask.id, currentSubTask.id);
                } else if (value == 'uncomplete') {
                  provider.taskActions.uncompleteSubtask(parentTask.id, currentSubTask.id);
                }
              },
              itemBuilder: (context) => [
                if (currentSubTask.completed) ...[
                  const PopupMenuItem(
                      value: 'uncomplete',
                      child: Text("Uncomplete",
                          style: TextStyle(color: AppTheme.fhTextPrimary))),
                  const PopupMenuItem(
                      value: 'duplicate',
                      child: Text("Duplicate",
                          style: TextStyle(color: AppTheme.fhTextPrimary))),
                ],
                const PopupMenuItem(
                    value: 'delete',
                    child: Text("Delete",
                        style: TextStyle(color: AppTheme.fhAccentRed))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}