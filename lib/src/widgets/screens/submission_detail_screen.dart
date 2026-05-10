import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/dialogs/subtask_config_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/widgets/dialogs/upgrade_to_project_dialog.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';
import 'package:missions/src/widgets/ui/active_session_timer_display.dart'; 
import 'package:missions/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_resources_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_steps_list.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/screens/submission_sessions_screen.dart';
import 'package:missions/src/widgets/charts/subtask_weekly_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
        isActive: liveSubTask.isActive,
      ),
    );
    if (result != null) {
      provider.taskActions.updateSubtask(
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
      
      final success = provider.taskActions.addSessionToSubtask(
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
           provider.taskActions.deleteSessionFromSubtask(
            widget.parentTask.id, widget.subTask.id, session.id);
        }
      } else if (result['action'] == 'save') {
        if (session.id.startsWith('temp')) {
           provider.taskActions.addSessionToSubtask(
            widget.parentTask.id, widget.subTask.id, result['start'], result['end']);
        } else {
           provider.taskActions.updateSessionInSubtask(widget.parentTask.id, widget.subTask.id,
            session.id, result['start'], result['end']);
        }
      }
    }
  }

  List<TimelineEntry> _buildTimelineEntries(
      AppProvider provider, String currentSubTaskId) {
    final List<TimelineEntry> entries =[];
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

    final bool isRunning = timerState?.isRunning ?? false;
    final timelineEntries = _buildTimelineEntries(provider, liveSubTask.id);

    final Color activeAccent = widget.parentTask.taskColor;

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children:[
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
                color: AppTheme.fhBgDark,
              ),
              child: Row(
                children:[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: AppTheme.fhTextSecondary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(
                          widget.parentTask.name.toUpperCase(),
                          style: TextStyle(
                            color: activeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          liveSubTask.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontSize: 24,
                            fontFamily: AppTheme.fontDisplay,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _handleEditSubtask(context, provider, liveSubTask),
                    child:  Icon(MdiIcons.pencilOutline, color: AppTheme.fhTextSecondary, size: 20),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:[
                    // --- TIMER AREA ---
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:[activeAccent.withOpacity(0.15), Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:[
                                  const Text("TIME LOGGED TODAY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  ActiveSessionTimerDisplay(
                                    isRunning: isRunning,
                                    startTime: timerState?.startTime,
                                    totalTodaySeconds: todaySeconds,
                                  ),
                                ],
                              ),
                              FloatingActionButton(
                                backgroundColor: isRunning ? AppTheme.fhAccentRed : activeAccent,
                                foregroundColor: Colors.black,
                                onPressed: () {
                                  if (isRunning) {
                                    provider.timerActions.pauseTimer(liveSubTask!.id); 
                                    provider.timerActions.logTimerAndReset(liveSubTask.id); 
                                  } else {
                                    provider.timerActions.startTimer(liveSubTask!.id, 'subtask', widget.parentTask.id);
                                  }
                                },
                                child: Icon(isRunning ? MdiIcons.pause : MdiIcons.play, size: 32),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- ACTION PLAN ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          ActionPlanStepsList(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            steps: liveSubTask.subSubTasks,
                            accentColor: activeAccent,
                            onGenerate: (prompt) => provider.aiGenerationActions.generateActionPlanSteps(widget.parentTask.id, liveSubTask!.id, liveSubTask.why, prompt),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          ActionPlanWhyCard(
                            initialWhy: liveSubTask.why,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(widget.parentTask.id, liveSubTask!.id, {'why': val}),
                          ),
                          const SizedBox(height: 16),
                          ActionPlanOutcomeCard(
                            initialWhat: liveSubTask.what,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(widget.parentTask.id, liveSubTask!.id, {'what': val}),
                          ),
                          const SizedBox(height: 16),
                          ActionPlanResourcesCard(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            initialResources: liveSubTask.resources,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(widget.parentTask.id, liveSubTask!.id, {'resources': val}),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: SubtaskWeeklyChart(subTask: liveSubTask, accentColor: activeAccent),
                    ),

                    const SizedBox(height: 32),
                    
                    // --- TIMELINE ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("SESSION TIMELINE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                                InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionSessionsScreen(parentTask: widget.parentTask, subTask: liveSubTask!))),
                                  child: Text("VIEW ALL", style: TextStyle(color: activeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                )
                              ],
                            ),
                          ),
                          Container(
                            height: 200, 
                            decoration: BoxDecoration(
                              color: AppTheme.fhBgDark.withOpacity(0.5),
                              border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5))
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children:[
                              Expanded(
                                child: ValorantButton(
                                  label: "FINISH",
                                  icon: MdiIcons.contentSave,
                                  color: AppTheme.fhAccentGreen,
                                  onPressed: () {
                                    provider.taskActions.completeSubtask(widget.parentTask.id, liveSubTask!.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ValorantButton(
                                  label: "DELETE",
                                  icon: MdiIcons.deleteOutline,
                                  color: AppTheme.fhAccentRed,
                                  isPrimary: false,
                                  onPressed: () {
                                    provider.taskActions.deleteSubtask(widget.parentTask.id, liveSubTask!.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: Icon(MdiIcons.rocketLaunchOutline, size: 18),
                            label: Text("UPGRADE TO PROJECT", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.fhAccentPurple,
                              side: const BorderSide(color: AppTheme.fhAccentPurple, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const BeveledRectangleBorder()
                            ),
                            onPressed: () async {
                               final confirm = await showDialog<bool>(
                                 context: context,
                                 builder: (ctx) => UpgradeToProjectDialog(missionName: liveSubTask.name),
                               );
                               if (confirm == true) {
                                 provider.projectActions.upgradeSubtaskToProject(widget.parentTask.id, liveSubTask);
                                 if (mounted) Navigator.pop(context);
                               }
                            },
                          )
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