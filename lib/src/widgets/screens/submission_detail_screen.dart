import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_resources_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_steps_list.dart';
import 'package:missions/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:missions/src/widgets/charts/subtask_progress_time_chart.dart';
import 'package:missions/src/widgets/charts/subtask_weekly_chart.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/widgets/dialogs/subtask_config_dialog.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';
import 'package:missions/src/widgets/screens/submission/manual_progress_input.dart';
import 'package:missions/src/widgets/screens/submission/section_label.dart';
import 'package:missions/src/widgets/screens/submission/submission_date_navigator.dart';
import 'package:missions/src/widgets/screens/submission/submission_detail_header.dart';
import 'package:missions/src/widgets/screens/submission/submission_footer_actions.dart';
import 'package:missions/src/widgets/screens/submission/submission_paste_dialog.dart';
import 'package:missions/src/widgets/screens/submission/submission_reminders_dialog.dart';
import 'package:missions/src/widgets/screens/submission/submission_timer_card.dart';
import 'package:missions/src/widgets/screens/submission/template_sets_tabs.dart';
import 'package:missions/src/widgets/screens/submission_sessions_screen.dart';
import 'package:provider/provider.dart';

export 'package:missions/src/widgets/screens/submission/date_nav_btn.dart';
export 'package:missions/src/widgets/screens/submission/manual_progress_input.dart';
export 'package:missions/src/widgets/screens/submission/section_label.dart';
export 'package:missions/src/widgets/screens/submission/submission_date_navigator.dart';
export 'package:missions/src/widgets/screens/submission/submission_detail_header.dart';
export 'package:missions/src/widgets/screens/submission/submission_footer_actions.dart';
export 'package:missions/src/widgets/screens/submission/submission_paste_dialog.dart';
export 'package:missions/src/widgets/screens/submission/submission_reminders_dialog.dart';
export 'package:missions/src/widgets/screens/submission/submission_timer_card.dart';
export 'package:missions/src/widgets/screens/submission/template_sets_tabs.dart';

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
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.parentTask.id);
      return parent.subTasks.firstWhere((s) => s.id == widget.subTask.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleEditSubtask(BuildContext context, AppProvider provider, SubTask liveSubTask) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SubtaskConfigDialog(
        initialName: liveSubTask.name,
        initialDescription: liveSubTask.description,
        isRecurring: liveSubTask.isRecurring,
        isActive: liveSubTask.isActive,
        initialProgressMode: liveSubTask.progressMode,
        initialDepth: liveSubTask.depth,
      ),
    );
    if (result != null) {
      provider.taskActions.updateSubtask(widget.parentTask.id, widget.subTask.id, result);
    }
  }

  void _showAddSessionDialog(AppProvider provider) async {
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
            backgroundColor: JweTheme.accentRed,
            action: SnackBarAction(
              label: "EDIT",
              textColor: Colors.white,
              onPressed: () {
                _handleSessionEdit(context, provider,
                    TaskSession(id: 'temp', startTime: start, endTime: end));
              },
            ),
          ),
        );
      }
    }
  }

  void _handleSessionEdit(BuildContext context, AppProvider provider, TaskSession session) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          SessionEditDialog(initialStart: session.startTime, initialEnd: session.endTime),
    );
    if (result != null) {
      if (result['action'] == 'delete') {
        if (!session.id.startsWith('temp')) {
          provider.taskActions
              .deleteSessionFromSubtask(widget.parentTask.id, widget.subTask.id, session.id);
        }
      } else if (result['action'] == 'save') {
        if (session.id.startsWith('temp')) {
          provider.taskActions.addSessionToSubtask(
              widget.parentTask.id, widget.subTask.id, result['start'], result['end']);
        } else {
          provider.taskActions.updateSessionInSubtask(
              widget.parentTask.id, widget.subTask.id, session.id, result['start'], result['end']);
        }
      }
    }
  }

  List<TimelineEntry> _buildTimelineEntries(AppProvider provider, String currentSubTaskId) {
    final List<TimelineEntry> entries = [];
    final dayStart =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (var task in provider.mainTasks) {
      if (task.id != widget.parentTask.id) continue;
      for (var sub in task.subTasks) {
        if (sub.id != currentSubTaskId) continue;
        for (var session in sub.sessions) {
          if (session.startTime.isBefore(dayEnd) && session.endTime.isAfter(dayStart)) {
            final displayStart =
                session.startTime.isBefore(dayStart) ? dayStart : session.startTime;
            final displayEnd =
                session.endTime.isAfter(dayEnd) ? dayEnd : session.endTime;
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
    final double todaySeconds = TaskCalculations.getTodaySeconds(liveSubTask, timerState, provider.mainTasks);
    final bool isRunning = timerState?.isRunning ?? false;
    final timelineEntries = _buildTimelineEntries(provider, liveSubTask.id);
    final Color activeAccent = widget.parentTask.taskColor;

    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final canGoForward = !isToday;

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            SubmissionDetailHeader(
              parentTask: widget.parentTask,
              liveSubTask: liveSubTask,
              isRunning: isRunning,
              activeAccent: activeAccent,
              hasReminder: SubmissionRemindersDialog.hasReminder(provider, liveSubTask),
              onBack: () => Navigator.pop(context),
              onOpenReminders: () => SubmissionRemindersDialog.show(
                context,
                provider,
                widget.parentTask.id,
                liveSubTask,
                () => setState(() {}),
              ),
              onEdit: () => _handleEditSubtask(context, provider, liveSubTask),
              onCopyStructure: () {
                Clipboard.setData(ClipboardData(text: liveSubTask.toCopyStructure()));
                showGlobalToast("Task structure copied to clipboard");
              },
              onPasteStructure: () => SubmissionPasteDialog.handlePaste(
                context,
                provider,
                widget.parentTask.id,
                liveSubTask,
              ),
              onSelectDepth: (depth) {
                provider.taskActions.setSubtaskDepth(
                  widget.parentTask.id,
                  liveSubTask.id,
                  depth,
                );
              },
            ),

            // ── Scrollable body ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Timer card ───────────────────────────────────
                    SubmissionTimerCard(
                      isRunning: isRunning,
                      activeAccent: activeAccent,
                      timerState: timerState,
                      todaySeconds: todaySeconds,
                      onToggleTimer: () {
                        if (isRunning) {
                          provider.timerActions.pauseTimer(liveSubTask.id);
                          provider.timerActions.logTimerAndReset(liveSubTask.id);
                        } else {
                          provider.timerActions.startTimer(
                            liveSubTask.id,
                            'subtask',
                            widget.parentTask.id,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Action plan section ──────────────────────────
                    SectionLabel(
                      label: "ACTION PLAN",
                      accentColor: activeAccent,
                      icon: MdiIcons.formatListChecks,
                      trailing: liveSubTask.progressMode == 'manual'
                          ? ManualProgressInput(
                              mainTaskId: widget.parentTask.id,
                              subTask: liveSubTask,
                              accentColor: activeAccent,
                              provider: provider,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (liveSubTask.isRecurring)
                            TemplateSetsTabs(
                              parentTask: widget.parentTask,
                              subTask: liveSubTask,
                              provider: provider,
                            ),
                          ActionPlanStepsList(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            steps: liveSubTask.subSubTasks,
                            accentColor: activeAccent,
                            onGenerate: (prompt) => provider.aiGenerationActions
                                .generateActionPlanSteps(
                                    widget.parentTask.id, liveSubTask.id, liveSubTask.why, prompt),
                          ),
                          const SizedBox(height: 16),
                          ActionPlanWhyCard(
                            initialWhy: liveSubTask.why,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask.id, {'why': val}),
                          ),
                          const SizedBox(height: 10),
                          ActionPlanOutcomeCard(
                            initialWhat: liveSubTask.what,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask.id, {'what': val}),
                          ),
                          const SizedBox(height: 10),
                          ActionPlanResourcesCard(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            initialResources: liveSubTask.resources,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask.id, {'resources': val}),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Weekly chart section ─────────────────────────
                    SectionLabel(
                      label: "WEEKLY PERFORMANCE",
                      accentColor: JweTheme.accentCyan,
                      icon: MdiIcons.chartBar,
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SubtaskWeeklyChart(subTask: liveSubTask, accentColor: activeAccent),
                    ),

                    const SizedBox(height: 24),

                    // ── Progress · Time chart ────────────────────────
                    SectionLabel(
                      label: "PROGRESS · TIME",
                      accentColor: activeAccent,
                      icon: MdiIcons.chartLine,
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SubtaskProgressTimeChart(
                        dataPoints: liveSubTask.progressDataPoints,
                        accentColor: activeAccent,
                        currentSpentSeconds: liveSubTask.isRecurring
                            ? TaskCalculations.getTodaySeconds(liveSubTask, timerState, provider.mainTasks).toInt()
                            : TaskCalculations.getSubtaskTotalSeconds(liveSubTask, provider.mainTasks) +
                                (isRunning && timerState?.startTime != null
                                    ? DateTime.now().difference(timerState!.startTime).inSeconds
                                    : 0),
                        currentProgress: liveSubTask.calculateProgress(),
                        onAddEntry: (progress, spentSeconds) => provider.saveProgressDataPoint(
                            widget.parentTask.id, liveSubTask.id, progress, spentSeconds),
                        onDeleteEntry: (index) => provider.deleteProgressDataPoint(
                            widget.parentTask.id, liveSubTask.id, index),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Timeline section ─────────────────────────────
                    SectionLabel(
                      label: "SESSION TIMELINE",
                      accentColor: JweTheme.accentAmber,
                      icon: MdiIcons.clock,
                      trailing: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmissionSessionsScreen(
                                parentTask: widget.parentTask, subTask: liveSubTask),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "VIEW ALL",
                              style: TextStyle(
                                color: activeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(MdiIcons.chevronRight, color: activeAccent, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Date navigation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SubmissionDateNavigator(
                        selectedDate: _selectedDate,
                        onPrevious: () => setState(
                          () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
                        ),
                        onNext: canGoForward
                            ? () => setState(
                                () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
                              )
                            : null,
                        onResetToday: isToday ? null : () => setState(() => _selectedDate = DateTime.now()),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: JweTheme.bgBase,
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: ScheduleTimeline(
                          entries: timelineEntries,
                          onAddSession: () => _showAddSessionDialog(provider),
                          onEditEntry: (entry) {
                            if (entry.originalObject is TaskSession) {
                              _handleSessionEdit(
                                context,
                                provider,
                                entry.originalObject as TaskSession,
                              );
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Footer actions ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SubmissionFooterActions(
                        onComplete: () {
                          provider.taskActions.completeSubtask(
                            widget.parentTask.id,
                            liveSubTask.id,
                          );
                          Navigator.pop(context);
                        },
                        onDelete: () {
                          provider.taskActions.deleteSubtask(
                            widget.parentTask.id,
                            liveSubTask.id,
                          );
                          Navigator.pop(context);
                        },
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
