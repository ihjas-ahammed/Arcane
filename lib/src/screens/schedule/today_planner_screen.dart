import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/global_toast.dart';

/// One slot in the day plan. The same compound id may appear more than once
/// (planning several sessions of the same work), so each slot carries its own
/// stable [key] for list identity and animations.
class _PlanCheckpoint {
  final String id;
  String name;
  bool completed;
  int durationMinutes;

  _PlanCheckpoint({
    required this.id,
    required this.name,
    this.completed = false,
    this.durationMinutes = 15,
  });

  _PlanCheckpoint clone({String? newId}) => _PlanCheckpoint(
    id: newId ?? const Uuid().v4(),
    name: name,
    completed: completed,
    durationMinutes: durationMinutes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'completed': completed,
    'durationMinutes': durationMinutes,
  };

  factory _PlanCheckpoint.fromJson(Map<String, dynamic> json) => _PlanCheckpoint(
    id: json['id'] as String? ?? const Uuid().v4(),
    name: json['name'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 15,
  );
}

/// One slot in the day plan. The same compound id may appear more than once
/// (planning several sessions of the same work), so each slot carries its own
/// stable [key] for list identity and animations.
class _PlanEntry {
  static int _seq = 0;
  final String key;
  final String id;
  final bool addedAtRuntime;
  List<_PlanCheckpoint> checkpoints;

  _PlanEntry(
    this.id, {
    this.addedAtRuntime = false,
    String? key,
    List<_PlanCheckpoint>? checkpoints,
  })  : key = key ?? 'plan-entry-${_seq++}',
        checkpoints = checkpoints ?? [];

  _PlanEntry clone() {
    return _PlanEntry(
      id,
      addedAtRuntime: true,
      checkpoints: checkpoints.map((c) => c.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'id': id,
    'addedAtRuntime': addedAtRuntime,
    'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
  };

  factory _PlanEntry.fromJson(Map<String, dynamic> json) => _PlanEntry(
    json['id'] as String? ?? '',
    addedAtRuntime: json['addedAtRuntime'] as bool? ?? false,
    key: json['key'] as String?,
    checkpoints: (json['checkpoints'] as List?)
        ?.whereType<Map>()
        .map((m) => _PlanCheckpoint.fromJson(Map<String, dynamic>.from(m)))
        .toList() ??
        [],
  );
}

/// A row in the multi-planner holding 1, 2, or 3 plans for multitasking.
class _PlanRowData {
  static int _rowSeq = 0;
  final String key;
  final List<_PlanEntry> entries;

  _PlanRowData(this.entries, {String? key})
      : key = key ?? 'plan-row-${_rowSeq++}';

  int get count => entries.length.clamp(1, 3);
}

class _PlanEntryDragData {
  final _PlanEntry entry;
  final int sourceRowIndex;
  _PlanEntryDragData({required this.entry, required this.sourceRowIndex});
}

enum _LeaveKind { removed, completed }

class TodayPlannerScreen extends StatefulWidget {
  final String? date;
  const TodayPlannerScreen({super.key, this.date});

  @override
  State<TodayPlannerScreen> createState() => _TodayPlannerScreenState();
}

class _TodayPlannerScreenState extends State<TodayPlannerScreen> {
  late String _date;
  List<_PlanRowData> _rows = [];
  List<_PlanEntry> get _entries => _rows.expand((r) => r.entries).toList();
  Map<String, int> _estimates = {};
  final Map<String, _LeaveKind> _leaving = {};
  bool _addExpanded = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isInit = true;
  int _activeAddTab = 0; // 0 for Missions, 1 for Routines
  int? _multitaskTargetRowIndex;

  final ScrollController _planScrollController = ScrollController();
  final GlobalKey _planListKey = GlobalKey();
  bool _isDraggingPlan = false;
  Timer? _autoScrollTimer;
  double _autoScrollVelocity = 0.0;
  final Set<String> _expandedCheckpointEntries = {};

  void _startAutoScroll(double velocity) {
    _autoScrollVelocity = velocity;
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_planScrollController.hasClients) return;
      final maxScroll = _planScrollController.position.maxScrollExtent;
      final current = _planScrollController.offset;
      final target = (current + _autoScrollVelocity).clamp(0.0, maxScroll);
      if ((target - current).abs() > 0.1) {
        _planScrollController.jumpTo(target);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollVelocity = 0.0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDraggingPlan) return;
    final renderBox = _planListKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localPos = renderBox.globalToLocal(event.position);
    final height = renderBox.size.height;
    const edgeThreshold = 90.0;
    const maxSpeed = 15.0;

    if (localPos.dy < edgeThreshold && localPos.dy >= -40) {
      final factor = ((edgeThreshold - localPos.dy.clamp(0.0, edgeThreshold)) / edgeThreshold).clamp(0.1, 1.0);
      _startAutoScroll(-maxSpeed * factor);
    } else if (localPos.dy > height - edgeThreshold && localPos.dy <= height + 40) {
      final factor = (((localPos.dy - (height - edgeThreshold)).clamp(0.0, edgeThreshold)) / edgeThreshold).clamp(0.1, 1.0);
      _startAutoScroll(maxSpeed * factor);
    } else {
      _stopAutoScroll();
    }
  }

  void _onPlanDragStarted() {
    setState(() {
      _isDraggingPlan = true;
    });
  }

  void _onPlanDragEnded() {
    _stopAutoScroll();
    if (_isDraggingPlan) {
      setState(() {
        _isDraggingPlan = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _date = widget.date ?? helper.getTodayDateString();
      final provider = Provider.of<AppProvider>(context, listen: false);
      final savedRowEntries = provider.taskActions.getDayPlanRowEntries(_date);
      if (savedRowEntries.isNotEmpty) {
        _rows = savedRowEntries
            .map((row) => _PlanRowData(row.map(_PlanEntry.fromJson).toList()))
            .toList();
      } else {
        final rowLists = provider.taskActions.getDayPlanRows(_date);
        _rows = rowLists.map((row) {
          return _PlanRowData(row.map((id) {
            final entry = _PlanEntry(id);
            final parts = id.split('|');
            if (parts.length >= 2) {
              final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
              final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
              if (sub != null && sub.subSubTasks.isNotEmpty) {
                entry.checkpoints = sub.getCheckpointsAtDepth().map((sst) => _PlanCheckpoint(
                  id: const Uuid().v4(),
                  name: sst.name,
                  completed: false,
                  durationMinutes: sst.timeSpentMinutes > 0 ? sst.timeSpentMinutes : 15,
                )).toList();
              }
            }
            return entry;
          }).toList());
        }).toList();
      }
      _estimates = provider.taskActions.getDayPlanEstimates(_date);
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _planScrollController.dispose();
    _stopAutoScroll();
    super.dispose();
  }

  void _persistPlan(AppProvider provider) {
    provider.taskActions.saveDayPlanRowEntries(
      _date,
      _rows.map((r) => r.entries.map((e) => e.toJson()).toList()).toList(),
    );
  }

  void _setEstimate(AppProvider provider, String compoundId, int minutes) {
    setState(() {
      if (minutes <= 0) {
        _estimates.remove(compoundId);
      } else {
        _estimates[compoundId] = minutes;
      }
    });
    provider.taskActions.setDayPlanEstimate(_date, compoundId, minutes);
  }

  int _estimateFor(String compoundId, AppProvider provider) {
    if (_estimates.containsKey(compoundId)) return _estimates[compoundId]!;
    final parts = compoundId.split('|');
    if (parts.length < 2) return TaskCalculations.defaultSubtaskMinutes;
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (sub == null) return TaskCalculations.defaultSubtaskMinutes;

    final median = TaskCalculations.medianSessionMinutes(sub);
    final subtaskEstimate = median ?? TaskCalculations.defaultSubtaskMinutes;

    if (parts.length == 3) {
      final activeCps = _getAllCheckpointsForPlanning(sub);
      if (activeCps.isNotEmpty) {
        return (subtaskEstimate / activeCps.length).round().clamp(1, 600);
      }
      return TaskCalculations.defaultCheckpointMinutes;
    }

    return subtaskEstimate;
  }

  /// True when the entry's target is already completed (kept in the plan as a
  /// dimmed "done" row until the user removes it — never auto-removed).
  bool _isEntryDone(AppProvider provider, String compoundId) {
    final parts = compoundId.split('|');
    if (parts.length < 2) return false;
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null) return false;
    if (_date != helper.getTodayDateString() && sub.isRecurring) {
      return false;
    }
    if (parts.length == 3) {
      return sub.findCheckpoint(parts[2])?.completed ?? false;
    }
    return sub.completed;
  }

  void _addToPlan(AppProvider provider, String compoundId, [int? targetRowIdx]) {
    final target = targetRowIdx ?? _multitaskTargetRowIndex;
    final newEntry = _PlanEntry(compoundId, addedAtRuntime: true);
    final parts = compoundId.split('|');
    if (parts.length >= 2) {
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
      if (sub != null && sub.subSubTasks.isNotEmpty) {
        newEntry.checkpoints = sub.getCheckpointsAtDepth().map((sst) => _PlanCheckpoint(
          id: const Uuid().v4(),
          name: sst.name,
          completed: false,
          durationMinutes: sst.timeSpentMinutes > 0 ? sst.timeSpentMinutes : 15,
        )).toList();
      }
    }

    setState(() {
      if (target != null && target >= 0 && target < _rows.length && _rows[target].entries.length < 3) {
        _rows[target].entries.add(newEntry);
      } else {
        _rows.add(_PlanRowData([newEntry]));
      }
      _multitaskTargetRowIndex = null;
    });
    _persistPlan(provider);
  }

  void _duplicatePlanItem(AppProvider provider, _PlanEntry entry, int rowIndex) {
    final cloned = entry.clone();
    setState(() {
      if (_rows[rowIndex].entries.length < 3) {
        _rows[rowIndex].entries.add(cloned);
      } else {
        _rows.insert(rowIndex + 1, _PlanRowData([cloned]));
      }
    });
    _persistPlan(provider);
    showGlobalToast('Mission duplicated with independent checkpoints');
  }

  void _toggleCheckpoint(AppProvider provider, _PlanEntry entry, _PlanCheckpoint checkpoint) {
    setState(() {
      checkpoint.completed = !checkpoint.completed;
    });
    _persistPlan(provider);
  }

  void _removeCheckpoint(AppProvider provider, _PlanEntry entry, _PlanCheckpoint checkpoint) {
    setState(() {
      entry.checkpoints.removeWhere((c) => c.id == checkpoint.id);
    });
    _persistPlan(provider);
  }

  void _addCheckpoint(AppProvider provider, _PlanEntry entry, String name, int duration) {
    setState(() {
      entry.checkpoints.add(_PlanCheckpoint(
        id: const Uuid().v4(),
        name: name,
        completed: false,
        durationMinutes: duration,
      ));
    });
    _persistPlan(provider);
  }

  void _startLeave(_PlanEntry entry, _LeaveKind kind) {
    if (_leaving.containsKey(entry.key)) return;
    setState(() => _leaving[entry.key] = kind);
  }

  /// Called once the leave animation finished: actually drop the entry.
  void _finishLeave(AppProvider provider, _PlanEntry entry) {
    if (!mounted) return;
    setState(() {
      for (final row in _rows) {
        row.entries.removeWhere((e) => e.key == entry.key);
      }
      _rows.removeWhere((r) => r.entries.isEmpty);
      _leaving.remove(entry.key);
    });
    _persistPlan(provider);
  }

  void _removeFromPlan(AppProvider provider, _PlanEntry entry) {
    _startLeave(entry, _LeaveKind.removed);
  }

  void _completePlanItem(AppProvider provider, _PlanEntry entry) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return;
    final mainTaskId = parts[0];
    final subTaskId = parts[1];
    if (parts.length == 3) {
      provider.taskActions.completeSubSubtask(mainTaskId, subTaskId, parts[2]);
      showGlobalToast('✓ Checked: checkpoint completed');
    } else {
      final ok = provider.taskActions.completeSubtask(mainTaskId, subTaskId);
      if (!ok) {
        showGlobalToast('Can\'t complete yet — checkpoints, count or time still pending');
        return;
      }
      showGlobalToast('✓ Completed: subtask completed');
    }
    _startLeave(entry, _LeaveKind.completed);
  }



  Future<void> _editEstimate(AppProvider provider, String compoundId) async {
    final current = _estimateFor(compoundId, provider);
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.fhBgDark,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text('ESTIMATE',
              style: GoogleFonts.rajdhani(
                  color: AppTheme.fhAccentTeal,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [5, 15, 30, 60, 90].map((preset) {
                  return ChoiceChip(
                    label: Text('${preset}m'),
                    selected: false,
                    backgroundColor: AppTheme.fhBgDeepDark,
                    labelStyle:   TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    onSelected: (_) => Navigator.pop(ctx, preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style:   TextStyle(color: AppTheme.fhTextPrimary),
                decoration:   InputDecoration(
                  labelText: 'Minutes',
                  labelStyle: TextStyle(color: AppTheme.fhTextSecondary),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:   Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary))),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? current;
                Navigator.pop(ctx, v.clamp(0, 600));
              },
              child:   Text('SET', style: TextStyle(color: AppTheme.fhAccentTeal)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) {
      _setEstimate(provider, compoundId, result);
    }
  }

  Future<void> _editReminder(AppProvider provider, String compoundId) async {
    final existing = provider.plannerReminderTime(compoundId);
    if (existing != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.fhBgDark,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text('REMINDER',
              style: GoogleFonts.rajdhani(
                  color: AppTheme.fhAccentTeal,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          content: Text(
            'Set for ${DateFormat('MMM d · hh:mm a').format(existing)}.',
            style:   TextStyle(color: AppTheme.fhTextSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'clear'),
                child:   Text('CLEAR',
                    style: TextStyle(color: AppTheme.fhAccentRed))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'change'),
                child:   Text('CHANGE',
                    style: TextStyle(color: AppTheme.fhAccentTeal))),
          ],
        ),
      );
      if (action == 'clear') {
        await provider.setPlannerReminder(compoundId, null);
        return;
      }
      if (action != 'change') return;
    }

    if (!mounted) return;

    final parts = compoundId.split('|');
    SubTask? sub;
    if (parts.length >= 2) {
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
      sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    }
    final isRecurring = sub?.isRecurring ?? false;

    final base = existing ?? DateTime.now().add(const Duration(hours: 1));
    DateTime date;
    if (isRecurring) {
      date = DateTime.now();
    } else {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: base,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (pickedDate == null || !mounted) return;
      date = pickedDate;
    }
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    var when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isRecurring && when.isBefore(DateTime.now())) {
      when = when.add(const Duration(days: 1));
    }
    await provider.setPlannerReminder(compoundId, when);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reminder set for ${DateFormat('MMM d · hh:mm a').format(when)}'),
      backgroundColor: AppTheme.fhAccentTeal.withValues(alpha: 0.9),
    ));
  }

