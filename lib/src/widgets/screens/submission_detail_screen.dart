import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/utils/task_calculations.dart';
import 'package:arcane/src/widgets/dialogs/subtask_config_dialog.dart';
import 'package:arcane/src/widgets/cards/task_info_card.dart';
import 'package:arcane/src/widgets/dialogs/add_session_dialog.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/widgets/schedule/schedule_timeline.dart';
import 'package:arcane/src/widgets/ui/valorant_ability_slot.dart';
import 'package:arcane/src/widgets/ui/active_session_timer_display.dart'; 
import 'package:arcane/src/widgets/charts/subtask_weekly_chart.dart'; 
import 'package:arcane/src/widgets/drawers/session_log_drawer.dart';
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

  Future<void> _pickDateFiltered(BuildContext context, SubTask subTask) async {
    final Set<String> validDates = {};
    for (var s in subTask.sessions) {
      validDates.add(DateFormat('yyyy-MM-dd').format(s.startTime));
      validDates.add(DateFormat('yyyy-MM-dd').format(s.endTime));
    }
    final today = DateTime.now();
    validDates.add(DateFormat('yyyy-MM-dd').format(today));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        return validDates.contains(DateFormat('yyyy-MM-dd').format(day));
      },
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTealFixed,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDark,
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppTheme.fhBgDark),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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
    
    final int completedSteps =
        liveSubTask.subSubTasks.where((s) => s.completed).length;
    final int totalSteps = liveSubTask.subSubTasks.length;
    final timelineEntries = _buildTimelineEntries(provider, liveSubTask.id);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      endDrawer:
          SessionLogDrawer(parentTask: widget.parentTask, subTask: liveSubTask),
      body: Stack(
        children: [
          Positioned(
            right: -50,
            top: 50,
            child: Opacity(
              opacity: 0.05,
              child:
                  Icon(MdiIcons.targetVariant, size: 400, color: Colors.white),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(MdiIcons.history, color: Colors.white70),
                            tooltip: "Session History",
                            onPressed: () =>
                                Scaffold.of(context).openEndDrawer(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(MdiIcons.pencilOutline,
                              color: Colors.white70),
                          tooltip: "Configure Task",
                          onPressed: () => _handleEditSubtask(
                              context, provider, liveSubTask),
                        ),
                      ],
                    ),
                  ),

                  // Header Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parentTask.name.toUpperCase(),
                          style: TextStyle(
                            color: widget.parentTask.taskColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 12,
                            fontFamily: AppTheme.fontDisplay,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          liveSubTask.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            height: 1.0,
                            fontFamily: AppTheme.fontDisplay,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Ability Slot Stats
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ValorantAbilitySlot(
                          hotkey: "Q",
                          label: "TODAY",
                          value: formattedTotalToday,
                          icon: MdiIcons.clockFast,
                          isActive: isRunning,
                        ),
                        const SizedBox(width: 16),
                        ValorantAbilitySlot(
                          hotkey: "E",
                          label: "STEPS",
                          value: "$completedSteps/$totalSteps",
                          icon: MdiIcons.formatListChecks,
                          isActive: completedSteps > 0 &&
                              completedSteps == totalSteps,
                        ),
                        const SizedBox(width: 16),
                        ValorantAbilitySlot(
                          hotkey: "C",
                          label: "LOGS",
                          value: "${liveSubTask.sessions.length}",
                          icon: MdiIcons.history,
                        ),
                        const SizedBox(width: 16),
                        ValorantAbilitySlot(
                          hotkey: "X",
                          label: "STATUS",
                          value: liveSubTask.completed ? "DONE" : "ACTIVE",
                          icon: liveSubTask.completed
                              ? MdiIcons.checkAll
                              : MdiIcons.target,
                          isActive: liveSubTask.completed,
                          onTap: () {
                            if (liveSubTask.completed) {
                              provider.taskActions.uncompleteSubtask(
                                  widget.parentTask.id, liveSubTask.id);
                            } else {
                              provider.completeSubtask(
                                  widget.parentTask.id, liveSubTask.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Info Card (Recurring / Metadata)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: TaskInfoCard(
                      description: liveSubTask.description,
                      isRecurring: liveSubTask.isRecurring,
                      createdAt: liveSubTask.createdAt,
                      updatedAt: liveSubTask.updatedAt,
                    ),
                  ),

                  // --- ACTION PLAN SECTION START ---
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text("ACTION PLAN", style: TextStyle(color: AppTheme.fhAccentPurple, letterSpacing: 2.0, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 16),

                  // 1. WHY (Strategic Intent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ActionPlanWhyCard(
                      initialWhy: liveSubTask.why,
                      onChanged: (val) => provider.updateSubtask(widget.parentTask.id, liveSubTask.id, {'why': val}),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. HOW (Tactical Execution / Steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ActionPlanStepsList(
                      mainTaskId: widget.parentTask.id,
                      subTaskId: liveSubTask.id,
                      steps: liveSubTask.subSubTasks,
                      onGenerate: () => provider.aiGenerationActions.generateActionPlanSteps(widget.parentTask.id, liveSubTask.id, liveSubTask.why),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. WHAT (Outcome)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ActionPlanOutcomeCard(
                      initialWhat: liveSubTask.what,
                      onChanged: (val) => provider.updateSubtask(widget.parentTask.id, liveSubTask.id, {'what': val}),
                    ),
                  ),
                  // --- ACTION PLAN SECTION END ---

                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),

                  // Timer Control
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isRunning
                            ? [
                                AppTheme.fhAccentRed.withOpacity(0.2),
                                Colors.transparent
                              ]
                            : [
                                Colors.white.withOpacity(0.05),
                                Colors.transparent
                              ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      border: Border(
                          left: BorderSide(
                              color: isRunning
                                  ? AppTheme.fhAccentRed
                                  : AppTheme.fhTextSecondary,
                              width: 2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ActiveSessionTimerDisplay(
                          isRunning: isRunning,
                          startTime: timerState?.startTime,
                          totalTodaySeconds: todaySeconds,
                        ),
                        FloatingActionButton.small(
                          backgroundColor: isRunning
                              ? AppTheme.fhAccentRed
                              : AppTheme.fhAccentTealFixed,
                          foregroundColor: Colors.black,
                          onPressed: () {
                              if (isRunning) {
                                provider.pauseTimer(liveSubTask.id);
                                provider.logTimerAndReset(liveSubTask.id);
                              } else {
                                provider.startTimer(liveSubTask.id, 'subtask',
                                    widget.parentTask.id);
                              }
                            },
                          child: Icon(isRunning ? MdiIcons.pause : MdiIcons.play),
                        ),
                      ],
                    ),
                  ),

                  // Weekly Chart
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SubtaskWeeklyChart(
                      subTask: liveSubTask,
                      accentColor: widget.parentTask.taskColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Manual Session Logging & Timeline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  _pickDateFiltered(context, liveSubTask),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('MMM dd')
                                        .format(_selectedDate)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: AppTheme.fhAccentTealFixed,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: AppTheme.fontDisplay,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down,
                                      color: AppTheme.fhAccentTealFixed,
                                      size: 16),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add,
                                  size: 20, color: Colors.white54),
                              onPressed: () =>
                                  _showAddSessionDialog(context, provider),
                              tooltip: "Log Manual Session",
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 300, 
                          color: Colors.black.withOpacity(0.2),
                          child: ScheduleTimeline(
                            entries: timelineEntries,
                            onAddSession: () =>
                                _showAddSessionDialog(context, provider),
                            onEditEntry: (entry) {
                              if (entry.originalObject is TaskSession) {
                                _handleSessionEdit(context, provider,
                                    entry.originalObject as TaskSession);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}