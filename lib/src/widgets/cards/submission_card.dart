import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/task_calculations.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';
import 'package:arcane/src/widgets/ui/hextech_components.dart';
import 'package:arcane/src/widgets/atoms/valorant_timer_text.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

    SubTask currentSubTask = subTask;
    try {
      final liveParent = provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      currentSubTask = liveParent.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (_) {}

    final linkedInfo = provider.findLinkedProjectStepInfo(currentSubTask.id);
    final isRunning = timerState?.isRunning ?? false;
    final bool isCompleted = currentSubTask.completed;

    final double displayBaseTime = isRunning 
        ? TaskCalculations.getHistoricalTodaySeconds(currentSubTask)
        : TaskCalculations.getTodaySeconds(currentSubTask, timerState);

    // Calculate 7-Day Average Total Time for THIS Submission
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    double total7Days = 0;

    // Filter sessions belonging to this specific subtask in the last 7 days
    for (var session in currentSubTask.sessions) {
      if (session.startTime.isAfter(sevenDaysAgo)) {
        total7Days += session.durationSeconds;
      }
    }
    
    // Average calculation (prevent div by zero)
    double avgSeconds = total7Days / 7.0;
    // Minimum 5 minutes baseline to show progress visual if avg is too low
    if (avgSeconds < 300) avgSeconds = 300; 
    
    // Calculate current total time spent today
    final fullTotalToday = TaskCalculations.getTodaySeconds(currentSubTask, timerState);
    
    // Progress relative to 7-day average
    double usageProgress = isCompleted ? 1.0 : (fullTotalToday / avgSeconds).clamp(0.0, 1.0);

    // Style Constants
    final Color activeAccent = parentTask.taskColor;
    final bool isActive = isRunning; 
    
    // Text Colors
    final Color titleColor = isCompleted ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary;
    final Color statusColor = isCompleted ? AppTheme.fhTextDisabled : (isActive ? activeAccent : AppTheme.fhTextSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
        child: GestureDetector(
          onTap: () => _openDetailScreen(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 100,
            decoration: BoxDecoration(
              // Gradient changes based on state
              gradient: LinearGradient(
                colors: isActive 
                  ? [activeAccent.withOpacity(0.2), AppTheme.fhBgDark.withOpacity(0.95)]
                  : [AppTheme.fhBgDark.withOpacity(0.9), AppTheme.fhBgDeepDark.withOpacity(0.95)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(
                color: isActive ? activeAccent : AppTheme.fhBorderColor.withOpacity(0.3),
                width: isActive ? 1.5 : 1
              ),
              // Beveled corners like Valorant cards
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomRight: Radius.circular(16)
              ),
              boxShadow: isActive ? [BoxShadow(color: activeAccent.withOpacity(0.15), blurRadius: 12)] : null,
            ),
            child: Stack(
              children: [
                // Progress Bar Background Fill (Horizontal from left)
                if (isActive || usageProgress > 0)
                  FractionallySizedBox(
                    widthFactor: usageProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [activeAccent.withOpacity(0.1), Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight
                        )
                      ),
                    ),
                  ).animate().fadeIn(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Leading Visual (Hexagon or Icon)
                      SizedBox(
                        width: 50, height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!isCompleted)
                              HexProgressRing(
                                progress: usageProgress, 
                                color: activeAccent,
                                size: 48,
                              ).animate().fade(duration: 500.ms),
                            Icon(
                              isCompleted ? MdiIcons.checkAll : (isActive ? MdiIcons.fire : MdiIcons.swordCross), 
                              color: isCompleted ? AppTheme.fhTextDisabled : (isActive ? Colors.white : AppTheme.fhTextSecondary),
                              size: 22,
                              shadows: isActive ? [Shadow(color: activeAccent, blurRadius: 10)] : null,
                            ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.1,1.1), duration: 1.seconds, curve: Curves.easeInOut).then().scale(begin: const Offset(1.1,1.1), end: const Offset(1,1)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),

                      // Text Content
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Flexible text to show full name
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currentSubTask.name.toUpperCase(),
                                style: GoogleFonts.chakraPetch(
                                  color: titleColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  color: statusColor.withOpacity(0.1),
                                  child: Text(
                                    isCompleted ? "ARCHIVED" : (isActive ? "ENGAGED" : "PENDING"),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                if (currentSubTask.isRecurring)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6.0),
                                    child: Icon(MdiIcons.syncIcon, size: 12, color: statusColor),
                                  ),
                              ],
                            ),
                            if (linkedInfo != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
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

                      // Right Action / Timer
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ValorantTimerText(
                            isRunning: isRunning,
                            startTime: timerState?.startTime,
                            accumulatedTime: displayBaseTime,
                            style: TextStyle(
                              fontFamily: "RobotoMono",
                              color: isActive ? activeAccent : AppTheme.fhTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              shadows: isActive ? [Shadow(color: activeAccent, blurRadius: 8)] : null
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!isCompleted)
                            GestureDetector(
                              onTap: () {
                                if (isRunning) {
                                  provider.pauseTimer(subTask.id); 
                                  provider.logTimerAndReset(subTask.id); 
                                } else {
                                  provider.startTimer(subTask.id, 'subtask', parentTask.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isActive ? activeAccent : AppTheme.fhBorderColor),
                                  color: isActive ? activeAccent.withOpacity(0.1) : Colors.transparent,
                                ),
                                child: Text(
                                  isActive ? "HALT" : "EXECUTE",
                                  style: TextStyle(
                                    color: isActive ? activeAccent : AppTheme.fhTextSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            )
                        ],
                      )
                    ],
                  ),
                ),
                
                // Bottom decorative line showing 7-day average relation
                if (!isCompleted)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutExpo,
                        height: 2,
                        width: MediaQuery.of(context).size.width * 0.9 * usageProgress, // Approximate width relative to card
                        decoration: BoxDecoration(
                          color: activeAccent,
                          boxShadow: [BoxShadow(color: activeAccent, blurRadius: 6)]
                        ),
                      ),
                    ),
                  )
              ],
            ),
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