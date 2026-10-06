import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/schedule/external_ai_schedule_screen.dart';
import 'package:missions/src/screens/schedule/today_planner_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/dialogs/add_session_dialog.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/widgets/schedule/schedule.dart';
import 'package:missions/src/widgets/screens/checkpoint_detail_screen.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';

export 'package:missions/src/widgets/schedule/schedule.dart';

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
            accent: JweTheme.accentTeal,
            surface: JweTheme.panel,
          ),
          dialogTheme: DialogThemeData(backgroundColor: JweTheme.bgDeep),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _predictedEntries.clear();
      });
    }
  }

  Future<void> _handlePredictSchedule(AppProvider provider) async {
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    TimeOfDay startTime = isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0);

    if (!isToday) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: startTime,
        helpText: 'SELECT SCHEDULE START TIME FOR ${DateFormat('MMM d').format(_selectedDate).toUpperCase()}',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: JweTheme.pickerScheme(
                accent: JweTheme.accentAmber,
                surface: JweTheme.panel,
              ),
              dialogTheme: DialogThemeData(backgroundColor: JweTheme.bgDeep),
            ),
            child: child!,
          );
        },
      );
      if (pickedTime == null) return;
      startTime = pickedTime;
    }

    setState(() => _isPredicting = true);
    try {
      final newEntries = await provider.scheduleActions.predictSchedule(
        targetDate: _selectedDate,
        startTime: startTime,
      );
      if (!mounted) return;
      setState(() {
        _predictedEntries = newEntries;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.accentTeal,
          content: Text(
            '✓ Predicted ${newEntries.length} shadow plan sessions for ${DateFormat('MMM d').format(_selectedDate)}',
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prediction failed: $e")));
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  void _openExternalAiSchedule(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExternalAiScheduleScreen(initialDate: _selectedDate),
      ),
    );
  }

  void _showPredictOptions(BuildContext context, AppProvider provider) {
    final activeOverlay = provider.scheduleActions.getPredictedEntriesForDate(_selectedDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: JweTheme.border),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.crystalBall, size: 18, color: JweTheme.accentCyan),
                  const SizedBox(width: 8),
                  Text(
                    'SCHEDULE PREDICTION & PLAN OVERLAY',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: JweTheme.panel2,
                leading: Icon(MdiIcons.robotOutline, color: JweTheme.accentCyan),
                title: Text(
                  'EXTERNAL AI PREDICTOR (OVERLAY)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.isLight ? JweTheme.accentCyan : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Export context dataset, copy prompt, and paste frontier AI output as non-editable blueprint overlay.',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openExternalAiSchedule(context);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: JweTheme.panel2,
                leading: Icon(Icons.flash_on_rounded, color: JweTheme.accentAmber),
                title: Text(
                  'IN-APP AI PREDICT',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.isLight ? JweTheme.accentAmber : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Synthesize prediction directly via in-app Gemini API.',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePredictSchedule(provider);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: JweTheme.panel2,
                leading: Icon(Icons.add_task_rounded, color: JweTheme.textWhite),
                title: Text(
                  'MANUAL PREDICTION EVENT',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Manually add a predicted blueprint event block.',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualPrediction(provider);
                },
              ),
              if (activeOverlay.isNotEmpty || _predictedEntries.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: JweTheme.accentRed.withValues(alpha: 0.12),
                  leading: Icon(Icons.layers_clear_rounded, color: JweTheme.accentRed),
                  title: Text(
                    'CLEAR PREDICTED OVERLAY (${activeOverlay.length + _predictedEntries.length} BLOCKS)',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Remove all predicted ghost blocks for this date.',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await provider.scheduleActions.clearPredictedEntriesForDate(_selectedDate);
                    setState(() {
                      _predictedEntries.clear();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showManualPrediction(AppProvider provider) {
    showManualPredictionDialog(
      context: context,
      provider: provider,
      selectedDate: _selectedDate,
      onAddPrediction: (entry) {
        final nonEditable = entry.copyWith(isPredicted: true, isEditable: false);
        setState(() {
          _predictedEntries.add(nonEditable);
        });
        provider.scheduleActions.setPredictedEntriesForDate(
          _selectedDate,
          [...provider.scheduleActions.getPredictedEntriesForDate(_selectedDate), nonEditable],
        );
      },
    );
  }

  List<TimelineEntry> _buildEntries(AppProvider provider) {
    final persisted = provider.scheduleActions.getPredictedEntriesForDate(_selectedDate);
    final combinedPredicted = [
      ...persisted,
      ..._predictedEntries.where((p) => !persisted.any((e) => e.id == p.id)),
    ];
    return ScheduleEntryResolver.buildEntries(
      provider: provider,
      selectedDate: _selectedDate,
      predictedEntries: combinedPredicted,
    );
  }

  void _openProtocolControl(AppProvider provider) {
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
          onAdd: () => _showAddProtocolDialog(provider),
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

  void _showAddProtocolDialog(AppProvider provider) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
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
                  colorHex: "FF00F8F8",
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("CREATE"),
          )
        ],
      ),
    );
  }

  void _handleAddSession(AppProvider provider) async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => AddSessionDialog(initialDate: _selectedDate),
    );

    if (result != null && mounted) {
      final start = result['start']!;
      final end = result['end']!;
      _showTaskSelectorAndAdd(provider, start, end);
    }
  }

  void _showTaskSelectorAndAdd(AppProvider provider, DateTime start, DateTime end) {
    showDialog(
      context: context,
      builder: (ctx) {
        final validTasks = provider.mainTasks.where((t) => !t.isDeleted).toList();
        return AlertDialog(
          backgroundColor: JweTheme.panel,
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
                      title: Text(sub.name, style: TextStyle(color: JweTheme.textWhite)),
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
      },
    );
  }

  Future<void> _handleDeleteEntry(AppProvider provider, TimelineEntry entry) async {
    if (entry.isPredicted || entry.originalObject is! TaskSession) return;
    final session = entry.originalObject as TaskSession;

    String? mainTaskId;
    String? subTaskId;
    for (final m in provider.mainTasks) {
      for (final s in m.subTasks) {
        if (s.sessions.any((sess) => sess.id == session.id)) {
          mainTaskId = m.id;
          subTaskId = s.id;
        }
      }
    }
    if (mainTaskId == null || subTaskId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          '${DateFormat('HH:mm').format(session.startTime)} – ${DateFormat('HH:mm').format(session.endTime)}'
          ' (${session.endTime.difference(session.startTime).inMinutes} min)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      provider.deleteSessionFromSubtask(mainTaskId, subTaskId, session.id);
    }
  }

  void _handleEditEntry(AppProvider provider, TimelineEntry entry) async {
    if (entry.isPredicted) {
      _handlePredictedEntryTap(provider, entry);
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

    if (result != null && mounted) {
      if (result['action'] == 'delete') {
        provider.deleteSessionFromSubtask(mainTaskId, subTaskId, session.id);
      } else if (result['action'] == 'save') {
        provider.updateSessionInSubtask(mainTaskId, subTaskId, session.id, result['start'], result['end']);
      }
    }
  }

  void _handleUpdateEntryTimeRange(AppProvider provider, TimelineEntry entry, DateTime newStart, DateTime newEnd) {
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
    provider.updateSessionInSubtask(mainTaskId, subTaskId, session.id, newStart, newEnd);
  }

  void _handleSwitchTask(AppProvider provider, TimelineEntry entry) {
    if (entry.originalObject is! TaskSession) return;
    final session = entry.originalObject as TaskSession;

    String? currentMainTaskId;
    String? currentSubTaskId;
    for (var m in provider.mainTasks) {
      for (var s in m.subTasks) {
        if (s.sessions.any((sess) => sess.id == session.id)) {
          currentMainTaskId = m.id;
          currentSubTaskId = s.id;
          break;
        }
      }
      if (currentMainTaskId != null) break;
    }

    if (currentMainTaskId == null || currentSubTaskId == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final validTasks = provider.mainTasks.where((t) => !t.isDeleted).toList();
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          title: Text(
            "SWITCH MISSION",
            style: TextStyle(
              color: JweTheme.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
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
                  initiallyExpanded: task.id == currentMainTaskId,
                  title: Text(task.name, style: TextStyle(color: task.taskColor, fontWeight: FontWeight.bold)),
                  children: activeSubtasks.map((sub) {
                    final isCurrent = sub.id == currentSubTaskId;
                    return ListTile(
                      title: Text(
                        sub.name,
                        style: TextStyle(
                          color: isCurrent ? JweTheme.accentCyan : JweTheme.textWhite,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isCurrent ? Icon(Icons.check, size: 16, color: JweTheme.accentCyan) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isCurrent) {
                          provider.deleteSessionFromSubtask(currentMainTaskId!, currentSubTaskId!, session.id, silent: true);
                          provider.addSessionToSubtask(task.id, sub.id, session.startTime, session.endTime);
                          HapticFeedback.mediumImpact();
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handlePredictedEntryTap(AppProvider provider, TimelineEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(entry.title, style: TextStyle(color: JweTheme.textWhite)),
        content: Text(
          "This is a predicted session. Would you like to confirm it (log it) or remove it?",
          style: TextStyle(color: JweTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _predictedEntries.removeWhere((e) => e.id == entry.id);
              });
              provider.scheduleActions.removePredictedEntry(_selectedDate, entry.id);
              Navigator.pop(ctx);
            },
            child: Text("REMOVE", style: TextStyle(color: JweTheme.accentRed)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showTaskSelectorAndAdd(provider, entry.startTime, entry.endTime);
            },
            child: const Text("LOG REAL SESSION"),
          ),
        ],
      ),
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
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = List<String>.from(provider.taskActions.getDayPlan(selectedDateStr));

    final heroState = ScheduleHeroStateResolver.resolve(
      provider: provider,
      selectedDate: _selectedDate,
    );

    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    Widget leftPanel = Column(
      children: [
        if (isToday) CarryoverBanner(provider: provider),

        // HERO SECTION
        ScheduleHeroWidget(
          mainTask: heroState.nextMainTask,
          subTask: heroState.nextSubTask,
          checkpoint: heroState.nextCheckpoint,
          isRunning: heroState.isRunning,
          plannedMinutes: heroState.plannedMin,
          realisticMinutes: heroState.realisticMin,
          accumulatedTodaySeconds: heroState.accumulatedTodaySeconds,
          sessionStart: heroState.sessionStart,
          topFiveTasks: heroState.topFiveTasks,
          multitaskItems: heroState.multitaskItems,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TodayPlannerScreen(
                  date: selectedDateStr,
                ),
              ),
            );
          },
          onPlayPause: () {
            final nextSub = heroState.nextSubTask;
            final nextMain = heroState.nextMainTask;
            if (nextSub == null || nextMain == null) return;
            if (heroState.isRunning) {
              provider.pauseTimer(nextSub.id);
              provider.logTimerAndReset(nextSub.id);
            } else {
              provider.startTimer(nextSub.id, 'subtask', nextMain.id);
            }
          },
          onFinishCheckpoint: () {
            final nextQ = heroState.nextQueueId;
            final nextCp = heroState.nextCheckpoint;
            final nextMain = heroState.nextMainTask;
            final nextSub = heroState.nextSubTask;
            if (nextQ != null && nextCp != null && nextMain != null && nextSub != null) {
              provider.taskActions.completeSubSubtask(nextMain.id, nextSub.id, nextCp.id);
              final parts = nextQ.split('|');
              if (parts.length == 3) {
                final newPlan = List<String>.from(plan)..remove(nextQ);
                provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
              } else {
                final remainingNext = TaskCalculations.nextCheckpoint(nextSub);
                if (remainingNext == null) {
                  final newPlan = List<String>.from(plan)..remove(nextQ);
                  provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
                }
              }
            }
          },
          onFinishSubTask: () {
            final nextQ = heroState.nextQueueId;
            final nextMain = heroState.nextMainTask;
            final nextSub = heroState.nextSubTask;
            if (nextQ != null && nextMain != null && nextSub != null) {
              provider.taskActions.completeSubtask(nextMain.id, nextSub.id);
              final newPlan = List<String>.from(plan)..remove(nextQ);
              provider.taskActions.updateDayPlan(selectedDateStr, newPlan);
            }
          },
          onTitleTap: () {
            final m = heroState.nextMainTask;
            final s = heroState.nextSubTask;
            final cp = heroState.nextCheckpoint;
            if (m != null && s != null) {
              if (cp != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckpointDetailScreen(
                      mainTaskId: m.id,
                      parentSubTaskId: s.id,
                      checkpointId: cp.id,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmissionDetailScreen(
                      parentTask: m,
                      subTask: s,
                    ),
                  ),
                );
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
              ScheduleControlIcon(
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
              ScheduleControlIcon(
                icon: Icons.chevron_right,
                onTap: () => _shiftDate(1),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final activeOverlay = provider.scheduleActions.getPredictedEntriesForDate(_selectedDate);
                  final hasOverlay = activeOverlay.isNotEmpty || _predictedEntries.isNotEmpty;
                  return ScheduleControlIcon(
                    icon: _isPredicting ? null : MdiIcons.crystalBall,
                    loading: _isPredicting,
                    accent: hasOverlay ? JweTheme.accentAmber : JweTheme.accentCyan,
                    tooltip: 'PREDICT & BLUEPRINT (Tap: Options | Long-Click: External AI)',
                    onTap: _isPredicting ? null : () => _showPredictOptions(context, provider),
                    onLongPress: _isPredicting ? null : () => _openExternalAiSchedule(context),
                  );
                },
              ),
              const SizedBox(width: 6),
              ScheduleControlIcon(
                icon: MdiIcons.console,
                accent: JweTheme.accentAmber,
                tooltip: 'PROTOCOLS',
                onTap: () => _openProtocolControl(provider),
              ),
            ],
          ),
        ),
      ],
    );

    Widget timelineWidget = ScheduleTimeline(
      entries: entries,
      selectedDate: _selectedDate,
      onRangeCreated: (start, end) => _showTaskSelectorAndAdd(provider, start, end),
      onUpdateEntryTimeRange: (entry, newStart, newEnd) => _handleUpdateEntryTimeRange(provider, entry, newStart, newEnd),
      onAddSession: () => _handleAddSession(provider),
      onEditEntry: (entry) => _handleEditEntry(provider, entry),
      onDeleteEntry: (entry) => _handleDeleteEntry(provider, entry),
      onSwitchTask: (entry) => _handleSwitchTask(provider, entry),
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
