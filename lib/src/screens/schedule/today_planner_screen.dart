import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/global_toast.dart';

/// One slot in the day plan. The same compound id may appear more than once
/// (planning several sessions of the same work), so each slot carries its own
/// stable [key] for list identity and animations.
class _PlanEntry {
  static int _seq = 0;
  final String key;
  final String id;
  final bool addedAtRuntime;
  _PlanEntry(this.id, {this.addedAtRuntime = false}) : key = 'plan-entry-${_seq++}';
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
  List<_PlanEntry> _entries = [];
  Map<String, int> _estimates = {};
  final Map<String, _LeaveKind> _leaving = {};
  bool _addExpanded = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _date = widget.date ?? helper.getTodayDateString();
      final provider = Provider.of<AppProvider>(context, listen: false);
      _entries = provider.taskActions.getDayPlan(_date).map(_PlanEntry.new).toList();
      _estimates = provider.taskActions.getDayPlanEstimates(_date);
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _persistPlan(AppProvider provider) {
    provider.taskActions.updateDayPlan(_date, _entries.map((e) => e.id).toList());
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
    if (median != null) return median;
    return parts.length == 3
        ? TaskCalculations.defaultCheckpointMinutes
        : TaskCalculations.defaultSubtaskMinutes;
  }

  /// True when the entry's target is already completed (kept in the plan as a
  /// dimmed "done" row until the user removes it — never auto-removed).
  bool _isEntryDone(AppProvider provider, String compoundId) {
    final parts = compoundId.split('|');
    if (parts.length < 2) return false;
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null) return false;
    if (parts.length == 3) {
      return sub.findCheckpoint(parts[2])?.completed ?? false;
    }
    return sub.completed;
  }

  void _addToPlan(AppProvider provider, String compoundId) {
    setState(() {
      _entries.add(_PlanEntry(compoundId, addedAtRuntime: true));
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
      _entries.removeWhere((e) => e.key == entry.key);
      _leaving.remove(entry.key);
    });
    _persistPlan(provider); // updateDayPlan auto-clears a Phoenix that left the plan
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

  void _togglePhoenix(AppProvider provider, _PlanEntry entry) {
    final current = provider.taskActions.getPhoenixId(_date);
    if (current == entry.id) {
      provider.taskActions.setPhoenix(_date, null);
    } else {
      // Pin to the front so the Phoenix reads as the first thing of the day.
      setState(() {
        _entries.removeWhere((e) => e.key == entry.key);
        _entries.insert(0, entry);
      });
      _persistPlan(provider);
      provider.taskActions.setPhoenix(_date, entry.id);
    }
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
    int doneMinutes = 0;
    int doneCount = 0;
    for (final entry in _entries) {
      final est = _estimateFor(entry.id, provider);
      if (_isEntryDone(provider, entry.id)) {
        doneMinutes += est;
        doneCount++;
      } else {
        plannedMinutes += est;
      }
    }
    final active = _resolveActive(provider);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text(
            _date == helper.getTodayDateString()
                ? 'TODAY'
                : DateFormat('dd MMM yyyy').format(DateTime.parse(_date)).toUpperCase(),
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhAccentTeal,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:   IconThemeData(color: AppTheme.fhTextPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _BudgetBar(
              plannedMinutes: plannedMinutes,
              doneMinutes: doneMinutes,
              doneCount: doneCount,
              minutesLeft: minutesLeft,
              realisticMinutes: realisticMinutes,
              fromHistory: window.fromHistory,
            ),
            if (active.title != null)
              _ActivePill(
                title: active.title!,
                color: active.color ?? AppTheme.fhAccentTeal,
                isRunning: active.isRunning,
              ),
            Expanded(child: _buildPlanList(provider)),
            _AddSection(
              expanded: _addExpanded,
              onToggle: () => setState(() => _addExpanded = !_addExpanded),
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              child: _buildAvailableList(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList(AppProvider provider) {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.formatListBulletedSquare,
                size: 48, color: AppTheme.fhTextDisabled),
            const SizedBox(height: 12),
            Text('NOTHING PLANNED',
                style: GoogleFonts.rajdhani(
                    color: AppTheme.fhTextDisabled,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Queue the work that matters today.',
                style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _addExpanded = true),
              icon: Icon(MdiIcons.plusBoxOutline, size: 16, color: AppTheme.fhAccentTeal),
              label: Text('ADD MISSIONS',
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
        ).animate().fadeIn(duration: 300.ms),
      );
    }

    final phoenixId = provider.taskActions.getPhoenixId(_date);
    // Only the first occurrence is the Phoenix; duplicates stay in the queue.
    final phoenixIndex =
        phoenixId == null ? -1 : _entries.indexWhere((e) => e.id == phoenixId);
    final phoenixEntry = phoenixIndex == -1 ? null : _entries[phoenixIndex];
    final queue = [
      for (var i = 0; i < _entries.length; i++)
        if (i != phoenixIndex) _entries[i],
    ];

    final list = ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: queue.length,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.02 * t,
            child: Material(
              color: Colors.transparent,
              elevation: 6 * t,
              shadowColor: Colors.black.withValues(alpha: 0.5),
              child: child,
            ),
          );
        },
      ),
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = queue.removeAt(oldIndex);
          queue.insert(newIndex, item);
          _entries = [if (phoenixEntry != null) phoenixEntry, ...queue];
        });
        _persistPlan(provider);
      },
      itemBuilder: (context, index) {
        final entry = queue[index];
        return _AnimatedEntry(
          key: ValueKey(entry.key),
          animateIn: entry.addedAtRuntime,
          leaving: _leaving[entry.key],
          onLeft: () => _finishLeave(provider, entry),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: _PlanRow(
              compoundId: entry.id,
              provider: provider,
              dragIndex: index,
              minutes: _estimateFor(entry.id, provider),
              isCustomEstimate: _estimates.containsKey(entry.id),
              isDone: _isEntryDone(provider, entry.id),
              hasReminder: provider.plannerReminderTime(entry.id) != null,
              onEditEstimate: () => _editEstimate(provider, entry.id),
              onEditReminder: () => _editReminder(provider, entry.id),
              onRemove: () => _removeFromPlan(provider, entry),
              onAnoint: () => _togglePhoenix(provider, entry),
              onCheck: () => _completePlanItem(provider, entry),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: 280.ms,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
                sizeFactor: animation, alignment: const Alignment(-1.0, -1.0), child: child),
          ),
          child: phoenixEntry != null
              ? _AnimatedEntry(
                  key: ValueKey('phoenix-${phoenixEntry.key}'),
                  animateIn: false,
                  leaving: _leaving[phoenixEntry.key],
                  onLeft: () => _finishLeave(provider, phoenixEntry),
                  child: _PhoenixCard(
                    compoundId: phoenixEntry.id,
                    provider: provider,
                    minutes: _estimateFor(phoenixEntry.id, provider),
                    isCustomEstimate: _estimates.containsKey(phoenixEntry.id),
                    isDone: _isEntryDone(provider, phoenixEntry.id),
                    hasReminder:
                        provider.plannerReminderTime(phoenixEntry.id) != null,
                    onEditEstimate: () => _editEstimate(provider, phoenixEntry.id),
                    onEditReminder: () => _editReminder(provider, phoenixEntry.id),
                    onRemove: () => _removeFromPlan(provider, phoenixEntry),
                    onDemote: () => _togglePhoenix(provider, phoenixEntry),
                    onCheck: () => _completePlanItem(provider, phoenixEntry),
                  ),
                )
              : const _AnointHint(key: ValueKey('anoint-hint')),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildAvailableList(AppProvider provider) {
    final plannedCounts = <String, int>{};
    for (final entry in _entries) {
      plannedCounts[entry.id] = (plannedCounts[entry.id] ?? 0) + 1;
    }
    final activeTasks =
        provider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
    final q = _searchQuery;
    final widgets = <Widget>[];

    for (final task in activeTasks) {
      final activeSubs = task.subTasks.where((s) {
        if (s.isDeleted) return false;
        if (s.completed) return s.isRecurring;
        return true;
      }).toList();
      if (activeSubs.isEmpty) continue;

      final taskRows = <Widget>[];

      for (final sub in activeSubs) {
        final subId = '${task.id}|${sub.id}';
        final activeCps = _getAllCheckpointsForPlanning(sub);

        if (_matchesQuery(sub.name, q)) {
          taskRows.add(_AvailableRow(
            title: sub.name,
            color: task.taskColor,
            isCheckpoint: false,
            plannedCount: plannedCounts[subId] ?? 0,
            onAdd: () => _addToPlan(provider, subId),
          ));
        }

        for (final cp in activeCps) {
          final cpId = '$subId|${cp.id}';
          if (!_matchesQuery(cp.name, q) && !_matchesQuery(sub.name, q)) continue;
          taskRows.add(_AvailableRow(
            title: cp.name,
            parent: _findParentPath(sub, cp),
            color: task.taskColor,
            isCheckpoint: true,
            plannedCount: plannedCounts[cpId] ?? 0,
            onAdd: () => _addToPlan(provider, cpId),
          ));
        }
      }

      if (taskRows.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Text(task.name.toUpperCase(),
              style: TextStyle(
                  color: task.taskColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.5)),
        ));
        widgets.addAll(taskRows);
      }
    }

    if (widgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            q.isEmpty ? 'No available items.' : 'No matches for "$_searchQuery".',
            style:   TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
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

class _BudgetBar extends StatelessWidget {
  final int plannedMinutes;
  final int doneMinutes;
  final int doneCount;
  final int minutesLeft;
  final int realisticMinutes;
  final bool fromHistory;

  const _BudgetBar({
    required this.plannedMinutes,
    required this.doneMinutes,
    required this.doneCount,
    required this.minutesLeft,
    required this.realisticMinutes,
    required this.fromHistory,
  });

  @override
  Widget build(BuildContext context) {
    // Capacity is judged against realistic (buffer-aware) time, not raw time left.
    final over = realisticMinutes > 0 && plannedMinutes > realisticMinutes;
    final ratio = realisticMinutes <= 0
        ? 1.0
        : (plannedMinutes / realisticMinutes).clamp(0.0, 1.0);
    final color = over
        ? AppTheme.fhAccentRed
        : (ratio > 0.85 ? PersonInfoTheme.spideyCyan : AppTheme.fhAccentGreen);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration:   BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: plannedMinutes.toDouble()),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(formatMinutes(v.round()),
                    style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1)),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('PLANNED / ${formatMinutes(realisticMinutes)} USABLE',
                    style: TextStyle(
                        color: over ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${formatMinutes(minutesLeft)} LEFT',
                  style: TextStyle(
                      color: over ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: fromHistory
                    ? 'Window from your sleep history'
                    : 'Window from default 07:00–22:00',
                child: Icon(
                  fromHistory ? MdiIcons.weatherNight : MdiIcons.clockOutline,
                  size: 14,
                  color: AppTheme.fhTextDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: SizedBox(
              height: 4,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(children: [
                  Container(color: AppTheme.fhBgDeepDark),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * ratio,
                    color: color,
                  ),
                ]),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                  sizeFactor: animation, alignment: const Alignment(-1.0, -1.0), child: child),
            ),
            child: (over || doneCount > 0)
                ? Padding(
                    key: ValueKey('bar-meta-$over-$doneCount-$doneMinutes'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        if (doneCount > 0)
                          Text(
                            '✓ $doneCount DONE · ${formatMinutes(doneMinutes)}',
                            style: TextStyle(
                                color: AppTheme.fhAccentGreen,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold),
                          ),
                        const Spacer(),
                        if (over)
                          Text(
                            'OVER BY ${formatMinutes(plannedMinutes - realisticMinutes)} — TRIM OR RESCHEDULE',
                            style: TextStyle(
                                color: AppTheme.fhAccentRed,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('bar-meta-none')),
          ),
        ],
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final String title;
  final Color color;
  final bool isRunning;

  const _ActivePill({
    required this.title,
    required this.color,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(width: 6, height: 6, color: color);
    if (isRunning) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 1.0, end: 0.35, duration: 800.ms, curve: Curves.easeInOut);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 8),
          Text(
            isRunning ? 'DOING' : 'UP NEXT',
            style: TextStyle(
                color: isRunning ? AppTheme.fhAccentGreen : AppTheme.fhTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                title,
                key: ValueKey(title),
                style:   TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estimate chip that pulses whenever its value changes.
class _EstimateChip extends StatelessWidget {
  final int minutes;
  final bool isCustom;
  final Color accent;
  final VoidCallback onTap;

  const _EstimateChip({
    required this.minutes,
    required this.isCustom,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDeepDark,
          border: Border.all(
              color: isCustom
                  ? accent.withValues(alpha: 0.6)
                  : AppTheme.fhBorderColor),
        ),
        child: Text(formatMinutes(minutes),
                style: TextStyle(
                    color: isCustom ? accent : AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
            .animate(key: ValueKey(minutes))
            .scaleXY(
                begin: 0.7,
                end: 1.0,
                duration: 250.ms,
                curve: Curves.easeOutBack),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String compoundId;
  final AppProvider provider;
  final int dragIndex;
  final int minutes;
  final bool isCustomEstimate;
  final bool isDone;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onEditReminder;
  final VoidCallback onRemove;
  final VoidCallback onAnoint;
  final VoidCallback onCheck;

  const _PlanRow({
    required this.compoundId,
    required this.provider,
    required this.dragIndex,
    required this.minutes,
    required this.isCustomEstimate,
    required this.isDone,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onEditReminder,
    required this.onRemove,
    required this.onAnoint,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final parts = compoundId.split('|');
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

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDone ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border(left: BorderSide(color: task.taskColor, width: 3)),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: dragIndex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_indicator,
                    color: AppTheme.fhTextDisabled, size: 18),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: AppTheme.fhTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(parent,
                        style:   TextStyle(
                            color: AppTheme.fhTextSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            if (isDone) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('DONE',
                        style: TextStyle(
                            color: AppTheme.fhAccentGreen,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold))
                    .animate()
                    .fadeIn(duration: 250.ms)
                    .scaleXY(begin: 0.7, curve: Curves.easeOutBack),
              ),
            ] else ...[
              _EstimateChip(
                minutes: minutes,
                isCustom: isCustomEstimate,
                accent: AppTheme.fhAccentTeal,
                onTap: onEditEstimate,
              ),
              IconButton(
                icon: Icon(MdiIcons.fireCircle,
                    size: 18, color: AppTheme.fhTextSecondary),
                onPressed: onAnoint,
                splashRadius: 18,
                tooltip: 'Anoint as Phoenix',
              ),
              IconButton(
                icon: Icon(
                  hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                  size: 18,
                  color: hasReminder ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
                ),
                onPressed: onEditReminder,
                splashRadius: 18,
                tooltip: 'Reminder',
              ),
              IconButton(
                icon:   Icon(Icons.check, size: 18, color: AppTheme.fhAccentTeal),
                onPressed: onCheck,
                splashRadius: 18,
                tooltip: 'Complete Task',
              ),
            ],
            IconButton(
              icon:   Icon(Icons.close, size: 18, color: AppTheme.fhAccentRed),
              onPressed: onRemove,
              splashRadius: 18,
              tooltip: 'Remove from plan',
            ),
          ],
        ),
      ),
    );
  }
}

class _AnointHint extends StatelessWidget {
  const _AnointHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.fhAccentOrange.withValues(alpha: 0.05),
        border: Border.all(
            color: AppTheme.fhAccentOrange.withValues(alpha: 0.35),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.fireCircle, size: 16, color: AppTheme.fhAccentOrange),
          const SizedBox(width: 10),
            Expanded(
            child: Text('Anoint your Phoenix — the one thing that must rise today.',
                style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11.5)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PhoenixCard extends StatelessWidget {
  final String compoundId;
  final AppProvider provider;
  final int minutes;
  final bool isCustomEstimate;
  final bool isDone;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onEditReminder;
  final VoidCallback onRemove;
  final VoidCallback onDemote;
  final VoidCallback onCheck;

  const _PhoenixCard({
    required this.compoundId,
    required this.provider,
    required this.minutes,
    required this.isCustomEstimate,
    required this.isDone,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onEditReminder,
    required this.onRemove,
    required this.onDemote,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final parts = compoundId.split('|');
    if (parts.length < 2) return const SizedBox.shrink();
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null) return const SizedBox.shrink();

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }
    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${_findParentPath(sub, cp!)}' : task.name;

    final amber = AppTheme.fhAccentOrange;

    final fireIcon = Icon(MdiIcons.fire, size: 13, color: amber)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
            begin: 1.0, end: 1.25, duration: 900.ms, curve: Curves.easeInOut);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDone ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.07),
          border: Border(left: BorderSide(color: amber, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phoenix banner
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 2),
              child: Row(
                children: [
                  fireIcon,
                  const SizedBox(width: 6),
                  Text('PHOENIX',
                      style: GoogleFonts.rajdhani(
                          color: amber,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold)),
                  if (isDone) ...[
                    const SizedBox(width: 8),
                    Text('· RISEN',
                            style: TextStyle(
                                color: AppTheme.fhAccentGreen,
                                fontSize: 9,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold))
                        .animate()
                        .fadeIn(duration: 250.ms),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: onDemote,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('DEMOTE',
                          style: TextStyle(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 9,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: AppTheme.fhTextSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(parent,
                            style:   TextStyle(
                                color: AppTheme.fhTextSecondary, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                if (!isDone) ...[
                  _EstimateChip(
                    minutes: minutes,
                    isCustom: isCustomEstimate,
                    accent: amber,
                    onTap: onEditEstimate,
                  ),
                  IconButton(
                    icon: Icon(
                      hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                      size: 18,
                      color: hasReminder ? amber : AppTheme.fhTextSecondary,
                    ),
                    onPressed: onEditReminder,
                    splashRadius: 18,
                    tooltip: 'Reminder',
                  ),
                  IconButton(
                    icon:   Icon(Icons.check, size: 18, color: AppTheme.fhAccentTeal),
                    onPressed: onCheck,
                    splashRadius: 18,
                    tooltip: 'Complete Task',
                  ),
                ],
                IconButton(
                  icon:   Icon(Icons.close, size: 18, color: AppTheme.fhAccentRed),
                  onPressed: onRemove,
                  splashRadius: 18,
                  tooltip: 'Remove from plan',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  final String title;
  final String? parent;
  final Color color;
  final bool isCheckpoint;
  final int plannedCount;
  final VoidCallback onAdd;

  const _AvailableRow({
    required this.title,
    this.parent,
    required this.color,
    required this.isCheckpoint,
    required this.plannedCount,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
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
            Icon(
              isCheckpoint ? MdiIcons.rhombusOutline : MdiIcons.targetAccount,
              size: isCheckpoint ? 14 : 16,
              color: isCheckpoint ? AppTheme.fhTextSecondary : color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppTheme.fhTextPrimary,
                          fontSize: isCheckpoint ? 12 : 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (parent != null)
                    Text(parent!,
                        style:   TextStyle(
                            color: AppTheme.fhTextDisabled, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (plannedCount > 0)
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

  const _AddSection({
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.child,
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
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style:   TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search…',
                            hintStyle:   TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13),
                            prefixIcon:   Icon(Icons.search,
                                size: 16, color: AppTheme.fhTextSecondary),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 32, minHeight: 32),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            enabledBorder:   UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                            focusedBorder:   UnderlineInputBorder(
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
