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

    // Calculate 7-Day Average to feed progress bar
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    double total7Days = 0;

    for (var session in currentSubTask.sessions) {
      if (session.startTime.isAfter(sevenDaysAgo)) {
        total7Days += session.durationSeconds;
      }
    }
    
    double avgSeconds = total7Days / 7.0;
    if (avgSeconds < 60) avgSeconds = 60; // minimum 1 minute average for scaling visual
    
    final fullTotalToday = TaskCalculations.getTodaySeconds(currentSubTask, timerState);
    double usageProgress = isCompleted ? 1.0 : (fullTotalToday / avgSeconds).clamp(0.0, 1.0);

    // Style Constants mapped to AppTheme
    final Color activeAccent = parentTask.taskColor;
    final bool isActive = isRunning; 
    
    // Background Gradients
    final Gradient bgGradient = isActive 
      ? LinearGradient(colors:[activeAccent.withOpacity(0.15), AppTheme.fhBgDark.withOpacity(0.9)])
      : LinearGradient(colors:[AppTheme.fhBgDark.withOpacity(0.8), AppTheme.fhBgDeepDark.withOpacity(0.9)]);

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
          child: Stack(
            children:[
              // Main Card Shape
              ClipPath(
                clipper: HexCardClipper(),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: bgGradient,
                  ),
                  child: Stack(
                    children:[
                      // Simulated Border via inner shadow if active
                      if (isActive)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: activeAccent, width: 2),
                            boxShadow:[
                              BoxShadow(color: activeAccent.withOpacity(0.1), blurRadius: 20)
                            ]
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.fhBorderColor, width: 1),
                          ),
                        ),
                      
                      // Mist Effect if active
                      if (isActive)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors:[activeAccent.withOpacity(0.1), Colors.transparent],
                                radius: 0.7
                              )
                            ),
                          ),
                        ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children:[
                            // Icon / Ring Area
                            SizedBox(
                              width: 60, height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children:[
                                  HexProgressRing(
                                    progress: usageProgress, 
                                    color: activeAccent
                                  ),
                                  Icon(
                                    isCompleted ? MdiIcons.checkAll : (isActive ? MdiIcons.fire : MdiIcons.swordCross), 
                                    color: isCompleted ? AppTheme.fhTextDisabled : (isActive ? Colors.white : AppTheme.fhTextSecondary),
                                    size: 24,
                                    shadows: isActive ? [Shadow(color: activeAccent, blurRadius: 10)] : null,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),

                            // Text Content
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:[
                                  Text(
                                    currentSubTask.name.toUpperCase(),
                                    style: GoogleFonts.cinzel(
                                      color: titleColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children:[
                                      Text(
                                        isCompleted ? "ARCHIVED" : (isActive ? "IN PROGRESS" : "PENDING"),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      if (currentSubTask.isRecurring)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4.0),
                                          child: Icon(MdiIcons.syncIcon, size: 12, color: statusColor),
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

                            // Actions
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children:[
                                ValorantTimerText(
                                  isRunning: isRunning,
                                  startTime: timerState?.startTime,
                                  accumulatedTime: displayBaseTime,
                                  style: TextStyle(
                                    fontFamily: "RobotoMono",
                                    color: isActive ? activeAccent : AppTheme.fhTextSecondary,
                                    fontSize: 12,
                                    shadows: isActive ?[Shadow(color: activeAccent, blurRadius: 5)] : null
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
                                    child: ClipPath(
                                      clipper: HexButtonClipper(),
                                      child: Container(
                                        width: 80, height: 30,
                                        decoration: BoxDecoration(
                                          gradient: isActive 
                                            ? LinearGradient(colors:[activeAccent.withOpacity(0.2), activeAccent.withOpacity(0.1)])
                                            : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors:[AppTheme.fhBgMedium, AppTheme.fhBgDark]),
                                          border: Border.all(color: isActive ? activeAccent : AppTheme.fhBorderColor, width: 1),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          isActive ? "PAUSE" : "START",
                                          style: TextStyle(
                                            color: isActive ? activeAccent : AppTheme.fhTextSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              
              // Corner Accents if active
              if (isActive) ...[
                Positioned(top: 0, left: 15, child: _buildCornerAccent(activeAccent)),
                Positioned(bottom: 0, right: 15, child: _buildCornerAccent(activeAccent)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerAccent(Color color) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: color,
        boxShadow:[BoxShadow(color: color, blurRadius: 10)]
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
          ?[Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]
          :[Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Icon(icon, color: Colors.white)],
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
        actions:[
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