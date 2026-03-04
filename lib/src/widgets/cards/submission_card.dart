import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/task_calculations.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';
import 'package:arcane/src/widgets/atoms/valorant_timer_text.dart';
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

    // Safe retrieval logic
    SubTask currentSubTask = subTask;
    try {
      final liveParent = provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      currentSubTask = liveParent.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (_) {}

    final linkedInfo = provider.findLinkedProjectStepInfo(currentSubTask.id);
    final isRunning = timerState?.isRunning ?? false;
    final bool isCompleted = currentSubTask.completed;

    // Calculate time for display
    // If running, we pass only historical time to ValorantTimerText so it can add the live ticker itself
    // If not running, we pass total calculated time
    final double displayBaseTime = isRunning 
        ? TaskCalculations.getHistoricalTodaySeconds(currentSubTask)
        : TaskCalculations.getTodaySeconds(currentSubTask, timerState);

    // --- Progress Calculation ---
    double progressValue = 0.0;
    if (currentSubTask.subSubTasks.isNotEmpty) {
      final int completed = currentSubTask.subSubTasks.where((s) => s.completed).length;
      progressValue = completed / currentSubTask.subSubTasks.length;
    } else if (currentSubTask.isCountable && currentSubTask.targetCount > 0) {
      progressValue = currentSubTask.currentCount / currentSubTask.targetCount;
    } else {
      final yesterdayTime = provider.getYesterdaysTimeForTask(parentTask.id);
      final double maxTime = yesterdayTime > 0 ? yesterdayTime.toDouble() : 3600.0;
      // Use full total for progress bar calculation even if running
      final fullTotal = TaskCalculations.getTodaySeconds(currentSubTask, timerState);
      progressValue = (fullTotal / maxTime).clamp(0.0, 1.0);
    }

    Color borderColor = AppTheme.fhBorderColor.withValues(alpha: 0.3);
    Color backgroundColor = AppTheme.fhBgDark.withValues(alpha: 0.6);
    if (isRunning) {
      borderColor = parentTask.taskColor;
      backgroundColor = parentTask.taskColor.withValues(alpha: 0.1);
    }
    if (isCompleted) {
      borderColor = parentTask.taskColor.withValues(alpha: 0.5);
      backgroundColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Dismissible(
        key: ValueKey("subtask_${currentSubTask.id}"),
        background: _buildSwipeAction(
          alignment: Alignment.centerLeft,
          color: isCompleted ? AppTheme.fhAccentTeal : AppTheme.fhAccentGreen,
          icon: isCompleted ? MdiIcons.restore : MdiIcons.archiveArrowDownOutline,
          label: isCompleted ? "RESTORE" : "COMPLETE",
        ),
        secondaryBackground: _buildSwipeAction(
          alignment: Alignment.centerRight,
          color: AppTheme.fhAccentRed,
          icon: Icons.delete_forever,
          label: "DELETE",
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            return await _showDeleteConfirm(context);
          } else {
            if (isCompleted) {
              provider.taskActions.uncompleteSubtask(parentTask.id, currentSubTask.id);
              return false; 
            } else {
              provider.completeSubtask(parentTask.id, currentSubTask.id);
              return false; 
            }
          }
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            provider.deleteSubtask(parentTask.id, currentSubTask.id);
          }
        },
        child: ValorantCard(
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          isSelected: isRunning,
          onTap: () => _openDetailScreen(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Status
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: isCompleted
                    ? Icon(MdiIcons.checkboxMarkedCircle, size: 24, color: parentTask.taskColor.withValues(alpha: 0.5))
                    : Icon(MdiIcons.checkboxBlankCircleOutline, size: 24, color: isRunning ? parentTask.taskColor : AppTheme.fhTextSecondary),
              ),

              // Title Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currentSubTask.name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: 0.5,
                              height: 1.1,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (currentSubTask.isRecurring)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(MdiIcons.syncIcon, size: 14, color: AppTheme.fhAccentTeal),
                          ),
                      ],
                    ),
                    if (linkedInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: LinkedTaskIndicator(
                          label: "${linkedInfo['projectTitle']} - ${linkedInfo['stepTitle']}",
                          onUnlink: () => provider.projectActions.unlinkStep(
                              linkedInfo['mainTaskId'], linkedInfo['projectId'], linkedInfo['stepId']
                            ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Right Side: Timer & Action
              if (!isCompleted) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValorantTimerText(
                      isRunning: isRunning,
                      startTime: timerState?.startTime,
                      accumulatedTime: displayBaseTime,
                      style: TextStyle(
                          fontFamily: "RobotoMono",
                          color: isRunning ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isRunning ? AppTheme.fhAccentTeal.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(color: isRunning ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          isRunning ? MdiIcons.pause : MdiIcons.play,
                          size: 14,
                          color: isRunning ? AppTheme.fhAccentTeal : AppTheme.fhTextPrimary,
                        ),
                      ),
                    ),
                  ],
                )
              ] else ...[
                Icon(MdiIcons.chevronRight, size: 16, color: AppTheme.fhTextDisabled.withValues(alpha: 0.3))
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeAction({required Alignment alignment, required Color color, required IconData icon, required String label}) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft 
          ? [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]
          : [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Icon(icon, color: Colors.white)],
      ),
    );
  }

  Future<bool> _showDeleteConfirm(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        title: const Text("DELETE MISSION?", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: AppTheme.fhTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE")
          ),
        ],
      )
    ) ?? false;
  }
}