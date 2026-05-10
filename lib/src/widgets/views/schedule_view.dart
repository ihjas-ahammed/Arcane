import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';
import 'package:missions/src/widgets/schedule/protocol_control_panel.dart';
import 'package:missions/src/widgets/schedule/schedule_hero_widget.dart';
import 'package:missions/src/widgets/schedule/day_plan_dashboard_widget.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/screens/schedule/day_plan_screen.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/widgets/screens/checkpoint_detail_screen.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  DateTime _selectedDate = DateTime.now();
  List<TimelineEntry> _predictedEntries = [];
  bool _isPredicting = false;

  // --- Date Control ---
  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _predictedEntries.clear(); 
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTeal,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDark,
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppTheme.fhBgDeepDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _predictedEntries.clear();
      });
    }
  }

  // --- Prediction ---
  Future<void> _handlePredictSchedule(BuildContext context, AppProvider provider) async {
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Predictions only available for today.")));
      return;
    }
    setState(() => _isPredicting = true);
    try {
      final newEntries = await provider.scheduleActions.predictSchedule();
      setState(() {
        _predictedEntries = newEntries;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prediction failed: $e")));
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  // --- Entries Merging ---
  List<TimelineEntry> _buildEntries(AppProvider provider) {
    final List<TimelineEntry> entries = [];
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 1. Process standard recorded sessions
    // We explicitly DON'T filter deleted tasks here because we want historical records to remain intact!
    for (var task in provider.mainTasks) {
      for (var sub in task.subTasks) {
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

    // 2. Inject currently running (LIVE) sessions
    provider.activeTimers.forEach((subTaskId, timerState) {
      if (timerState.isRunning && timerState.type == 'subtask') {
        final task = provider.mainTasks.firstWhereOrNull((t) => t.id == timerState.mainTaskId);
        final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subTaskId);
        if (task != null && sub != null) {
          final now = DateTime.now();
          if (timerState.startTime.isBefore(dayEnd) && now.isAfter(dayStart)) {
            DateTime displayStart = timerState.startTime.isBefore(dayStart) ? dayStart : timerState.startTime;
            DateTime displayEnd = now.isAfter(dayEnd) ? dayEnd : now;

            if (displayEnd.isAfter(displayStart)) {
              entries.add(TimelineEntry(
                id: 'live_$subTaskId',
                startTime: displayStart,
                endTime: displayEnd,
                title: sub.name,
                subtitle: "${task.name} (LIVE)",
                color: task.taskColor,
                isEditable: false,
              ));
            }
          }
        }
      }
    });

    // 3. Process predicted entries (ensure no overlap)
    for (var pred in _predictedEntries) {
      bool overlaps = false;
      for (var real in entries) {
        if (pred.startTime.isBefore(real.endTime) && pred.endTime.isAfter(real.startTime)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) entries.add(pred);
    }

    return entries;
  }

  // --- Handlers ---
  void _openProtocolControl(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ProtocolControlPanel(
          protocols: provider.mainTasks.where((t) => !t.isDeleted).toList(),
          selectedProtocolId: provider.selectedTaskId,
          onSelect: (id) => provider.setSelectedTaskId(id),
          onAdd: () => _showAddProtocolDialog(context, provider),
          onEdit: (updatedTask) {
            provider.editMainTask(
              updatedTask.id,
              name: updatedTask.name,
              description: updatedTask.description,
              theme: updatedTask.theme,
              colorHex: updatedTask.colorHex,
            );
          },
        ),
      ),
    );
  }

  void _showAddProtocolDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("NEW PROTOCOL"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "NAME"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                provider.addMainTask(
                  name: nameCtrl.text,
                  description: "New Protocol",
                  theme: "general",
                  colorHex: "FF00F8F8" 
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("CREATE"),
          )
        ],
      )
    );
  }

  void _handleAddSession(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => AddSessionDialog(initialDate: _selectedDate),
    );

    if (result != null && mounted) {
      final start = result['start']!;
      final end = result['end']!;
      _showTaskSelectorAndAdd(context, provider, start, end);
    }
  }

  void _showTaskSelectorAndAdd(BuildContext context, AppProvider provider, DateTime start, DateTime end) {
    showDialog(
      context: context,
      builder: (ctx) {
        final validTasks = provider.mainTasks.where((t) => !t.isDeleted).toList();
        return AlertDialog(
          backgroundColor: AppTheme.fhBgMedium,
          title: const Text("SELECT MISSION"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: validTasks.length,
              itemBuilder: (context, index) {
                final task = validTasks[index];
                final activeSubtasks = task.subTasks.where((s) => !s.completed && !s.isDeleted).toList();
                if (activeSubtasks.isEmpty) return const SizedBox.shrink();

                return ExpansionTile(
                  title: Text(task.name, style: TextStyle(color: task.taskColor, fontWeight: FontWeight.bold)),
                  children: activeSubtasks.map((sub) {
                    return ListTile(
                      title: Text(sub.name, style: const TextStyle(color: AppTheme.fhTextPrimary)),
                      onTap: () {
                        provider.addSessionToSubtask(task.id, sub.id, start, end);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _handleEditEntry(BuildContext context, AppProvider provider, TimelineEntry entry) async {
    if (entry.isPredicted) {
      _handlePredictedEntryTap(context, provider, entry);
      return;
    }

    if (entry.originalObject is! TaskSession) return;
    final session = entry.originalObject as TaskSession;
    
    String? mainTaskId;
    String? subTaskId;
    for (var m in provider.mainTasks) {
      for (var s in m.subTasks) {
        if (s.sessions.any((sess) => sess.id == session.id)) {
          mainTaskId = m.id;
          subTaskId = s.id;
          break;
        }
      }
      if (mainTaskId != null) break;
    }

    if (mainTaskId == null || subTaskId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(
        initialStart: session.startTime,
        initialEnd: session.endTime,
      ),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        provider.deleteSessionFromSubtask(mainTaskId, subTaskId, session.id);
      } else if (result['action'] == 'save') {
        provider.updateSessionInSubtask(mainTaskId, subTaskId, session.id, result['start'], result['end']);
      }
    }
  }

  void _handlePredictedEntryTap(BuildContext context, AppProvider provider, TimelineEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.title),
        content: const Text("This is a predicted session. Would you like to confirm it (log it) or remove it?"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _predictedEntries.removeWhere((e) => e.id == entry.id);
              });
              Navigator.pop(ctx);
            }, 
            child: const Text("REMOVE", style: TextStyle(color: AppTheme.fhAccentRed))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showTaskSelectorAndAdd(context, provider, entry.startTime, entry.endTime);
            }, 
            child: const Text("LOG REAL SESSION")
          )
        ],
      )
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final entries = _buildEntries(provider);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    // Resolve Next Task from Day Plan
    String? nextQueueId;
    SubTask? nextSubTask;
    MainTask? nextMainTask;
    SubSubTask? nextCheckpoint;

    final plan = List<String>.from(provider.taskActions.getDayPlan(helper.getTodayDateString()));
    
    for (String idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length >= 2) {
        final mTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
        final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
        
        if (sTask != null && !sTask.completed) {
          if (parts.length == 3) {
            // It's a checkpoint
            final cp = sTask.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
            if (cp != null && !cp.completed) {
              nextQueueId = idPair;
              nextMainTask = mTask;
              nextSubTask = sTask;
              nextCheckpoint = cp;
              break;
            }
          } else {
            // It's a subtask
            nextQueueId = idPair;
            nextMainTask = mTask;
            nextSubTask = sTask;
            break;
          }
        }
      }
    }

    final activeTimer = nextSubTask == null ? null : provider.activeTimers[nextSubTask.id];
    final isRunning = activeTimer?.isRunning == true;
    final accumulatedTodaySeconds = nextSubTask != null
        ? TaskCalculations.getHistoricalTodaySeconds(nextSubTask)
        : 0.0;
    final sessionStart = isRunning ? activeTimer?.startTime : null;

    return Column(
      children: [
        // HERO SECTION
        ScheduleHeroWidget(
          mainTask: nextMainTask,
          subTask: nextSubTask,
          checkpoint: nextCheckpoint,
          isRunning: isRunning,
          accumulatedTodaySeconds: accumulatedTodaySeconds,
          sessionStart: sessionStart,
          onOpenPlan: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const DayPlanScreen()));
          },
          onPlayPause: () {
            if (nextSubTask == null || nextMainTask == null) return;
            if (isRunning) {
              provider.pauseTimer(nextSubTask!.id);
              provider.logTimerAndReset(nextSubTask!.id);
            } else {
              provider.startTimer(nextSubTask!.id, 'subtask', nextMainTask!.id);
            }
          },
          onFinishCheckpoint: () {
            if (nextQueueId != null && nextCheckpoint != null && nextMainTask != null && nextSubTask != null) {
              provider.taskActions.completeSubSubtask(nextMainTask!.id, nextSubTask!.id, nextCheckpoint!.id);
              final newPlan = List<String>.from(plan)..remove(nextQueueId);
              provider.taskActions.updateDayPlan(helper.getTodayDateString(), newPlan);
            }
          },
          onFinishSubTask: () {
            if (nextQueueId != null && nextMainTask != null && nextSubTask != null) {
              provider.taskActions.completeSubtask(nextMainTask!.id, nextSubTask!.id);
              final newPlan = List<String>.from(plan)..remove(nextQueueId);
              provider.taskActions.updateDayPlan(helper.getTodayDateString(), newPlan);
            }
          },
          onTitleTap: () {
            if (nextMainTask != null && nextSubTask != null) {
              if (nextCheckpoint != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
                  mainTaskId: nextMainTask!.id,
                  parentSubTaskId: nextSubTask!.id,
                  checkpointId: nextCheckpoint!.id,
                )));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionDetailScreen(
                  parentTask: nextMainTask!,
                  subTask: nextSubTask!,
                )));
              }
            }
          },
        ),
        
        // --- NEW QUEUE DASHBOARD ---
        if (isToday)
          const DayPlanDashboardWidget(),

        // CONTROLS — tactical date strip
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: JweTheme.bgCanvas,
            border: Border(
              top: BorderSide(color: JweTheme.lineSoft, width: 1),
              bottom: BorderSide(color: JweTheme.lineSoft, width: 1),
            ),
          ),
          child: Row(
            children: [
              _ScheduleControlIcon(
                icon: Icons.chevron_left,
                onTap: () => _shiftDate(-1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: isToday ? JweTheme.lineAmber : JweTheme.lineSoft),
                      color: isToday ? JweTheme.amberSoft : Colors.transparent,
                    ),
                    child: Row(children: [
                      Container(
                        width: 3,
                        height: 22,
                        color: isToday ? JweTheme.accentAmber : JweTheme.accentCyan,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isToday ? 'TODAY · LIVE' : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: isToday ? JweTheme.accentAmber : JweTheme.accentCyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(MdiIcons.calendarBlank, size: 14, color: JweTheme.textMuted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _ScheduleControlIcon(
                icon: Icons.chevron_right,
                onTap: () => _shiftDate(1),
              ),
              const SizedBox(width: 8),
              if (isToday)
                _ScheduleControlIcon(
                  icon: _isPredicting ? null : MdiIcons.crystalBall,
                  loading: _isPredicting,
                  accent: JweTheme.accentCyan,
                  tooltip: 'PREDICT',
                  onTap: _isPredicting ? null : () => _handlePredictSchedule(context, provider),
                ),
              if (isToday) const SizedBox(width: 6),
              _ScheduleControlIcon(
                icon: MdiIcons.console,
                accent: JweTheme.accentAmber,
                tooltip: 'PROTOCOLS',
                onTap: () => _openProtocolControl(context, provider),
              ),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              ScheduleTimeline(
                entries: entries,
                onAddSession: () => _handleAddSession(context, provider),
                onEditEntry: (entry) => _handleEditEntry(context, provider, entry),
                initialScrollOffset: 0,
              ),
              Positioned(
                right: 18,
                bottom: 22,
                child: InkWell(
                  onTap: () => _handleAddSession(context, provider),
                  child: ClipPath(
                    clipper: HudCutClipper(clip: HudClip.both, cut: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber,
                        boxShadow: [
                          BoxShadow(color: JweTheme.accentAmber.withValues(alpha: 0.55), blurRadius: 14),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(MdiIcons.plus, color: JweTheme.bgDeep, size: 16),
                        const SizedBox(width: 6),
                        Text('LOG SESSION',
                            style: GoogleFonts.saira(
                              color: JweTheme.bgDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            )),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleControlIcon extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final Color accent;
  final String? tooltip;
  final bool loading;

  const _ScheduleControlIcon({
    this.icon,
    this.onTap,
    this.accent = JweTheme.accentCyan,
    this.tooltip,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    Widget child = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled ? JweTheme.lineSoft : accent.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6, valueColor: AlwaysStoppedAnimation<Color>(accent)),
            )
          : Icon(icon, size: 16, color: disabled ? JweTheme.textMuted : accent),
    );
    if (onTap != null) {
      child = InkWell(onTap: onTap, child: child);
    }
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return child;
  }
}