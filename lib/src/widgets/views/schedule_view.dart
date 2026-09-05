import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';
import 'package:missions/src/widgets/schedule/protocol_control_panel.dart';
import 'package:missions/src/widgets/schedule/schedule_hero_widget.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/screens/schedule/today_planner_screen.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/widgets/screens/checkpoint_detail_screen.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class ScheduleView extends StatefulWidget {
  final ValueListenable<int>? openTick;
  const ScheduleView({super.key, this.openTick});

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
          colorScheme: JweTheme.pickerScheme(
              accent: AppTheme.fhAccentTeal, surface: AppTheme.fhBgDark),
          dialogTheme:   DialogThemeData(backgroundColor: AppTheme.fhBgDeepDark),
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

  void _showManualPredictionDialog(BuildContext context, AppProvider provider) {
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Predictions only available for today.")));
      return;
    }

    final activeMainTasks = provider.mainTasks.where((t) => !t.isDeleted && t.isActive).toList();
    MainTask? selectedMainTask = activeMainTasks.isNotEmpty ? activeMainTasks.first : null;
    final activityCtrl = TextEditingController();
    TimeOfDay selectedStartTime = TimeOfDay.now();
    int selectedDurationMinutes = 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppTheme.fhBgMedium,
            title: Row(
              children: [
                Icon(MdiIcons.crystalBall, color: JweTheme.accentCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MANUAL PREDICTED EVENT',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SELECT TASK / PROTOCOL', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<MainTask>(
                    value: selectedMainTask,
                    dropdownColor: AppTheme.fhBgMedium,
                    items: activeMainTasks.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name, style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedMainTask = val),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: JweTheme.bgCanvas,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('PREDICTED ACTIVITY NAME', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: activityCtrl,
                    style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Focus Session',
                      hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: JweTheme.bgCanvas,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('START TIME', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(context: context, initialTime: selectedStartTime);
                                if (time != null) setModalState(() => selectedStartTime = time);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: JweTheme.bgCanvas,
                                  border: Border.all(color: JweTheme.lineSoft),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  selectedStartTime.format(context),
                                  style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DURATION (MINS)', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: selectedDurationMinutes,
                              dropdownColor: AppTheme.fhBgMedium,
                              items: const [15, 25, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('${d}m', style: TextStyle(color: Colors.white, fontSize: 13)),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedDurationMinutes = val);
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: JweTheme.bgCanvas,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  final title = activityCtrl.text.trim().isNotEmpty
                      ? activityCtrl.text.trim()
                      : (selectedMainTask?.name ?? 'Manual Event');
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day, selectedStartTime.hour, selectedStartTime.minute);
                  final end = start.add(Duration(minutes: selectedDurationMinutes));

                  final entry = TimelineEntry(
                    id: "pred_manual_${DateTime.now().millisecondsSinceEpoch}",
                    startTime: start,
                    endTime: end,
                    title: title,
                    subtitle: selectedMainTask?.name ?? 'Manual Prediction',
                    color: selectedMainTask?.taskColor ?? AppTheme.fhAccentTeal,
                    isPredicted: true,
                    isEditable: true,
                  );

                  setState(() {
                    _predictedEntries.add(entry);
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Manual predicted event added to schedule!')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: JweTheme.bgBase),
                child: const Text('ADD PREDICTION'),
              ),
            ],
          );
        },
      ),
    );
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

    // 3. Process predicted entries (ensure no overlap unless all lessons are less than 5 minutes)
    for (var pred in _predictedEntries) {
      bool overlaps = false;
      for (var real in entries) {
        if (pred.startTime.isBefore(real.endTime) && pred.endTime.isAfter(real.startTime)) {
          final predIsShort = pred.endTime.difference(pred.startTime) < const Duration(minutes: 5);
          final realIsShort = real.endTime.difference(real.startTime) < const Duration(minutes: 5);
          if (!(predIsShort && realIsShort)) {
            overlaps = true;
            break;
          }
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
                      title: Text(sub.name, style:   TextStyle(color: AppTheme.fhTextPrimary)),
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
            child:   Text("REMOVE", style: TextStyle(color: AppTheme.fhAccentRed))
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

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = List<String>.from(provider.taskActions.getDayPlan(selectedDateStr));

    // PRIORITY 1 — a live, running session always claims the hero spot.
    final runningEntry = provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    if (runningEntry != null) {
      final m = provider.mainTasks.firstWhereOrNull(
          (t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted);
      final s = m?.subTasks
          .firstWhereOrNull((st) => st.id == runningEntry.key && !st.isDeleted);
      if (m != null && s != null && !s.completed) {
        nextMainTask = m;
        nextSubTask = s;
        // If this task is in selected date's plan, retain its queue id so the
        // "FINISH" button still drops it from the plan.
        final inPlan = plan.firstWhereOrNull((p) {
          final parts = p.split('|');
          return parts.length >= 2 && parts[0] == m.id && parts[1] == s.id;
        });
        if (inPlan != null) {
          nextQueueId = inPlan;
          final parts = inPlan.split('|');
          if (parts.length == 3) {
            final cp = s.findCheckpoint(parts[2]);
            if (cp != null) {
              final cpDepth = TaskCalculations.findCheckpointDepth(s.subSubTasks, parts[2]) ?? 1;
              nextCheckpoint = TaskCalculations.findTargetIncompleteCheckpoint(cp, maxDepth: s.depth, currentDepth: cpDepth) ?? cp;
            }
          } else {
            nextCheckpoint = TaskCalculations.nextCheckpoint(s);
          }
        } else {
          nextCheckpoint = TaskCalculations.nextCheckpoint(s);
        }
      }
    }

    // PRIORITY 2 — fall back to the next uncompleted entry in the day plan.
    if (nextSubTask == null) {
      for (String idPair in plan) {
        final parts = idPair.split('|');
        if (parts.length >= 2) {
          final mTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
          final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);

          if (sTask != null && !sTask.completed) {
            if (parts.length == 3) {
              // It's a checkpoint
              final cp = sTask.findCheckpoint(parts[2]);
              if (cp != null && !cp.completed) {
                final cpDepth = TaskCalculations.findCheckpointDepth(sTask.subSubTasks, parts[2]) ?? 1;
                nextQueueId = idPair;
                nextMainTask = mTask;
                nextSubTask = sTask;
                nextCheckpoint = TaskCalculations.findTargetIncompleteCheckpoint(cp, maxDepth: sTask.depth, currentDepth: cpDepth) ?? cp;
                break;
              }
            } else {
              // It's a subtask
              nextQueueId = idPair;
              nextMainTask = mTask;
              nextSubTask = sTask;
              nextCheckpoint = TaskCalculations.nextCheckpoint(sTask);
              break;
            }
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

    final now = DateTime.now();
    final dayWindow = resolveDayWindow(provider, now);
    final plannedMin =
        provider.taskActions.plannedMinutesForDay(selectedDateStr);
    final realisticMin = dayWindow.realisticMinutes(now);

    final topFiveTasks = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: provider.mainTasks,
      plan: plan,
    );

    final planRows = provider.taskActions.getDayPlanRows(selectedDateStr);
    List<String> activeRowCompoundIds = [];
    if (nextSubTask != null) {
      final activeSubId = nextSubTask.id;
      for (final row in planRows) {
        if (row.any((id) {
          final parts = id.split('|');
          return parts.length >= 2 && parts[1] == activeSubId;
        })) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    if (activeRowCompoundIds.isEmpty) {
      for (final row in planRows) {
        bool hasUncompleted = false;
        for (final id in row) {
          final parts = id.split('|');
          if (parts.length >= 2) {
            final m = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
            final s = m?.subTasks.firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted);
            if (s != null && !s.completed) {
              if (parts.length == 3) {
                final cp = s.findCheckpoint(parts[2]);
                if (cp != null && !cp.completed) {
                  hasUncompleted = true;
                  break;
                }
              } else {
                hasUncompleted = true;
                break;
              }
            }
          }
        }
        if (hasUncompleted) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    final multitaskItems = TaskCalculations.resolveDayPlanItems(
      mainTasks: provider.mainTasks,
      compoundIds: activeRowCompoundIds,
    );

    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    Widget leftPanel = Column(
      children: [
        if (isToday) _CarryoverBanner(provider: provider),

        // HERO SECTION
        ScheduleHeroWidget(
          mainTask: nextMainTask,
          subTask: nextSubTask,
          checkpoint: nextCheckpoint,
          isRunning: isRunning,
          plannedMinutes: plannedMin,
          realisticMinutes: realisticMin,
          accumulatedTodaySeconds: accumulatedTodaySeconds,
          sessionStart: sessionStart,
          topFiveTasks: topFiveTasks,
          multitaskItems: multitaskItems,
          onCheckMultitaskItem: (item) {
            if (item.targetCheckpointId != null) {
              provider.taskActions.completeSubSubtask(item.mainTaskId, item.subTaskId, item.targetCheckpointId!);
            } else {
              provider.taskActions.completeSubtask(item.mainTaskId, item.subTaskId);
            }
            final currentPlan = List<String>.from(provider.taskActions.getDayPlan(selectedDateStr));
            currentPlan.remove(item.compoundId);
            provider.taskActions.updateDayPlan(selectedDateStr, currentPlan);
          },
          onCheckTask: (item) {
            if (item.targetCheckpointId != null) {
              provider.taskActions.completeSubSubtask(item.mainTaskId, item.subTaskId, item.targetCheckpointId!);
            } else {
              provider.taskActions.completeSubtask(item.mainTaskId, item.subTaskId);
            }
            final currentPlan = List<String>.from(provider.taskActions.getDayPlan(selectedDateStr));
            currentPlan.remove(item.compoundId);
            provider.taskActions.updateDayPlan(selectedDateStr, currentPlan);
          },
          onOpenPlan: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => TodayPlannerScreen(
               date: selectedDateStr,
             )));
          },
          onPlayPause: () {
            if (nextSubTask == null || nextMainTask == null) return;
            if (isRunning) {
              provider.pauseTimer(nextSubTask.id);
              provider.logTimerAndReset(nextSubTask.id);
            } else {
              provider.startTimer(nextSubTask.id, 'subtask', nextMainTask.id);
            }
          },
          onFinishCheckpoint: () {
            if (nextQueueId != null && nextCheckpoint != null && nextMainTask != null && nextSubTask != null) {
              provider.taskActions.completeSubSubtask(nextMainTask.id, nextSubTask.id, nextCheckpoint.id);
              final parts = nextQueueId.split('|');
              if (parts.length == 3) {
                final newPlan = List<String>.from(plan)..remove(nextQueueId);
                provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
              } else {
                final remainingNext = TaskCalculations.nextCheckpoint(nextSubTask);
                if (remainingNext == null) {
                  final newPlan = List<String>.from(plan)..remove(nextQueueId);
                  provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
                }
              }
            }
          },
          onFinishSubTask: () {
            if (nextQueueId != null && nextMainTask != null && nextSubTask != null) {
              provider.taskActions.completeSubtask(nextMainTask.id, nextSubTask.id);
              final newPlan = List<String>.from(plan)..remove(nextQueueId);
              provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
            }
          },
          onTitleTap: () {
            final m = nextMainTask;
            final s = nextSubTask;
            final cp = nextCheckpoint;
            if (m != null && s != null) {
              if (cp != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
                  mainTaskId: m.id,
                  parentSubTaskId: s.id,
                  checkpointId: cp.id,
                )));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionDetailScreen(
                  parentTask: m,
                  subTask: s,
                )));
              }
            }
          },
        ),
        
        // CONTROLS — tactical date strip
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
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
                  tooltip: 'PREDICT (Tap: AI Predict | Long-Click: Manual Event)',
                  onTap: _isPredicting ? null : () => _handlePredictSchedule(context, provider),
                  onLongPress: _isPredicting ? null : () => _showManualPredictionDialog(context, provider),
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
      ],
    );

    Widget timelineWidget = ScheduleTimeline(
      entries: entries,
      onAddSession: () => _handleAddSession(context, provider),
      onEditEntry: (entry) => _handleEditEntry(context, provider, entry),
      initialScrollOffset: 0,
      scrollToNow: isToday,
      scrollToNowTick: widget.openTick,
    );

    if (isLargeScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 440,
            child: SingleChildScrollView(child: leftPanel),
          ),
          Container(width: 1, color: JweTheme.lineSoft),
          Expanded(child: timelineWidget),
        ],
      );
    }

    return Column(
      children: [
        leftPanel,
        Expanded(child: timelineWidget),
      ],
    );
  }
}

