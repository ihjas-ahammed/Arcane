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

export 'today/today.dart';
import 'today/today.dart';

typedef _PlanCheckpoint = PlanCheckpoint;
typedef _PlanEntry = PlanEntry;
typedef _PlanRowData = PlanRowData;
typedef _LeaveKind = LeaveKind;

const _getAllCheckpointsForPlanning = getAllCheckpointsForPlanning;

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
  final Set<String> _expandedCheckpointEntries = {};

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
          return _PlanRowData(row.map((id) => _PlanEntry(id)).toList());
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
    final result = await TodayEstimateReminderDialogs.showEditEstimateDialog(context, current);
    if (result != null) {
      _setEstimate(provider, compoundId, result);
    }
  }

  Future<void> _editReminder(AppProvider provider, String compoundId) async {
    await TodayEstimateReminderDialogs.showEditReminderDialog(context, provider, compoundId);
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
                  painter: TacticalBackgroundPainter(),
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
            AddSection(
              expanded: _addExpanded,
              onToggle: () => setState(() => _addExpanded = !_addExpanded),
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              activeTab: _activeAddTab,
              onTabChanged: (val) => setState(() => _activeAddTab = val),
              child: _activeAddTab == 0
                  ? _buildAvailableList(provider)
                  : TodayRoutinesView(
                      provider: provider,
                      searchQuery: _searchQuery,
                      onAddRoutineToPlan: (routine) => _addRoutineToPlan(provider, routine),
                    ),
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

    return ReorderableListView.builder(
      key: _planListKey,
      scrollController: _planScrollController,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _rows.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _rows.removeAt(oldIndex);
          _rows.insert(newIndex.clamp(0, _rows.length), item);
        });
        _persistPlan(provider);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: JweTheme.isLight ? 0.2 : 0.6),
          child: child,
        );
      },
      footer: const TacticalFooter(),
      itemBuilder: (context, index) {
        return _buildTaskRow(provider, _rows[index], index);
      },
    );
  }

  Widget _buildAvailableList(AppProvider provider) {
    final plannedCounts = <String, int>{};
    for (final entry in _entries) {
      plannedCounts[entry.id] = (plannedCounts[entry.id] ?? 0) + 1;
    }
    final widgets = buildSelectableTaskTree(
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

  void _addRoutineToPlan(AppProvider provider, RoutineList routine) {
    setState(() {
      for (final compoundId in routine.taskIds) {
        _rows.add(_PlanRowData([_PlanEntry(compoundId, addedAtRuntime: true)]));
      }
    });
    _persistPlan(provider);
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

    return Container(
      key: ValueKey(rowData.key),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ReorderableDelayedDragStartListener(
        index: rowIndex,
        child: content,
      ),
    );
  }

  String _resolveSubTaskName(AppProvider provider, String compoundId) {
    final parts = compoundId.split('|');
    if (parts.length < 2) return 'Mission';
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    return sub?.name ?? 'Mission';
  }

  Widget _buildTacticalCard1(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    return TacticalCard1(
      provider: provider,
      entry: entry,
      rowIndex: rowIndex,
      colIndex: colIndex,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      minutes: _estimateFor(entry.id, provider),
      isCustomEstimate: _estimates.containsKey(entry.id),
      isDone: _isEntryDone(provider, entry.id),
      hasReminder: provider.plannerReminderTime(entry.id) != null,
      onEditEstimate: () => _editEstimate(provider, entry.id),
      onRemoveFromPlan: () => _removeFromPlan(provider, entry),
      onEditReminder: () => _editReminder(provider, entry.id),
      onCompletePlanItem: () => _completePlanItem(provider, entry),
      onMenuAction: (action) => _onCardMenuSelected(
        action: action,
        provider: provider,
        entry: entry,
        mainTaskId: entry.id.split('|').first,
        subTaskId: entry.id.split('|').length > 1 ? entry.id.split('|')[1] : '',
        subTaskName: _resolveSubTaskName(provider, entry.id),
        rowIndex: rowIndex,
      ),
      isSubtasksExpanded: _expandedCheckpointEntries.contains(entry.key),
      onToggleSubtasksExpanded: () {
        setState(() {
          if (_expandedCheckpointEntries.contains(entry.key)) {
            _expandedCheckpointEntries.remove(entry.key);
          } else {
            _expandedCheckpointEntries.add(entry.key);
          }
        });
      },
      onToggleCheckpoint: (cp) => _toggleCheckpoint(provider, entry, cp),
      onRemoveCheckpoint: (cp) => _removeCheckpoint(provider, entry, cp),
      onPromptAddCheckpoint: () => _promptAddSubtask(provider, entry),
    );
  }

  Widget _buildTacticalCard2(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    return TacticalCard2(
      provider: provider,
      entry: entry,
      rowIndex: rowIndex,
      colIndex: colIndex,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      minutes: _estimateFor(entry.id, provider),
      isCustomEstimate: _estimates.containsKey(entry.id),
      isDone: _isEntryDone(provider, entry.id),
      hasReminder: provider.plannerReminderTime(entry.id) != null,
      onEditEstimate: () => _editEstimate(provider, entry.id),
      onRemoveFromPlan: () => _removeFromPlan(provider, entry),
      onEditReminder: () => _editReminder(provider, entry.id),
      onCompletePlanItem: () => _completePlanItem(provider, entry),
      onMenuAction: (action) => _onCardMenuSelected(
        action: action,
        provider: provider,
        entry: entry,
        mainTaskId: entry.id.split('|').first,
        subTaskId: entry.id.split('|').length > 1 ? entry.id.split('|')[1] : '',
        subTaskName: _resolveSubTaskName(provider, entry.id),
        rowIndex: rowIndex,
      ),
      onShowSubtasksModal: () => _showSubtasksModal(
        provider,
        entry,
        _resolveSubTaskName(provider, entry.id),
      ),
    );
  }

  Widget _buildTacticalCard3(AppProvider provider, _PlanEntry entry, int rowIndex, int colIndex) {
    return TacticalCard3(
      provider: provider,
      entry: entry,
      rowIndex: rowIndex,
      colIndex: colIndex,
      leaving: _leaving[entry.key],
      onLeft: () => _finishLeave(provider, entry),
      minutes: _estimateFor(entry.id, provider),
      isCustomEstimate: _estimates.containsKey(entry.id),
      isDone: _isEntryDone(provider, entry.id),
      hasReminder: provider.plannerReminderTime(entry.id) != null,
      onEditEstimate: () => _editEstimate(provider, entry.id),
      onRemoveFromPlan: () => _removeFromPlan(provider, entry),
      onEditReminder: () => _editReminder(provider, entry.id),
      onCompletePlanItem: () => _completePlanItem(provider, entry),
      onMenuAction: (action) => _onCardMenuSelected(
        action: action,
        provider: provider,
        entry: entry,
        mainTaskId: entry.id.split('|').first,
        subTaskId: entry.id.split('|').length > 1 ? entry.id.split('|')[1] : '',
        subTaskName: _resolveSubTaskName(provider, entry.id),
        rowIndex: rowIndex,
      ),
      onShowSubtasksModal: () => _showSubtasksModal(
        provider,
        entry,
        _resolveSubTaskName(provider, entry.id),
      ),
    );
  }

  void _showSubtasksModal(AppProvider provider, _PlanEntry entry, String subTaskName) {
    showSubtasksModalBottomSheet(
      context: context,
      provider: provider,
      entry: entry,
      subTaskName: subTaskName,
      onToggleCheckpoint: (cp) => _toggleCheckpoint(provider, entry, cp),
      onRemoveCheckpoint: (cp) => _removeCheckpoint(provider, entry, cp),
      onPromptAdd: () => _promptAddSubtask(provider, entry),
    );
  }

  Future<void> _promptAddSubtask(AppProvider provider, _PlanEntry entry) async {
    await promptAddSubtaskDialog(
      context: context,
      onAdd: (name, minutes) async {
        _addCheckpoint(provider, entry, name, minutes);
        showGlobalToast('Checkpoint added');
      },
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
      case 'merge_top_row':
        _mergeToRow(provider, entry, rowIndex, -1);
        break;
      case 'merge_bottom_row':
        _mergeToRow(provider, entry, rowIndex, 1);
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

  void _mergeToRow(AppProvider provider, _PlanEntry entry, int currentRowIndex, int direction) {
    int actualRowIndex = _rows.indexWhere((r) => r.entries.any((e) => e.key == entry.key));
    if (actualRowIndex == -1) actualRowIndex = currentRowIndex;
    if (actualRowIndex < 0 || actualRowIndex >= _rows.length) return;

    final targetRowIndex = actualRowIndex + direction;
    if (targetRowIndex < 0) {
      showGlobalToast('No row above to merge into');
      return;
    }
    if (targetRowIndex >= _rows.length) {
      showGlobalToast('No row below to merge into');
      return;
    }

    final targetRow = _rows[targetRowIndex];
    if (targetRow.entries.length >= 3) {
      showGlobalToast('TACTICAL OVERLOAD: Maximum 3 missions allowed per row!');
      return;
    }

    setState(() {
      final currentRow = _rows[actualRowIndex];
      currentRow.entries.removeWhere((e) => e.key == entry.key);
      targetRow.entries.add(entry);
      if (currentRow.entries.isEmpty) {
        _rows.removeAt(actualRowIndex);
      }
    });

    _persistPlan(provider);
    showGlobalToast(direction < 0 ? 'Merged to top row' : 'Merged to bottom row');
  }
}
