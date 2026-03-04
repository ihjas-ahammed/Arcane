import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/utils/task_calculations.dart';
import 'package:arcane/src/widgets/dialogs/subtask_config_dialog.dart';
import 'package:arcane/src/widgets/dialogs/add_session_dialog.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/widgets/schedule/schedule_timeline.dart';
import 'package:arcane/src/widgets/ui/active_session_timer_display.dart'; 
import 'package:arcane/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_steps_list.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionDetailScreen({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  DateTime _selectedDate = DateTime.now();

  SubTask? _getLiveSubTask(AppProvider provider) {
    try {
      final parent =
          provider.mainTasks.firstWhere((t) => t.id == widget.parentTask.id);
      return parent.subTasks.firstWhere((s) => s.id == widget.subTask.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleEditSubtask(
      BuildContext context, AppProvider provider, SubTask liveSubTask) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SubtaskConfigDialog(
        initialName: liveSubTask.name,
        initialDescription: liveSubTask.description,
        isRecurring: liveSubTask.isRecurring,
      ),
    );
    if (result != null) {
      provider.updateSubtask(
          widget.parentTask.id, widget.subTask.id, result);
    }
  }

  void _showAddSessionDialog(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => AddSessionDialog(initialDate: _selectedDate),
    );
    
    if (result != null) {
      final start = result['start']!;
      final end = result['end']!;
      
      final success = provider.addSessionToSubtask(
          widget.parentTask.id, widget.subTask.id, start, end);
          
      if (!success && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: const Text("Overlap detected! Adjust time."),
             backgroundColor: AppTheme.fhAccentRed,
             action: SnackBarAction(
               label: "EDIT",
               textColor: Colors.white,
               onPressed: () {
                 _handleSessionEdit(context, provider, TaskSession(id: 'temp', startTime: start, endTime: end));
               },
             ),
           )
         );
      }
    }
  }

  void _handleSessionEdit(
      BuildContext context, AppProvider provider, TaskSession session) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(
          initialStart: session.startTime, initialEnd: session.endTime),
    );
    if (result != null) {
      if (result['action'] == 'delete') {
        if (!session.id.startsWith('temp')) {
           provider.deleteSessionFromSubtask(
            widget.parentTask.id, widget.subTask.id, session.id);
        }
      } else if (result['action'] == 'save') {
        if (session.id.startsWith('temp')) {
           provider.addSessionToSubtask(
            widget.parentTask.id, widget.subTask.id, result['start'], result['end']);
        } else {
           provider.updateSessionInSubtask(widget.parentTask.id, widget.subTask.id,
            session.id, result['start'], result['end']);
        }
      }
    }
  }

  List<TimelineEntry> _buildTimelineEntries(
      AppProvider provider, String currentSubTaskId) {
    final List<TimelineEntry> entries = [];
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (var task in provider.mainTasks) {
      if (task.id != widget.parentTask.id) continue;
      
      for (var sub in task.subTasks) {
        if (sub.id != currentSubTaskId) continue;

        for (var session in sub.sessions) {
          if (session.startTime.isBefore(dayEnd) && session.endTime.isAfter(dayStart)) {
            DateTime displayStart = session.startTime.isBefore(dayStart) ? dayStart : session.startTime;
            DateTime displayEnd = session.endTime.isAfter(dayEnd) ? dayEnd : session.endTime;

            entries.add(TimelineEntry(
              id: session.id,
              startTime: displayStart,
              endTime: displayEnd,
              title: sub.name,
              subtitle: task.name,
              color: task.taskColor,
              isEditable: true,
              originalObject: session,
            ));
          }
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final liveSubTask = _getLiveSubTask(provider);

    if (liveSubTask == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final timerState = provider.activeTimers[liveSubTask.id];
    final double todaySeconds =
        TaskCalculations.getTodaySeconds(liveSubTask, timerState);
    final String formattedTotalToday = helper.formatTime(todaySeconds);

    final bool isRunning = timerState?.isRunning ?? false;
    final timelineEntries = _buildTimelineEntries(provider, liveSubTask.id);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
                color: AppTheme.fhBgDark,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parentTask.name.toUpperCase(),
                          style: TextStyle(
                            color: widget.parentTask.taskColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5
                          ),
                        ),
                        Text(
                          liveSubTask.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontSize: 20,
                            fontFamily: AppTheme.fontDisplay,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.pencilOutline, color: AppTheme.fhTextSecondary),
                    onPressed: () => _handleEditSubtask(context, provider, liveSubTask),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- BANNER / STATS ---
                    Container(
                      height: 120,
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.parentTask.taskColor.withOpacity(0.2), 
                            Colors.transparent
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("TIME LOGGED TODAY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ActiveSessionTimerDisplay(
                                  isRunning: isRunning,
                                  startTime: timerState?.startTime,
                                  totalTodaySeconds: todaySeconds,
                                ),
                              ],
                            ),
                          ),
                          FloatingActionButton(
                            backgroundColor: isRunning ? AppTheme.fhAccentRed : AppTheme.fhAccentTeal,
                            foregroundColor: Colors.black,
                            onPressed: () {
                              if (isRunning) {
                                provider.pauseTimer(liveSubTask.id); 
                                provider.logTimerAndReset(liveSubTask.id); 
                              } else {
                                provider.startTimer(liveSubTask.id, 'subtask', widget.parentTask.id);
                              }
                            },
                            child: Icon(isRunning ? MdiIcons.pause : MdiIcons.play),
                          )
                        ],
                      ),
                    ),

                    // --- BRIEFING ---
                    if (liveSubTask.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          liveSubTask.description,
                          style: const TextStyle(color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
                        ),
                      ),

                    // --- ACTION PLAN ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. OBJECTIVES (Checkpoints)
                          ActionPlanStepsList(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            steps: liveSubTask.subSubTasks,
                            onGenerate: () => provider.aiGenerationActions.generateActionPlanSteps(widget.parentTask.id, liveSubTask.id, liveSubTask.why),
                          ),
                          
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 24),

                          // 2. STRATEGIC INTENT
                          ActionPlanWhyCard(
                            initialWhy: liveSubTask.why,
                            onChanged: (val) => provider.updateSubtask(widget.parentTask.id, liveSubTask.id, {'why': val}),
                          ),

                          const SizedBox(height: 16),

                          // 3. EXPECTED OUTCOME
                          ActionPlanOutcomeCard(
                            initialWhat: liveSubTask.what,
                            onChanged: (val) => provider.updateSubtask(widget.parentTask.id, liveSubTask.id, {'what': val}),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    // --- TIMELINE ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("SESSION TIMELINE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Container(
                            height: 200, 
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              border: Border.all(color: Colors.white10)
                            ),
                            child: ScheduleTimeline(
                              entries: timelineEntries,
                              onAddSession: () => _showAddSessionDialog(context, provider),
                              onEditEntry: (entry) {
                                if (entry.originalObject is TaskSession) {
                                  _handleSessionEdit(context, provider, entry.originalObject as TaskSession);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- FOOTER ACTIONS ---
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(MdiIcons.archiveArrowDownOutline),
                              label: const Text("COMPLETE"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.fhAccentGreen,
                                foregroundColor: Colors.black,
                                shape: const BeveledRectangleBorder(),
                              ),
                              onPressed: () {
                                provider.completeSubtask(widget.parentTask.id, liveSubTask.id);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(MdiIcons.delete),
                              label: const Text("TERMINATE"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.fhAccentRed,
                                side: BorderSide(color: AppTheme.fhAccentRed.withOpacity(0.5)),
                                shape: const BeveledRectangleBorder(),
                              ),
                              onPressed: () {
                                provider.deleteSubtask(widget.parentTask.id, liveSubTask.id);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}