class _CarryoverBanner extends StatelessWidget {
  final AppProvider provider;

  const _CarryoverBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final today = helper.getTodayDateString();
    if (provider.taskActions.wasCarryoverHandled(today)) {
      return const SizedBox.shrink();
    }
    final yesterday =
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    if (!provider.taskActions.hasUnfinishedPlan(yesterday)) {
      return const SizedBox.shrink();
    }

    final unfinishedCount = provider.taskActions
        .getDayPlan(yesterday)
        .where((id) {
      final parts = id.split('|');
      if (parts.length < 2) return false;
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (task == null || sub == null) return false;
      if (parts.length == 3) {
        final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
        return cp != null && !cp.completed;
      }
      return !sub.completed;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.fhAccentTeal.withOpacity(0.08),
        border: Border(
          left: BorderSide(color: AppTheme.fhAccentTeal, width: 3),
          bottom: BorderSide(color: AppTheme.fhBorderColor),
        ),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.arrowRightBoldOutline,
              size: 16, color: AppTheme.fhAccentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$unfinishedCount unfinished from yesterday',
              style:   TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => provider.taskActions.dismissCarryover(today),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child:   Text('DISMISS',
                style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () =>
                provider.taskActions.carryOverUnfinished(yesterday, today),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child:   Text('CARRY OVER',
                style: TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ScheduleControlIcon extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? accent;
  final String? tooltip;
  final bool loading;

  final VoidCallback? onLongPress;

  const _ScheduleControlIcon({
    this.icon,
    this.onTap,
    this.onLongPress,
    this.accent,
    this.tooltip,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && onLongPress == null;
    final activeAccent = accent ?? JweTheme.accentCyan;
    Widget child = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled ? JweTheme.lineSoft : activeAccent.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6, valueColor: AlwaysStoppedAnimation<Color>(activeAccent)),
            )
          : Icon(icon, size: 16, color: disabled ? JweTheme.textMuted : activeAccent),
    );
    if (onTap != null || onLongPress != null) {
      child = InkWell(onTap: onTap, onLongPress: onLongPress, child: child);
    }
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return child;
  }
}