  ({String? title, Color? color, bool isRunning}) _resolveActive(AppProvider provider) {
    for (final entry in _entries) {
      final parts = entry.id.split('|');
      if (parts.length < 2) continue;
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (task == null || sub == null || sub.completed) continue;
      String? title;
      if (parts.length == 3) {
        final cp = sub.findCheckpoint(parts[2]);
        if (cp == null || cp.completed) continue;
        title = cp.name;
      } else {
        title = sub.name;
      }
      final running = provider.activeTimers[sub.id]?.isRunning ?? false;
      return (title: title, color: task.taskColor, isRunning: running);
    }
    return (title: null, color: null, isRunning: false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final now = DateTime.now();
    final window = resolveDayWindow(provider, now);
    final minutesLeft = window.minutesRemaining(now);
    final realisticMinutes = window.realisticMinutes(now);

    int plannedMinutes = 0;
    for (final entry in _entries) {
      final est = _estimateFor(entry.id, provider);
      if (!_isEntryDone(provider, entry.id)) {
        plannedMinutes += est;
      }
    }
    final active = _resolveActive(provider);

    return Scaffold(
      backgroundColor: JweTheme.isLight ? JweTheme.bgCanvas : const Color(0xFF05080C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: JweTheme.textMid),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Text(
              _date == helper.getTodayDateString()
                  ? 'TODAY'
                  : DateFormat('dd MMM yyyy').format(DateTime.parse(_date)).toUpperCase(),
              style: GoogleFonts.teko(
                fontSize: 32,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
                color: JweTheme.textWhite,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 16, height: 2, color: JweTheme.accentRed),
          ],
        ),
        actions: [
          Center(
            child: InkWell(
              onTap: () => setState(() {
                _multitaskTargetRowIndex = null;
                _addExpanded = true;
              }),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.12 : 0.1),
                  border: Border.all(color: JweTheme.accentCyan, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: JweTheme.accentCyan),
                    const SizedBox(width: 4),
                    Text(
                      'ADD',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 12),
            child: Text.rich(
              TextSpan(
                text: 'DISCIPLINE\nBUILDS\nFREEDOM ',
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textMuted,
                  fontSize: 8,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                children: [
                  TextSpan(text: '—', style: TextStyle(color: JweTheme.accentRed)),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.85,
                child: const CustomPaint(
                  painter: _TacticalBackgroundPainter(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
            // Time & Progress Overview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatMinutes(plannedMinutes),
                            style: GoogleFonts.teko(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: JweTheme.textWhite,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PLANNED / ${realisticMinutes > 0 ? formatMinutes(realisticMinutes) : '0m'} USABLE',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: JweTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '${minutesLeft}m LEFT ',
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: JweTheme.textMid,
                            ),
                          ),
                          Icon(Icons.nightlight_round, size: 14, color: JweTheme.textMid),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: JweTheme.isLight ? JweTheme.border : const Color(0xFF111D28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: realisticMinutes > 0
                          ? (plannedMinutes / realisticMinutes).clamp(0.02, 1.0)
                          : 0.88,
                      child: Container(
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(color: JweTheme.accentCyan.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Up Next Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 7, height: 7, color: JweTheme.accentRed),
                      const SizedBox(width: 8),
                      Text(
                        'UP NEXT',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: JweTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    (active.title ?? 'NONE').toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: JweTheme.textWhite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildPlanList(provider)),
            _AddSection(
              expanded: _addExpanded,
              onToggle: () => setState(() => _addExpanded = !_addExpanded),
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              activeTab: _activeAddTab,
              onTabChanged: (val) => setState(() => _activeAddTab = val),
              child: _activeAddTab == 0
                  ? _buildAvailableList(provider)
                  : _buildRoutinesList(provider),
            ),
          ],
        ),
      ),
    ],
  ),
  );
  }

  Widget _buildPlanList(AppProvider provider) {
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.formatListBulletedSquare, size: 48, color: const Color(0xFF62778D)),
            const SizedBox(height: 12),
            Text(
              'NOTHING PLANNED',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFF62778D),
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('Queue the work that matters today.', style: GoogleFonts.rajdhani(color: const Color(0xFF62778D), fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _addExpanded = true),
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF00F0FF)),
              label: Text(
                'ADD MISSIONS',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF00F0FF),
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00F0FF)),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      );
    }

    return Listener(
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _onPlanDragEnded(),
      onPointerCancel: (_) => _onPlanDragEnded(),
      child: ListView.builder(
        key: _planListKey,
        controller: _planScrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _rows.length * 2 + 2,
        itemBuilder: (context, index) {
          if (index == _rows.length * 2 + 1) {
            return const _TacticalFooter();
          }

          if (index.isEven) {
            final dividerIdx = index ~/ 2;
            return _buildDropDivider(provider, dividerIdx);
          } else {
            final rowIdx = index ~/ 2;
            return _buildTaskRow(provider, _rows[rowIdx], rowIdx);
          }
        },
      ),
    );
  }

  Widget _buildAvailableList(AppProvider provider) {
    final plannedCounts = <String, int>{};
    for (final entry in _entries) {
      plannedCounts[entry.id] = (plannedCounts[entry.id] ?? 0) + 1;
    }
    final widgets = _buildSelectableTree(
      provider: provider,
      query: _searchQuery,
      isSelectionMode: false,
      selectedIds: const {},
      onToggleSelection: (_, __) {},
      plannedCounts: plannedCounts,
      onAdd: (id) => _addToPlan(provider, id),
    );

    if (widgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchQuery.isEmpty ? 'No available items.' : 'No matches for "$_searchQuery".',
            style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: widgets,
    );
  }

  bool _matchesQuery(String text, String q) {
    if (q.isEmpty) return true;
    return text.toLowerCase().contains(q);
  }

  Widget _buildRoutinesList(AppProvider provider) {
    final allRoutines = provider.routineLists;
    if (allRoutines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NO ROUTINES CREATED YET',
              style: GoogleFonts.rajdhani(
                  color: AppTheme.fhTextDisabled,
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showCreateRoutineDialog(provider),
              icon: Icon(MdiIcons.plusBoxOutline, size: 16, color: AppTheme.fhAccentTeal),
              label: Text('CREATE ROUTINE',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    final q = _searchQuery.trim().toLowerCase();
    final routines = allRoutines.where((r) {
      if (q.isEmpty) return true;
      if (_matchesQuery(r.name, q)) return true;
      for (final compoundId in r.taskIds) {
        final details = _resolveRoutineItemDetails(provider, compoundId);
        if (_matchesQuery(details.title, q) ||
            _matchesQuery(details.parentPath, q)) {
          return true;
        }
      }
      return false;
    }).toList();

    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No routine matches for "$_searchQuery".',
            style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateRoutineDialog(provider),
              icon: Icon(MdiIcons.plusBoxOutline, size: 14, color: AppTheme.fhAccentTeal),
              label: Text('CREATE ROUTINE',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: routines.length,
            itemBuilder: (context, idx) {
              final routine = routines[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDeepDark,
                  border: Border.all(color: AppTheme.fhBorderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${routine.taskIds.length} items',
                            style: TextStyle(
                              color: AppTheme.fhTextDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _addRoutineToPlan(provider, routine);
                        showGlobalToast('Added "${routine.name}" routine to plan');
                      },
                      child: Text('ADD ALL',
                          style: TextStyle(
                              color: AppTheme.fhAccentTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 16, color: AppTheme.fhTextSecondary),
                      onPressed: () => _showCreateRoutineDialog(provider, routine),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 16, color: AppTheme.fhAccentRed),
                      onPressed: () => _confirmDeleteRoutine(provider, routine),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addRoutineToPlan(AppProvider provider, RoutineList routine) {
    setState(() {
      for (final compoundId in routine.taskIds) {
        _rows.add(_PlanRowData([_PlanEntry(compoundId, addedAtRuntime: true)]));
      }
    });
    _persistPlan(provider);
  }

  void _confirmDeleteRoutine(AppProvider provider, RoutineList routine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('DELETE ROUTINE',
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhAccentRed,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete the routine "${routine.name}"?',
          style: TextStyle(color: AppTheme.fhTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              provider.taskActions.deleteRoutineList(routine.id);
              Navigator.pop(ctx);
              showGlobalToast('Deleted routine: ${routine.name}');
            },
            child: Text('DELETE', style: TextStyle(color: AppTheme.fhAccentRed)),
          ),
        ],
      ),
    );
  }

  void _showCreateRoutineDialog(AppProvider provider, [RoutineList? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final selectedIdsList = List<String>.from(existing?.taskIds ?? <String>[]);
    final selectedIdsSet = selectedIdsList.toSet();
    String dialogSearchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, dialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.fhBgDark,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(existing == null ? 'CREATE ROUTINE' : 'EDIT ROUTINE',
                  style: GoogleFonts.rajdhani(
                      color: AppTheme.fhAccentTeal,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: AppTheme.fhTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'Routine Name',
                        labelStyle: TextStyle(color: AppTheme.fhTextSecondary),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ROUTINE ORDER (DRAG TO REARRANGE):',
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (selectedIdsList.isEmpty)
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.fhBorderColor),
                          color: AppTheme.fhBgDeepDark,
                        ),
                        child: Text(
                          'No items selected yet. Use the selector below.',
                          style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 11),
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.fhBorderColor),
                          color: AppTheme.fhBgDeepDark,
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          itemCount: selectedIdsList.length,
                          onReorder: (oldIndex, newIndex) {
                            dialogState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = selectedIdsList.removeAt(oldIndex);
                              selectedIdsList.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, idx) {
                            final compoundId = selectedIdsList[idx];
                            final itemDetails = _resolveRoutineItemDetails(provider, compoundId);
                            return Container(
                              key: ValueKey('selected_$compoundId'),
                              margin: const EdgeInsets.only(bottom: 2),
                              color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                title: Text(
                                  itemDetails.title,
                                  style: TextStyle(
                                      color: AppTheme.fhTextPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  itemDetails.parentPath,
                                  style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10),
                                ),
                                leading: Icon(
                                  Icons.drag_handle,
                                  size: 16,
                                  color: AppTheme.fhTextSecondary,
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, size: 14, color: AppTheme.fhAccentRed),
                                  onPressed: () {
                                    dialogState(() {
                                      selectedIdsList.removeAt(idx);
                                      selectedIdsSet.remove(compoundId);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'ADD / REMOVE ITEMS:',
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.fhBorderColor),
                        color: AppTheme.fhBgDark,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: TextField(
                              onChanged: (v) {
                                dialogState(() {
                                  dialogSearchQuery = v;
                                });
                              },
                              style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search tasks...',
                                hintStyle: TextStyle(color: AppTheme.fhTextDisabled),
                                prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.fhTextSecondary),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: AppTheme.fhBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: AppTheme.fhAccentTeal),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              children: _buildSelectableTree(
                                provider: provider,
                                query: dialogSearchQuery,
                                isSelectionMode: true,
                                selectedIds: selectedIdsSet,
                                onToggleSelection: (id, isSelected) {
                                  dialogState(() {
                                    if (isSelected) {
                                      selectedIdsSet.add(id);
                                      if (!selectedIdsList.contains(id)) {
                                        selectedIdsList.add(id);
                                      }
                                    } else {
                                      selectedIdsSet.remove(id);
                                      selectedIdsList.remove(id);
                                    }
                                  });
                                },
                                plannedCounts: const {},
                                onAdd: (_) {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      showGlobalToast('Please enter a routine name');
                      return;
                    }
                    if (selectedIdsList.isEmpty) {
                      showGlobalToast('Please select at least one task');
                      return;
                    }

                    final routine = RoutineList(
                      id: existing?.id ?? const Uuid().v4(),
                      name: name,
                      taskIds: selectedIdsList,
                    );
                    provider.taskActions.addOrUpdateRoutineList(routine);
                    Navigator.pop(ctx);
                    showGlobalToast(existing == null ? 'Created routine: $name' : 'Updated routine: $name');
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE', style: TextStyle(color: AppTheme.fhAccentTeal)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSelectableTree({
    required AppProvider provider,
    required String query,
    required bool isSelectionMode,
    required Set<String> selectedIds,
    required void Function(String compoundId, bool selected) onToggleSelection,
    required Map<String, int> plannedCounts,
    required void Function(String compoundId) onAdd,
  }) {
    final List<Widget> widgets = [];
    final activeTasks = provider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
    final q = query.trim().toLowerCase();

    for (final task in activeTasks) {
      final bool taskMatches = q.isEmpty || task.name.toLowerCase().contains(q);

      final activeSubs = task.subTasks.where((s) {
        if (s.isDeleted) return false;
        if (s.completed && !s.isRecurring) return false;
        return true;
      }).toList();

      if (activeSubs.isEmpty) continue;

      final List<Widget> subGroups = [];
      int taskCount = 0;

      for (final sub in activeSubs) {
        final subId = '${task.id}|${sub.id}';
        final bool subMatches = taskMatches || q.isEmpty || sub.name.toLowerCase().contains(q);
        final bool subOrCpMatch = subMatches || _subTaskHasMatchingCheckpoints(sub, q);
        if (!subOrCpMatch) continue;

        final List<Widget> cpWidgets = _buildCheckpointTreeWidgets(
          provider: provider,
          subId: subId,
          taskColor: task.taskColor,
          substeps: sub.subSubTasks,
          query: q,
          parentMatched: subMatches,
          isSelectionMode: isSelectionMode,
          selectedIds: selectedIds,
          onToggleSelection: onToggleSelection,
          plannedCounts: plannedCounts,
          onAdd: onAdd,
          level: 2,
        );

        int subCount = 0;
        if (isSelectionMode) {
          if (selectedIds.contains(subId)) {
            subCount += 1;
          }
          subCount += _countSelectedCheckpoints(sub.subSubTasks, subId, selectedIds);
        } else {
          subCount += plannedCounts[subId] ?? 0;
          subCount += _sumPlannedCheckpoints(sub.subSubTasks, subId, plannedCounts);
        }

        taskCount += subCount;

        subGroups.add(_CollapsibleGroup(
          key: ValueKey('sub_${sub.id}_${q.isEmpty ? 0 : 1}'),
          title: sub.name,
          color: task.taskColor,
          level: 1,
          queuedCount: subCount,
          initiallyExpanded: q.isNotEmpty,
          children: [
            _AvailableRow(
              title: isSelectionMode ? 'Select whole subtask' : 'Add whole subtask',
              color: task.taskColor,
              isCheckpoint: false,
              plannedCount: isSelectionMode ? 0 : (plannedCounts[subId] ?? 0),
              isSelectionMode: isSelectionMode,
              isSelected: isSelectionMode ? selectedIds.contains(subId) : false,
              onSelectedChanged: isSelectionMode
                  ? (val) => onToggleSelection(subId, val == true)
                  : null,
              onAdd: isSelectionMode ? () {} : () => onAdd(subId),
            ),
            ...cpWidgets,
          ],
        ));
      }

      if (subGroups.isNotEmpty) {
        widgets.add(_CollapsibleGroup(
          key: ValueKey('task_${task.id}_${q.isEmpty ? 0 : 1}'),
          title: task.name,
          color: task.taskColor,
          level: 0,
          queuedCount: taskCount,
          initiallyExpanded: q.isNotEmpty,
          children: subGroups,
        ));
      }
    }

    return widgets;
  }

  bool _subTaskHasMatchingCheckpoints(SubTask sub, String q) {
    if (q.isEmpty) return true;
    for (final cp in sub.subSubTasks) {
      if (_checkpointOrDescendantsMatch(cp, q)) return true;
    }
    return false;
  }

  bool _checkpointOrDescendantsMatch(SubSubTask cp, String q) {
    if (q.isEmpty) return true;
    if (cp.name.toLowerCase().contains(q)) return true;
    for (final sub in cp.substeps) {
      if (_checkpointOrDescendantsMatch(sub, q)) return true;
    }
    return false;
  }

  int _countSelectedCheckpoints(List<SubSubTask> list, String subId, Set<String> selectedIds) {
    int count = 0;
    for (final cp in list) {
      final cpId = '$subId|${cp.id}';
      if (selectedIds.contains(cpId)) {
        count += 1;
      }
      count += _countSelectedCheckpoints(cp.substeps, subId, selectedIds);
    }
    return count;
  }

  int _sumPlannedCheckpoints(List<SubSubTask> list, String subId, Map<String, int> plannedCounts) {
    int sum = 0;
    for (final cp in list) {
      final cpId = '$subId|${cp.id}';
      sum += plannedCounts[cpId] ?? 0;
      sum += _sumPlannedCheckpoints(cp.substeps, subId, plannedCounts);
    }
    return sum;
  }

  List<Widget> _buildCheckpointTreeWidgets({
    required AppProvider provider,
    required String subId,
    required Color taskColor,
    required List<SubSubTask> substeps,
    required String query,
    required bool parentMatched,
    required bool isSelectionMode,
    required Set<String> selectedIds,
    required void Function(String compoundId, bool selected) onToggleSelection,
    required Map<String, int> plannedCounts,
    required void Function(String compoundId) onAdd,
    required int level,
  }) {
    final List<Widget> widgets = [];
    final q = query.trim().toLowerCase();

    for (final cp in substeps) {
      final parts = subId.split('|');
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
      final isRecurring = sub?.isRecurring ?? false;

      if (cp.completed && !isRecurring) continue;

      final bool cpMatched = parentMatched || q.isEmpty || cp.name.toLowerCase().contains(q);
      final bool cpOrDescendantMatch = cpMatched || _checkpointOrDescendantsMatch(cp, q);
      if (!cpOrDescendantMatch) continue;

      final cpId = '$subId|${cp.id}';

      if (cp.substeps.isEmpty) {
        widgets.add(_AvailableRow(
          title: cp.name,
          color: taskColor,
          isCheckpoint: true,
          plannedCount: isSelectionMode ? 0 : (plannedCounts[cpId] ?? 0),
          isSelectionMode: isSelectionMode,
          isSelected: isSelectionMode ? selectedIds.contains(cpId) : false,
          onSelectedChanged: isSelectionMode
              ? (val) => onToggleSelection(cpId, val == true)
              : null,
          onAdd: isSelectionMode ? () {} : () => onAdd(cpId),
        ));
      } else {
        final List<Widget> children = _buildCheckpointTreeWidgets(
          provider: provider,
          subId: subId,
          taskColor: taskColor,
          substeps: cp.substeps,
          query: query,
          parentMatched: cpMatched,
          isSelectionMode: isSelectionMode,
          selectedIds: selectedIds,
          onToggleSelection: onToggleSelection,
          plannedCounts: plannedCounts,
          onAdd: onAdd,
          level: level + 1,
        );

        int count = 0;
        if (isSelectionMode) {
          if (selectedIds.contains(cpId)) {
            count += 1;
          }
          count += _countSelectedCheckpoints(cp.substeps, subId, selectedIds);
        } else {
          count += plannedCounts[cpId] ?? 0;
          count += _sumPlannedCheckpoints(cp.substeps, subId, plannedCounts);
        }

        widgets.add(_CollapsibleGroup(
          key: ValueKey('cp_${cp.id}_${q.isEmpty ? 0 : 1}'),
          title: cp.name,
          color: taskColor,
          level: level,
          queuedCount: count,
          initiallyExpanded: q.isNotEmpty,
          children: [
            _AvailableRow(
              title: isSelectionMode ? 'Select "${cp.name}" itself' : 'Add "${cp.name}" itself',
              color: taskColor,
              isCheckpoint: true,
              plannedCount: isSelectionMode ? 0 : (plannedCounts[cpId] ?? 0),
              isSelectionMode: isSelectionMode,
              isSelected: isSelectionMode ? selectedIds.contains(cpId) : false,
              onSelectedChanged: isSelectionMode
                  ? (val) => onToggleSelection(cpId, val == true)
                  : null,
              onAdd: isSelectionMode ? () {} : () => onAdd(cpId),
            ),
            ...children,
          ],
        ));
      }
    }
    return widgets;
  }

  ResolvedRoutineItem _resolveRoutineItemDetails(AppProvider provider, String compoundId) {
    final parts = compoundId.split('|');
    if (parts.length < 2) {
      return ResolvedRoutineItem(title: 'Unknown Item', parentPath: '');
    }
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null) {
      return ResolvedRoutineItem(title: 'Deleted Item', parentPath: '');
    }

    if (parts.length == 3) {
      final cp = sub.findCheckpoint(parts[2]);
      if (cp == null) {
        return ResolvedRoutineItem(title: 'Deleted Checkpoint', parentPath: '${task.name} > ${sub.name}');
      }
      return ResolvedRoutineItem(
        title: cp.name,
        parentPath: '${task.name} > ${_findParentPath(sub, cp)}',
      );
    }

    return ResolvedRoutineItem(
      title: sub.name,
      parentPath: task.name,
    );
  }

  Widget _buildDropDivider(AppProvider provider, int dividerIdx) {
    return DragTarget<_PlanEntryDragData>(
      onWillAcceptWithDetails: (details) {
        final dragData = details.data;
        if (dragData.sourceRowIndex < 0 || dragData.sourceRowIndex >= _rows.length) return false;
        final sourceRow = _rows[dragData.sourceRowIndex];
        if (sourceRow.entries.length == 1) {
          if (dividerIdx == dragData.sourceRowIndex || dividerIdx == dragData.sourceRowIndex + 1) {
            return false;
          }
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        _onPlanDragEnded();
        final dragData = details.data;
        setState(() {
          final sourceRow = _rows[dragData.sourceRowIndex];
          sourceRow.entries.removeWhere((e) => e.key == dragData.entry.key);

          int insertIdx = dividerIdx;
          if (sourceRow.entries.isEmpty) {
            _rows.removeAt(dragData.sourceRowIndex);
            if (dragData.sourceRowIndex < dividerIdx) {
              insertIdx = (insertIdx - 1).clamp(0, _rows.length);
            }
          }
          insertIdx = insertIdx.clamp(0, _rows.length);
          _rows.insert(insertIdx, _PlanRowData([dragData.entry]));
        });
        _persistPlan(provider);
        showGlobalToast('Moved to new tactical row');
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: isHovered
              ? Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.12 : 0.18),
                    border: Border.all(color: JweTheme.accentCyan, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 10, color: JweTheme.accentCyan),
                      const SizedBox(width: 4),
                      Text(
                        'INSERT NEW ROW',
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildTaskRow(AppProvider provider, _PlanRowData rowData, int rowIndex) {
    Widget content;
    if (rowData.entries.length == 1) {
      content = _buildTacticalCard1(provider, rowData.entries[0], rowIndex, 0);
    } else if (rowData.entries.length == 2) {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildTacticalCard2(provider, rowData.entries[0], rowIndex, 0)),
            const SizedBox(width: 8),
            Expanded(child: _buildTacticalCard2(provider, rowData.entries[1], rowIndex, 1)),
          ],
        ),
      );
    } else {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildTacticalCard3(provider, rowData.entries[0], rowIndex, 0)),
            const SizedBox(width: 6),
            Expanded(child: _buildTacticalCard3(provider, rowData.entries[1], rowIndex, 1)),
            const SizedBox(width: 6),
            Expanded(child: _buildTacticalCard3(provider, rowData.entries[2], rowIndex, 2)),
          ],
        ),
      );
    }

    return DragTarget<_PlanEntryDragData>(
      onWillAcceptWithDetails: (details) {
        final dragData = details.data;
        if (dragData.sourceRowIndex == rowIndex) return false;
        if (rowData.entries.length >= 3) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        _onPlanDragEnded();
        final dragData = details.data;
        if (dragData.sourceRowIndex == rowIndex) {
          return;
        }
        if (rowData.entries.length >= 3) {
          showGlobalToast('TACTICAL OVERLOAD: Maximum 3 missions allowed per row!');
          return;
        }
        setState(() {
          final sourceRow = _rows[dragData.sourceRowIndex];
          sourceRow.entries.removeWhere((e) => e.key == dragData.entry.key);
          if (sourceRow.entries.isEmpty) {
            _rows.removeAt(dragData.sourceRowIndex);
          }
          rowData.entries.add(dragData.entry);
        });
        _persistPlan(provider);
        showGlobalToast('Multitasking linked');
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: isHovered
              ? BoxDecoration(
                  border: Border.all(color: JweTheme.accentCyan, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: JweTheme.accentCyan.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1),
                  ],
                )
              : null,
          child: content,
        );
      },
    );
  }

  Widget _buildTacticalCard1(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${_findParentPath(sub, cp!)}' : task.name;
    final minutes = _estimateFor(entry.id, provider);
    final isCustomEstimate = _estimates.containsKey(entry.id);
    final isDone = _isEntryDone(provider, entry.id);
    final hasReminder = provider.plannerReminderTime(entry.id) != null;
    final taskColor = task.taskColor;

    return _AnimatedEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const _Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: _TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                boxShadow: [
                  BoxShadow(
                    color: taskColor.withValues(alpha: JweTheme.isLight ? 0.08 : 0.05),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Draggable<_PlanEntryDragData>(
                        data: _PlanEntryDragData(entry: entry, sourceRowIndex: rowIndex),
                        onDragStarted: _onPlanDragStarted,
                        onDragEnd: (_) => _onPlanDragEnded(),
                        onDraggableCanceled: (_, __) => _onPlanDragEnded(),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                              border: Border.all(color: JweTheme.accentCyan),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: JweTheme.accentCyan.withValues(alpha: 0.4), blurRadius: 10),
                              ],
                            ),
                            child: Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(2, 6, 8, 6),
                            child: Icon(Icons.drag_indicator, size: 18, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(2, 6, 8, 6),
                          child: Icon(Icons.drag_indicator, size: 18, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                        ),
                      ),
                      // NO HERO ICON!
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _editEstimate(provider, entry.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate
                                  ? JweTheme.accentCyan
                                  : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate
                                  ? JweTheme.accentCyan
                                  : taskColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _removeFromPlan(provider, entry),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, color: JweTheme.textMuted, size: 16),
                        ),
                      ),
                      _buildCardMenuButton(
                        provider: provider,
                        entry: entry,
                        mainTaskId: task.id,
                        subTaskId: sub.id,
                        subTaskName: sub.name,
                        rowIndex: rowIndex,
                        isInMultiRow: false,
                      ),
                    ],
                  ),
                  if (!isCheckpoint)
                    _buildTacticalSubtasksPanel(provider, entry),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _editReminder(provider, entry.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Icon(
                                  hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                                  color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _completePlanItem(provider, entry),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Icon(
                              Icons.check,
                              color: isDone ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981)) : JweTheme.accentCyan,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalCard2(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${_findParentPath(sub, cp!)}' : task.name;
    final minutes = _estimateFor(entry.id, provider);
    final isCustomEstimate = _estimates.containsKey(entry.id);
    final isDone = _isEntryDone(provider, entry.id);
    final hasReminder = provider.plannerReminderTime(entry.id) != null;
    final taskColor = task.taskColor;
    final checkpoints = entry.checkpoints;
    final totalCps = checkpoints.length;
    final completedCps = checkpoints.where((c) => c.completed).length;

    return _AnimatedEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const _Chamfer4CornerClipper(chamfer: 6.0),
          child: CustomPaint(
            foregroundPainter: _TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 6.0,
              bracketSize: 8.0,
            ),
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Draggable<_PlanEntryDragData>(
                        data: _PlanEntryDragData(entry: entry, sourceRowIndex: rowIndex),
                        onDragStarted: _onPlanDragStarted,
                        onDragEnd: (_) => _onPlanDragEnded(),
                        onDraggableCanceled: (_, __) => _onPlanDragEnded(),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 170,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                              border: Border.all(color: JweTheme.accentCyan),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(1, 4, 6, 4),
                            child: Icon(Icons.drag_indicator, size: 14, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(1, 4, 6, 4),
                          child: Icon(Icons.drag_indicator, size: 14, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                        ),
                      ),
                      // NO HERO ICON!
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => _showSubtasksModal(provider, entry, sub.name),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 12,
                                    color: totalCps > 0 ? (JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8)) : JweTheme.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    totalCps > 0 ? '$completedCps/$totalCps' : '0/0',
                                    style: GoogleFonts.rajdhani(
                                      color: totalCps > 0 ? (JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8)) : JweTheme.textMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: () => _editEstimate(provider, entry.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _editReminder(provider, entry.id),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                                color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                                size: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _completePlanItem(provider, entry),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.check,
                                color: isDone ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981)) : JweTheme.accentCyan,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _removeFromPlan(provider, entry),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.close, color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B), size: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildCardMenuButton(
                            provider: provider,
                            entry: entry,
                            mainTaskId: task.id,
                            subTaskId: sub.id,
                            subTaskName: sub.name,
                            rowIndex: rowIndex,
                            isInMultiRow: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalCard3(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${_findParentPath(sub, cp!)}' : task.name;
    final minutes = _estimateFor(entry.id, provider);
    final isCustomEstimate = _estimates.containsKey(entry.id);
    final isDone = _isEntryDone(provider, entry.id);
    final hasReminder = provider.plannerReminderTime(entry.id) != null;
    final taskColor = task.taskColor;
    final checkpoints = entry.checkpoints;
    final totalCps = checkpoints.length;
    final completedCps = checkpoints.where((c) => c.completed).length;

    return _AnimatedEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const _Chamfer4CornerClipper(chamfer: 4.0),
          child: CustomPaint(
            foregroundPainter: _TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 4.0,
              bracketSize: 6.0,
            ),
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Draggable<_PlanEntryDragData>(
                        data: _PlanEntryDragData(entry: entry, sourceRowIndex: rowIndex),
                        onDragStarted: _onPlanDragStarted,
                        onDragEnd: (_) => _onPlanDragEnded(),
                        onDraggableCanceled: (_, __) => _onPlanDragEnded(),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                              border: Border.all(color: JweTheme.accentCyan),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(1, 3, 5, 3),
                            child: Icon(Icons.drag_indicator, size: 11, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(1, 3, 5, 3),
                          child: Icon(Icons.drag_indicator, size: 11, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                        ),
                      ),
                      // NO HERO ICON!
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => _showSubtasksModal(provider, entry, sub.name),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 10,
                                    color: totalCps > 0 ? (JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8)) : JweTheme.textMuted,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    totalCps > 0 ? '$completedCps/$totalCps' : '0/0',
                                    style: GoogleFonts.rajdhani(
                                      color: totalCps > 0 ? (JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8)) : JweTheme.textMuted,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => _editEstimate(provider, entry.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _editReminder(provider, entry.id),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                                color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                                size: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => _completePlanItem(provider, entry),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check,
                                color: isDone ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981)) : JweTheme.accentCyan,
                                size: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => _removeFromPlan(provider, entry),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close, color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B), size: 11),
                            ),
                          ),
                          const SizedBox(width: 2),
                          _buildCardMenuButton(
                            provider: provider,
                            entry: entry,
                            mainTaskId: task.id,
                            subTaskId: sub.id,
                            subTaskName: sub.name,
                            rowIndex: rowIndex,
                            isInMultiRow: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalSubtasksPanel(
    AppProvider provider,
    _PlanEntry entry,
  ) {
    final checkpoints = entry.checkpoints;
    final completedCount = checkpoints.where((c) => c.completed).length;
    final totalCount = checkpoints.length;
    final totalMinutes = checkpoints.fold<int>(0, (sum, c) => sum + c.durationMinutes);
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final isExpanded = _expandedCheckpointEntries.contains(entry.key);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF060A0F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: JweTheme.isLight ? JweTheme.border : const Color(0xFF14202D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCheckpointEntries.remove(entry.key);
                } else {
                  _expandedCheckpointEntries.add(entry.key);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.checklist_rounded,
                    size: 13,
                    color: totalCount > 0
                        ? (completedCount == totalCount ? JweTheme.accentTeal : JweTheme.accentCyan)
                        : JweTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CHECKPOINTS ($completedCount/$totalCount)',
                    style: GoogleFonts.rajdhani(
                      color: JweTheme.isLight ? JweTheme.textWhite : const Color(0xFFEAECF3),
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (totalMinutes > 0)
                    Text(
                      'Total: ${totalMinutes}m',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: JweTheme.isLight ? JweTheme.border : const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount ? JweTheme.accentTeal : JweTheme.accentCyan,
                  ),
                  minHeight: 2,
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checkpoints.isNotEmpty)
                          ...checkpoints.map((cp) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  _CustomSquareCheck(
                                    checked: cp.completed,
                                    onTap: () => _toggleCheckpoint(provider, entry, cp),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cp.name,
                                      style: GoogleFonts.rajdhani(
                                        color: cp.completed ? JweTheme.textMuted : JweTheme.textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: cp.completed ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${cp.durationMinutes}m',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _removeCheckpoint(provider, entry, cp),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text(
                                        '✕',
                                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _promptAddSubtask(provider, entry),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: JweTheme.lineSoft, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 12, color: JweTheme.accentCyan),
                                const SizedBox(width: 4),
                                Text(
                                  '+ ADD CHECKPOINT',
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.accentCyan,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 4),
          ),
        ],
      ),
    );
  }

  void _showSubtasksModal(AppProvider provider, _PlanEntry entry, String subTaskName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: JweTheme.border, width: 1.5),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final checkpoints = entry.checkpoints;
            final completedCount = checkpoints.where((c) => c.completed).length;

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHECKPOINTS',
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.accentCyan,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                subTaskName,
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF111D28),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: JweTheme.border),
                          ),
                          child: Text(
                            '$completedCount / ${checkpoints.length}',
                            style: GoogleFonts.rajdhani(
                              color: JweTheme.accentCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: JweTheme.lineSoft, height: 1),
                    const SizedBox(height: 8),
                    if (checkpoints.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No checkpoints attached yet.',
                            style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: checkpoints.length,
                          itemBuilder: (context, idx) {
                            final cp = checkpoints[idx];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF05080C),
                                border: Border.all(
                                  color: cp.completed ? JweTheme.border : (JweTheme.isLight ? JweTheme.border : const Color(0xFF1F2F40)),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  _CustomSquareCheck(
                                    checked: cp.completed,
                                    onTap: () {
                                      _toggleCheckpoint(provider, entry, cp);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      cp.name,
                                      style: GoogleFonts.rajdhani(
                                        color: cp.completed ? JweTheme.textMuted : JweTheme.textWhite,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: cp.completed ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${cp.durationMinutes}m',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      _removeCheckpoint(provider, entry, cp);
                                      setModalState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        '✕',
                                        style: TextStyle(color: JweTheme.textMuted, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _promptAddSubtask(provider, entry);
                        setModalState(() {});
                      },
                      icon: Icon(Icons.add, size: 16, color: JweTheme.accentCyan),
                      label: Text(
                        'ADD CHECKPOINT',
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: JweTheme.accentCyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptAddSubtask(AppProvider provider, _PlanEntry entry) async {
    final nameCtrl = TextEditingController();
    int selectedMinutes = 15;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: JweTheme.accentCyan, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.add_task, color: JweTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'ADD CHECKPOINT',
                style: GoogleFonts.rajdhani(
                  color: JweTheme.accentCyan,
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Checkpoint title…',
                  hintStyle: GoogleFonts.rajdhani(color: JweTheme.textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentCyan),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ESTIMATED DURATION',
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 25, 30].map((m) {
                  final isSel = selectedMinutes == m;
                  return ChoiceChip(
                    label: Text('${m}m',
                        style: GoogleFonts.rajdhani(
                          color: isSel ? JweTheme.onAccent : JweTheme.textWhite,
                          fontWeight: FontWeight.bold,
                        )),
                    selected: isSel,
                    selectedColor: JweTheme.accentCyan,
                    backgroundColor: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF111D28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    onSelected: (_) => setDlgState(() => selectedMinutes = m),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCEL', style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentCyan,
                foregroundColor: JweTheme.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text('ADD', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      _addCheckpoint(provider, entry, nameCtrl.text.trim(), selectedMinutes);
      showGlobalToast('Checkpoint added');
    }
  }

  Widget _buildCardMenuButton({
    required AppProvider provider,
    required _PlanEntry entry,
    required String mainTaskId,
    required String subTaskId,
    required String subTaskName,
    required int rowIndex,
    required bool isInMultiRow,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: JweTheme.textMuted),
      color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: JweTheme.border),
      ),
      padding: EdgeInsets.zero,
      onSelected: (action) => _onCardMenuSelected(
        action: action,
        provider: provider,
        entry: entry,
        mainTaskId: mainTaskId,
        subTaskId: subTaskId,
        subTaskName: subTaskName,
        rowIndex: rowIndex,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'duplicate_mission',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('DUPLICATE MISSION', style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_subtask',
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('ADD CHECKPOINT', style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'view_subtasks',
          child: Row(
            children: [
              Icon(Icons.checklist, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('VIEW CHECKPOINTS', style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (isInMultiRow)
          PopupMenuItem(
            value: 'move_own_row',
            child: Row(
              children: [
                const Icon(Icons.table_rows_outlined, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text('MOVE TO OWN ROW', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'multitask_add',
          child: Row(
            children: [
              const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('MULTITASK / ADD TO ROW', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'adjust_duration',
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFCBD5E1)),
              const SizedBox(width: 8),
              Text('ADJUST DURATION', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reminder',
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined, size: 16, color: Color(0xFFCBD5E1)),
              const SizedBox(width: 8),
              Text('SET REMINDER', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF2A4B)),
              const SizedBox(width: 8),
              Text('DELETE MISSION', style: GoogleFonts.rajdhani(color: const Color(0xFFFF2A4B), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _onCardMenuSelected({
    required String action,
    required AppProvider provider,
    required _PlanEntry entry,
    required String mainTaskId,
    required String subTaskId,
    required String subTaskName,
    required int rowIndex,
  }) {
    switch (action) {
      case 'duplicate_mission':
        _duplicatePlanItem(provider, entry, rowIndex);
        break;
      case 'add_subtask':
        _promptAddSubtask(provider, entry);
        break;
      case 'view_subtasks':
        _showSubtasksModal(provider, entry, subTaskName);
        break;
      case 'move_own_row':
        setState(() {
          if (rowIndex >= 0 && rowIndex < _rows.length) {
            final row = _rows[rowIndex];
            row.entries.removeWhere((e) => e.key == entry.key);
            if (row.entries.isEmpty) {
              _rows.removeAt(rowIndex);
            }
            _rows.insert(rowIndex + 1, _PlanRowData([entry]));
          }
        });
        _persistPlan(provider);
        showGlobalToast('Moved to separate row');
        break;
      case 'multitask_add':
        if (_rows[rowIndex].entries.length >= 3) {
          showGlobalToast('TACTICAL OVERLOAD: Maximum 3 missions allowed per row!');
          return;
        }
        setState(() {
          _multitaskTargetRowIndex = rowIndex;
          _addExpanded = true;
        });
        showGlobalToast('Select a mission below to link to row ${rowIndex + 1}');
        break;
      case 'adjust_duration':
        _editEstimate(provider, entry.id);
        break;
      case 'reminder':
        _editReminder(provider, entry.id);
        break;
      case 'delete':
        _removeFromPlan(provider, entry);
        break;
    }
  }
}

/// Animates a plan entry in (grow + fade) when queued and out (collapse +
/// fade, tinted by the action) before it is actually removed from the list.
class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  final bool animateIn;
  final _LeaveKind? leaving;
  final VoidCallback onLeft;

  const _AnimatedEntry({
    super.key,
    required this.child,
    required this.animateIn,
    required this.leaving,
    required this.onLeft,
  });

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _leaveStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
      value: widget.animateIn ? 0.0 : 1.0,
    );
    if (widget.animateIn) _controller.forward();
    _maybeStartLeave();
  }

  @override
  void didUpdateWidget(covariant _AnimatedEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartLeave();
  }

  void _maybeStartLeave() {
    if (widget.leaving == null || _leaveStarted) return;
    _leaveStarted = true;
    _controller.reverse().whenComplete(widget.onLeft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final veil = switch (widget.leaving) {
      _LeaveKind.completed => AppTheme.fhAccentGreen.withValues(alpha: 0.12),
      _LeaveKind.removed => AppTheme.fhAccentRed.withValues(alpha: 0.10),
      null => null,
    };
    Widget body = widget.child;
    if (veil != null) {
      body = Stack(children: [
        body,
        Positioned.fill(child: IgnorePointer(child: Container(color: veil))),
      ]);
    }
    Widget result = SizeTransition(
      sizeFactor: curved,
      alignment: const Alignment(-1.0, -1.0),
      child: FadeTransition(opacity: curved, child: body),
    );
    if (widget.leaving != null) {
      result = IgnorePointer(child: result);
    }
    return result;
  }
}



class _TacticalFooter extends StatelessWidget {
  const _TacticalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: _ValorantMarkPainter(
                color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SMALL STEPS BIG RESULTS —',
              style: GoogleFonts.rajdhani(
                color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF62778D),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValorantMarkPainter extends CustomPainter {
  final Color color;
  _ValorantMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path1 = Path()
      ..moveTo(w * 0.15, h)
      ..lineTo(w * 0.45, 0)
      ..lineTo(w * 0.55, 0)
      ..lineTo(w * 0.25, h)
      ..close();
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(w * 0.55, h)
      ..lineTo(w * 0.85, 0)
      ..lineTo(w * 0.95, 0)
      ..lineTo(w * 0.65, h)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _ValorantMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Cyberpunk Tactical Background Art matching the SVG canvas from HTML
class _TacticalBackgroundPainter extends CustomPainter {
  const _TacticalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isLight = JweTheme.isLight;
    final accentRed = isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B);

    // 1. Dot Grid pattern (24x24, circle at cx: 2, cy: 2, r: 0.8)
    final dotColor = isLight
        ? const Color(0xFFC5BCAC).withValues(alpha: 0.45)
        : const Color(0xFF172433).withValues(alpha: 0.6);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    for (double x = 0; x < w; x += 24.0) {
      for (double y = 0; y < h; y += 24.0) {
        canvas.drawCircle(Offset(x + 2, y + 2), 0.9, dotPaint);
      }
    }

    // Scale factors from reference viewBox 440 x 900
    final sx = w / 440.0;
    final sy = h / 900.0;

    // 2. Top Red Slash Gradient Polygon: 340,0 440,0 440,70 370,70
    final slashPath = Path()
      ..moveTo(340 * sx, 0)
      ..lineTo(w, 0)
      ..lineTo(w, 70 * sy)
      ..lineTo(370 * sx, 70 * sy)
      ..close();

    final slashGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accentRed.withValues(alpha: isLight ? 0.2 : 0.3),
        accentRed.withValues(alpha: 0.0),
      ],
    );
    final slashRect = Rect.fromLTRB(340 * sx, 0, w, 70 * sy);
    final slashPaint = Paint()
      ..shader = slashGradient.createShader(slashRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(slashPath, slashPaint);

    // 3. Top Stroke Line: M 330 0 L 365 70 L 440 70
    final topStrokePath = Path()
      ..moveTo(330 * sx, 0)
      ..lineTo(365 * sx, 70 * sy)
      ..lineTo(w, 70 * sy);
    final topStrokePaint = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.35 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(topStrokePath, topStrokePaint);

    // 4. Bottom Polygon 1: 160,900 240,820 260,820 180,900
    final bottomPoly1 = Path()
      ..moveTo(160 * sx, h)
      ..lineTo(240 * sx, h - 80 * sy)
      ..lineTo(260 * sx, h - 80 * sy)
      ..lineTo(180 * sx, h)
      ..close();
    final bottomPaint1 = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.12 : 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPoly1, bottomPaint1);

    // 5. Bottom Polygon 2: 185,900 250,835 255,835 190,900
    final bottomPoly2 = Path()
      ..moveTo(185 * sx, h)
      ..lineTo(250 * sx, h - 65 * sy)
      ..lineTo(255 * sx, h - 65 * sy)
      ..lineTo(190 * sx, h)
      ..close();
    final bottomPaint2 = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.25 : 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPoly2, bottomPaint2);

    // 6. Bottom Line: x1=260 y1=840 x2=340 y2=840
    final bottomLinePaint = Paint()
      ..color = accentRed.withValues(alpha: isLight ? 0.25 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(260 * sx, h - 60 * sy),
      Offset(340 * sx, h - 60 * sy),
      bottomLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TacticalBackgroundPainter oldDelegate) => false;
}

/// Clipper for 4-corner chamfer (Layout 1: Full-width row)
/// polygon(10px 0, calc(100% - 10px) 0, 100% 10px, 100% calc(100% - 10px),
/// calc(100% - 10px) 100%, 10px 100%, 0 calc(100% - 10px), 0 10px)
class _Chamfer4CornerClipper extends CustomClipper<Path> {
  final double chamfer;
  const _Chamfer4CornerClipper({this.chamfer = 10.0});

  @override
  Path getClip(Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _Chamfer4CornerClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}

/// Tactical border & bracket painter for planned cards (Card 1, Card 2, Card 3)
class _TacticalCardBorderPainter extends CustomPainter {
  final Color themeColor;
  final double chamfer;
  final double bracketSize;

  const _TacticalCardBorderPainter({
    required this.themeColor,
    this.chamfer = 10.0,
    this.bracketSize = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    // 1px border around chamfered path
    final borderPaint = Paint()
      ..color = JweTheme.isLight ? JweTheme.border : const Color(0xFF1A2736)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    final resolvedColor = JweTheme.calibrate(themeColor);

    // 3px solid theme color along left edge
    final leftEdgePaint = Paint()
      ..color = resolvedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, c), Offset(0, h - c), leftEdgePaint);

    // Top-left bracket following the chamfer
    if (bracketSize > 0) {
      final bracketPaint = Paint()
        ..color = resolvedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final bracketPath = Path()
        ..moveTo(0, c + bracketSize)
        ..lineTo(0, c)
        ..lineTo(c, 0)
        ..lineTo(c + bracketSize, 0);
      canvas.drawPath(bracketPath, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalCardBorderPainter oldDelegate) =>
      oldDelegate.themeColor != themeColor ||
      oldDelegate.chamfer != chamfer ||
      oldDelegate.bracketSize != bracketSize;
}

/// Custom square checkbox matching HTML .custom-check
class _CustomSquareCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const _CustomSquareCheck({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cyan = JweTheme.accentCyan;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: checked
              ? cyan.withValues(alpha: JweTheme.isLight ? 0.15 : 0.2)
              : (JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF0B1219)),
          border: Border.all(
            color: checked ? cyan : (JweTheme.isLight ? JweTheme.border : const Color(0xFF334155)),
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: checked
            ? Text(
                '✓',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: cyan,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}

/// Collapsible dropdown group used in the "add to plan" list. Level 0 renders
/// a main-task header (uppercase, colored, letter-spaced); level 1 renders a
/// nested subtask header (indented). Tapping the header toggles its children so
/// the task → subtask → checkpoint hierarchy is visually obvious.
class _CollapsibleGroup extends StatefulWidget {
  final String title;
  final Color color;
  final int level;
  final int queuedCount;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleGroup({
    super.key,
    required this.title,
    required this.color,
    required this.level,
    required this.queuedCount,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isMain = widget.level == 0;
    return Container(
      margin: EdgeInsets.only(
          top: isMain ? 8 : 4, left: isMain ? 0 : 12, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: isMain ? 6 : 5),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark
                    .withValues(alpha: isMain ? 0.85 : 0.5),
                border: Border(
                    left: BorderSide(
                        color: widget.color
                            .withValues(alpha: isMain ? 1.0 : 0.6),
                        width: isMain ? 3 : 2)),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(MdiIcons.chevronRight,
                        size: isMain ? 18 : 15,
                        color: isMain
                            ? widget.color
                            : AppTheme.fhTextSecondary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isMain ? widget.title.toUpperCase() : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMain
                            ? widget.color
                            : AppTheme.fhTextPrimary,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.w600,
                        fontSize: isMain ? 11 : 12.5,
                        letterSpacing: isMain ? 1.5 : 0,
                      ),
                    ),
                  ),
                  if (widget.queuedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.fhAccentTeal.withValues(alpha: 0.12),
                        border: Border.all(
                            color: AppTheme.fhAccentTeal
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text('${widget.queuedCount}',
                          style: TextStyle(
                              color: AppTheme.fhAccentTeal,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.children),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  final String title;
  final Color color;
  final bool isCheckpoint;
  final int plannedCount;
  final VoidCallback onAdd;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const _AvailableRow({
    required this.title,
    required this.color,
    required this.isCheckpoint,
    required this.plannedCount,
    required this.onAdd,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSelectionMode
          ? () => onSelectedChanged?.call(!isSelected)
          : onAdd,
      child: Container(
        margin: EdgeInsets.only(bottom: 4, left: isCheckpoint ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark.withValues(alpha: isCheckpoint ? 0.4 : 0.7),
          border: Border(
              left: BorderSide(color: color.withValues(alpha: isCheckpoint ? 0.4 : 1.0), width: 2)),
        ),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Theme(
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: AppTheme.fhTextDisabled,
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppTheme.fhAccentTeal,
                    checkColor: Colors.black,
                    onChanged: onSelectedChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isCheckpoint ? MdiIcons.rhombusOutline : MdiIcons.targetAccount,
              size: isCheckpoint ? 14 : 16,
              color: isCheckpoint ? AppTheme.fhTextSecondary : color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: isCheckpoint ? 12 : 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isSelectionMode && plannedCount > 0) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.fhAccentTeal.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                ),
                child: Text(
                  plannedCount == 1 ? 'QUEUED' : 'QUEUED ×$plannedCount',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold),
                ),
              )
                  .animate(key: ValueKey(plannedCount))
                  .scaleXY(
                      begin: 0.6,
                      end: 1.0,
                      duration: 280.ms,
                      curve: Curves.easeOutBack)
                  .fadeIn(duration: 120.ms),
            ],
            if (!isSelectionMode)
              Icon(Icons.add, color: AppTheme.fhAccentTeal, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AddSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Widget child;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _AddSection({
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.child,
    required this.activeTab,
    required this.onTabChanged,
  });

  static const double _headerHeight = 53;
  static const double _expandedHeight = 340;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: expanded ? _expandedHeight : _headerHeight,
      decoration:   BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(top: BorderSide(color: AppTheme.fhBorderColor)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(MdiIcons.plusBoxOutline,
                        size: 18, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 8),
                    Text('ADD MISSIONS',
                        style: GoogleFonts.rajdhani(
                            color: AppTheme.fhAccentTeal,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 14)),
                    const Spacer(),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.expand_less,
                        color: AppTheme.fhTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            // Fixed-height content clipped while the container grows, so the
            // expand animation never triggers a transient RenderFlex overflow.
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: _expandedHeight - _headerHeight,
                  maxHeight: _expandedHeight - _headerHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TabButton(
                              title: 'MISSIONS',
                              isActive: activeTab == 0,
                              onTap: () => onTabChanged(0),
                            ),
                            const SizedBox(width: 24),
                            _TabButton(
                              title: 'ROUTINES',
                              isActive: activeTab == 1,
                              onTap: () => onTabChanged(1),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: activeTab == 0 ? 'Search missions…' : 'Search routines…',
                            hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13),
                            prefixIcon: Icon(Icons.search,
                                size: 16, color: AppTheme.fhTextSecondary),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 32, minHeight: 32),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                          ),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ).animate().fadeIn(duration: 200.ms, delay: 60.ms),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: isActive ? AppTheme.fhAccentTeal : AppTheme.fhTextDisabled,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            color: isActive ? AppTheme.fhAccentTeal : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class RoutineItemSelectable {
  final String compoundId;
  final String title;
  final String parentPath;
  final Color color;

  RoutineItemSelectable({
    required this.compoundId,
    required this.title,
    required this.parentPath,
    required this.color,
  });
}

class ResolvedRoutineItem {
  final String title;
  final String parentPath;
  ResolvedRoutineItem({required this.title, required this.parentPath});
}

List<SubSubTask> _getAllCheckpointsForPlanning(SubTask sub) {
  final List<SubSubTask> result = [];
  void recurse(List<SubSubTask> currentList) {
    for (final cp in currentList) {
      if (sub.isRecurring || !cp.completed) {
        result.add(cp);
        recurse(cp.substeps);
      }
    }
  }
  recurse(sub.subSubTasks);
  return result;
}

String _findParentPath(SubTask sub, SubSubTask target) {
  String? search(List<SubSubTask> list, String currentPath) {
    for (final item in list) {
      if (item.id == target.id) return currentPath;
      final subPath = currentPath.isEmpty ? item.name : '$currentPath > ${item.name}';
      final found = search(item.substeps, subPath);
      if (found != null) return found;
    }
    return null;
  }
  final path = search(sub.subSubTasks, '');
  if (path == null || path.isEmpty) {
    return sub.name;
  }
  return '${sub.name} > $path';
}
