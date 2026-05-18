import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/dialogs/subtask_config_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';
import 'package:missions/src/widgets/ui/active_session_timer_display.dart';
import 'package:missions/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_resources_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_steps_list.dart';
import 'package:missions/src/widgets/screens/submission_sessions_screen.dart';
import 'package:missions/src/widgets/charts/subtask_weekly_chart.dart';
import 'package:missions/src/widgets/charts/subtask_progress_time_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
      ),
    );
    if (result != null) {
      provider.taskActions.updateSubtask(widget.parentTask.id, widget.subTask.id, result);
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
    final double todaySeconds = TaskCalculations.getTodaySeconds(liveSubTask, timerState);
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: JweTheme.panel,
                border: Border(bottom: BorderSide(color: JweTheme.line)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: JweTheme.border),
                        color: JweTheme.bgBase,
                      ),
                      child: const Icon(Icons.arrow_back, color: JweTheme.textMid, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parentTask.name.toUpperCase(),
                          style: TextStyle(
                              color: activeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            liveSubTask.name.toUpperCase(),
                            style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                letterSpacing: 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (liveSubTask.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.6)),
                        color: JweTheme.accentTeal.withValues(alpha: 0.08),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DONE',
                            style: TextStyle(
                                color: JweTheme.accentTeal,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5),
                          ),
                          if (liveSubTask.lastCompletedDate != null)
                            Text(
                              DateFormat('MMM d · HH:mm').format(liveSubTask.lastCompletedDate!),
                              style: TextStyle(
                                  color: JweTheme.accentTeal.withValues(alpha: 0.7),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isRunning
                                ? JweTheme.accentRed.withValues(alpha: 0.6)
                                : JweTheme.border),
                        color: isRunning
                            ? JweTheme.accentRed.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRunning ? JweTheme.accentRed : JweTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isRunning ? "ACTIVE" : "STANDBY",
                            style: TextStyle(
                                color: isRunning ? JweTheme.accentRed : JweTheme.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _handleEditSubtask(context, provider, liveSubTask),
                    child: Icon(MdiIcons.pencilOutline, color: JweTheme.textMid, size: 20),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Timer card ───────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: JweTheme.panel,
                        border: Border(
                          left: BorderSide(
                              color: isRunning ? JweTheme.accentRed : activeAccent, width: 3),
                          top: BorderSide(color: JweTheme.border),
                          right: BorderSide(color: JweTheme.border),
                          bottom: BorderSide(color: JweTheme.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isRunning ? "CURRENT SESSION" : "TODAY'S LOG",
                                  style: TextStyle(
                                      color: isRunning
                                          ? JweTheme.accentRed
                                          : JweTheme.textMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0),
                                ),
                                const SizedBox(height: 4),
                                ActiveSessionTimerDisplay(
                                  isRunning: isRunning,
                                  startTime: timerState?.startTime,
                                  totalTodaySeconds: todaySeconds,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (isRunning) {
                                provider.timerActions.pauseTimer(liveSubTask!.id);
                                provider.timerActions.logTimerAndReset(liveSubTask.id);
                              } else {
                                provider.timerActions.startTimer(
                                    liveSubTask!.id, 'subtask', widget.parentTask.id);
                              }
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isRunning
                                    ? JweTheme.accentRed.withValues(alpha: 0.12)
                                    : activeAccent.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: isRunning ? JweTheme.accentRed : activeAccent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isRunning ? MdiIcons.stop : MdiIcons.play,
                                color: isRunning ? JweTheme.accentRed : activeAccent,
                                size: 28,
                              ),
                            ),
                          ).animate(key: ValueKey(isRunning)).fadeIn(duration: 200.ms),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Action plan section ──────────────────────────
                    _SectionLabel(
                      label: "ACTION PLAN",
                      accentColor: activeAccent,
                      icon: MdiIcons.formatListChecks,
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ActionPlanStepsList(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            steps: liveSubTask.subSubTasks,
                            accentColor: activeAccent,
                            onGenerate: (prompt) => provider.aiGenerationActions
                                .generateActionPlanSteps(
                                    widget.parentTask.id, liveSubTask!.id, liveSubTask.why, prompt),
                          ),
                          const SizedBox(height: 16),
                          ActionPlanWhyCard(
                            initialWhy: liveSubTask.why,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask!.id, {'why': val}),
                          ),
                          const SizedBox(height: 10),
                          ActionPlanOutcomeCard(
                            initialWhat: liveSubTask.what,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask!.id, {'what': val}),
                          ),
                          const SizedBox(height: 10),
                          ActionPlanResourcesCard(
                            mainTaskId: widget.parentTask.id,
                            subTaskId: liveSubTask.id,
                            initialResources: liveSubTask.resources,
                            accentColor: activeAccent,
                            onChanged: (val) => provider.taskActions.updateSubtask(
                                widget.parentTask.id, liveSubTask!.id, {'resources': val}),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Weekly chart section ─────────────────────────
                    _SectionLabel(
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
                    _SectionLabel(
                      label: "PROGRESS · TIME",
                      accentColor: activeAccent,
                      icon: MdiIcons.chartLine,
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SubtaskProgressTimeChart(
                        subTask: liveSubTask,
                        accentColor: activeAccent,
                        currentSpentSeconds: liveSubTask.sessions.fold(0, (s, sess) => s + sess.durationSeconds) +
                            (isRunning && timerState?.startTime != null
                                ? DateTime.now().difference(timerState!.startTime).inSeconds
                                : 0),
                        onAddEntry: (progress, spentSeconds) => provider.saveProgressDataPoint(
                            widget.parentTask.id, liveSubTask.id, progress, spentSeconds),
                        onDeleteEntry: (index) => provider.deleteProgressDataPoint(
                            widget.parentTask.id, liveSubTask.id, index),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Timeline section ─────────────────────────────
                    _SectionLabel(
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
                            Text("VIEW ALL",
                                style: TextStyle(
                                    color: activeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0)),
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: JweTheme.panel,
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: Row(
                          children: [
                            _DateNavBtn(
                              icon: MdiIcons.chevronLeft,
                              onTap: () => setState(() =>
                                  _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: isToday
                                    ? null
                                    : () => setState(() => _selectedDate = DateTime.now()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Text(
                                        DateFormat('EEE, MMM dd yyyy')
                                            .format(_selectedDate)
                                            .toUpperCase(),
                                        style: GoogleFonts.chakraPetch(
                                            color: JweTheme.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 0.5),
                                      ),
                                      if (!isToday) ...[
                                        const SizedBox(height: 2),
                                        Text("TAP TO RETURN TODAY",
                                            style: TextStyle(
                                                color: JweTheme.accentAmber.withValues(alpha: 0.7),
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _DateNavBtn(
                              icon: MdiIcons.chevronRight,
                              enabled: canGoForward,
                              onTap: canGoForward
                                  ? () => setState(() =>
                                      _selectedDate = _selectedDate.add(const Duration(days: 1)))
                                  : null,
                            ),
                          ],
                        ),
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
                          onAddSession: () => _showAddSessionDialog(context, provider),
                          onEditEntry: (entry) {
                            if (entry.originalObject is TaskSession) {
                              _handleSessionEdit(
                                  context, provider, entry.originalObject as TaskSession);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Footer actions ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 1,
                            color: JweTheme.lineAmber,
                            margin: const EdgeInsets.only(bottom: 20),
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    provider.taskActions.completeSubtask(
                                        widget.parentTask.id, liveSubTask.id);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: JweTheme.accentTeal.withValues(alpha: 0.12),
                                      border: Border.all(color: JweTheme.accentTeal),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(MdiIcons.checkCircleOutline,
                                            color: JweTheme.accentTeal, size: 16),
                                        const SizedBox(width: 8),
                                        Text("COMPLETE",
                                            style: GoogleFonts.rajdhani(
                                                color: JweTheme.accentTeal,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                letterSpacing: 1.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    provider.taskActions.deleteSubtask(
                                        widget.parentTask.id, liveSubTask.id);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: JweTheme.accentRed),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(MdiIcons.deleteOutline,
                                            color: JweTheme.accentRed, size: 16),
                                        const SizedBox(width: 8),
                                        Text("DELETE",
                                            style: GoogleFonts.rajdhani(
                                                color: JweTheme.accentRed,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                letterSpacing: 1.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color accentColor;
  final IconData icon;
  final Widget? trailing;

  const _SectionLabel({
    required this.label,
    required this.accentColor,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: accentColor),
          const SizedBox(width: 8),
          Icon(icon, color: accentColor, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.rajdhani(
                  color: JweTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _DateNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _DateNavBtn({required this.icon, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: JweTheme.border)),
        ),
        child: Icon(icon,
            color: enabled ? JweTheme.textMid : JweTheme.textMuted.withValues(alpha: 0.3),
            size: 20),
      ),
    );
  }
}
