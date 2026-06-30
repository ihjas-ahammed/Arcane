import 'package:flutter/material.dart';
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

class TodayPlannerScreen extends StatefulWidget {
  const TodayPlannerScreen({super.key});

  @override
  State<TodayPlannerScreen> createState() => _TodayPlannerScreenState();
}

class _TodayPlannerScreenState extends State<TodayPlannerScreen> {
  late String _date;
  List<String> _plan = [];
  Map<String, int> _estimates = {};
  bool _addExpanded = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _date = helper.getTodayDateString();
      final provider = Provider.of<AppProvider>(context, listen: false);
      _plan = provider.taskActions.getDayPlan(_date);
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
    provider.taskActions.updateDayPlan(_date, _plan);
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

  void _addToPlan(AppProvider provider, String compoundId) {
    if (_plan.contains(compoundId)) return;
    setState(() {
      _plan.add(compoundId);
      // If we just added a subtask, drop any of its child checkpoints from the plan
      final parts = compoundId.split('|');
      if (parts.length == 2) {
        _plan.removeWhere((id) {
          final p = id.split('|');
          return p.length == 3 && p[0] == parts[0] && p[1] == parts[1];
        });
      }
    });
    _persistPlan(provider);
  }

  void _removeFromPlan(AppProvider provider, String compoundId) {
    setState(() {
      _plan.remove(compoundId);
    });
    _persistPlan(provider); // updateDayPlan auto-clears a Phoenix that left the plan
  }

  void _togglePhoenix(AppProvider provider, String compoundId) {
    final current = provider.taskActions.getPhoenixId(_date);
    if (current == compoundId) {
      provider.taskActions.setPhoenix(_date, null);
    } else {
      // Pin to the front so the Phoenix reads as the first thing of the day.
      setState(() {
        _plan.remove(compoundId);
        _plan.insert(0, compoundId);
      });
      _persistPlan(provider);
      provider.taskActions.setPhoenix(_date, compoundId);
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
                    labelStyle: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    onSelected: (_) => Navigator.pop(ctx, preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.fhTextPrimary),
                decoration: const InputDecoration(
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
                child: const Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary))),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? current;
                Navigator.pop(ctx, v.clamp(0, 600));
              },
              child: const Text('SET', style: TextStyle(color: AppTheme.fhAccentTeal)),
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
            style: const TextStyle(color: AppTheme.fhTextSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'clear'),
                child: const Text('CLEAR',
                    style: TextStyle(color: AppTheme.fhAccentRed))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'change'),
                child: const Text('CHANGE',
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
    final base = existing ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await provider.setPlannerReminder(compoundId, when);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reminder set for ${DateFormat('MMM d · hh:mm a').format(when)}'),
      backgroundColor: AppTheme.fhAccentTeal.withValues(alpha: 0.9),
    ));
  }

  ({String? title, Color? color, bool isRunning}) _resolveActive(AppProvider provider) {
    for (final id in _plan) {
      final parts = id.split('|');
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
    final plannedMinutes =
        _plan.fold<int>(0, (sum, id) => sum + _estimateFor(id, provider));
    final active = _resolveActive(provider);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text('TODAY',
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhAccentTeal,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.fhTextPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _BudgetBar(
              plannedMinutes: plannedMinutes,
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
    if (_plan.isEmpty) {
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
            const Text('Open ADD below to queue work.',
                style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
          ],
        ),
      );
    }

    final phoenixId = provider.taskActions.getPhoenixId(_date);
    final hasPhoenix = phoenixId != null && _plan.contains(phoenixId);
    final queue = _plan.where((id) => id != phoenixId).toList();

    final list = ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: queue.length,
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;
        setState(() {
          final item = queue.removeAt(oldIndex);
          queue.insert(newIndex, item);
          _plan = [if (hasPhoenix) phoenixId!, ...queue];
        });
        _persistPlan(provider);
      },
      itemBuilder: (context, index) {
        final id = queue[index];
        return _PlanRow(
          key: ValueKey(id),
          compoundId: id,
          provider: provider,
          minutes: _estimateFor(id, provider),
          isCustomEstimate: _estimates.containsKey(id),
          hasReminder: provider.plannerReminderTime(id) != null,
          onEditEstimate: () => _editEstimate(provider, id),
          onEditReminder: () => _editReminder(provider, id),
          onRemove: () => _removeFromPlan(provider, id),
          onAnoint: () => _togglePhoenix(provider, id),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhoenix)
          _PhoenixCard(
            compoundId: phoenixId!,
            provider: provider,
            minutes: _estimateFor(phoenixId, provider),
            isCustomEstimate: _estimates.containsKey(phoenixId),
            hasReminder: provider.plannerReminderTime(phoenixId) != null,
            onEditEstimate: () => _editEstimate(provider, phoenixId!),
            onEditReminder: () => _editReminder(provider, phoenixId!),
            onRemove: () => _removeFromPlan(provider, phoenixId!),
            onDemote: () => _togglePhoenix(provider, phoenixId!),
          )
        else
          const _AnointHint(),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildAvailableList(AppProvider provider) {
    final planSet = _plan.toSet();
    final activeTasks =
        provider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
    final q = _searchQuery;
    final widgets = <Widget>[];

    for (final task in activeTasks) {
      final activeSubs =
          task.subTasks.where((s) => !s.completed && !s.isDeleted).toList();
      if (activeSubs.isEmpty) continue;

      final taskRows = <Widget>[];

      for (final sub in activeSubs) {
        final subId = '${task.id}|${sub.id}';
        final activeCps = _getAllIncompleteCheckpoints(sub);
        final allCpIds =
            activeCps.map((c) => '$subId|${c.id}').toList();
        final subInPlan = planSet.contains(subId);
        final allCpsInPlan = activeCps.isNotEmpty &&
            allCpIds.every((id) => planSet.contains(id));

        if (!subInPlan && !allCpsInPlan && _matchesQuery(sub.name, q)) {
          taskRows.add(_AvailableRow(
            title: sub.name,
            color: task.taskColor,
            isCheckpoint: false,
            onAdd: () => _addToPlan(provider, subId),
          ));
        }

        if (!subInPlan) {
          for (final cp in activeCps) {
            final cpId = '$subId|${cp.id}';
            if (planSet.contains(cpId)) continue;
            if (!_matchesQuery(cp.name, q) && !_matchesQuery(sub.name, q)) continue;
            taskRows.add(_AvailableRow(
              title: cp.name,
              parent: _findParentPath(sub, cp),
              color: task.taskColor,
              isCheckpoint: true,
              onAdd: () => _addToPlan(provider, cpId),
            ));
          }
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
            style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
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

class _BudgetBar extends StatelessWidget {
  final int plannedMinutes;
  final int minutesLeft;
  final int realisticMinutes;
  final bool fromHistory;

  const _BudgetBar({
    required this.plannedMinutes,
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
      decoration: const BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatMinutes(plannedMinutes),
                  style: GoogleFonts.rajdhani(
                      color: AppTheme.fhTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1)),
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
              child: Stack(children: [
                Container(color: AppTheme.fhBgDeepDark),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(color: color),
                ),
              ]),
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, color: color),
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
            child: Text(
              title,
              style: const TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String compoundId;
  final AppProvider provider;
  final int minutes;
  final bool isCustomEstimate;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onEditReminder;
  final VoidCallback onRemove;
  final VoidCallback onAnoint;

  const _PlanRow({
    super.key,
    required this.compoundId,
    required this.provider,
    required this.minutes,
    required this.isCustomEstimate,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onEditReminder,
    required this.onRemove,
    required this.onAnoint,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(left: BorderSide(color: task.taskColor, width: 3)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_indicator,
                color: AppTheme.fhTextDisabled, size: 18),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(parent,
                      style: const TextStyle(
                          color: AppTheme.fhTextSecondary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onEditEstimate,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDeepDark,
                border: Border.all(
                    color: isCustomEstimate
                        ? AppTheme.fhAccentTeal.withOpacity(0.6)
                        : AppTheme.fhBorderColor),
              ),
              child: Text(formatMinutes(minutes),
                  style: TextStyle(
                      color: isCustomEstimate
                          ? AppTheme.fhAccentTeal
                          : AppTheme.fhTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
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
            icon: const Icon(Icons.close, size: 18, color: AppTheme.fhAccentRed),
            onPressed: onRemove,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _AnointHint extends StatelessWidget {
  const _AnointHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.fhAccentOrange.withOpacity(0.05),
        border: Border.all(
            color: AppTheme.fhAccentOrange.withOpacity(0.35),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.fireCircle, size: 16, color: AppTheme.fhAccentOrange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Anoint your Phoenix — the one thing that must rise today.',
                style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

class _PhoenixCard extends StatelessWidget {
  final String compoundId;
  final AppProvider provider;
  final int minutes;
  final bool isCustomEstimate;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onEditReminder;
  final VoidCallback onRemove;
  final VoidCallback onDemote;

  const _PhoenixCard({
    required this.compoundId,
    required this.provider,
    required this.minutes,
    required this.isCustomEstimate,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onEditReminder,
    required this.onRemove,
    required this.onDemote,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: amber.withOpacity(0.07),
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
                Icon(MdiIcons.fire, size: 13, color: amber),
                const SizedBox(width: 6),
                Text('PHOENIX',
                    style: GoogleFonts.rajdhani(
                        color: amber,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold)),
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
                          style: const TextStyle(
                              color: AppTheme.fhTextPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(parent,
                          style: const TextStyle(
                              color: AppTheme.fhTextSecondary, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onEditEstimate,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDeepDark,
                    border: Border.all(
                        color: isCustomEstimate
                            ? amber.withOpacity(0.6)
                            : AppTheme.fhBorderColor),
                  ),
                  child: Text(formatMinutes(minutes),
                      style: TextStyle(
                          color: isCustomEstimate ? amber : AppTheme.fhTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
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
                icon: const Icon(Icons.close, size: 18, color: AppTheme.fhAccentRed),
                onPressed: onRemove,
                splashRadius: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  final String title;
  final String? parent;
  final Color color;
  final bool isCheckpoint;
  final VoidCallback onAdd;

  const _AvailableRow({
    required this.title,
    this.parent,
    required this.color,
    required this.isCheckpoint,
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
          color: AppTheme.fhBgDark.withOpacity(isCheckpoint ? 0.4 : 0.7),
          border: Border(
              left: BorderSide(color: color.withOpacity(isCheckpoint ? 0.4 : 1.0), width: 2)),
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
                        style: const TextStyle(
                            color: AppTheme.fhTextDisabled, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.add, color: AppTheme.fhAccentTeal, size: 18),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: expanded ? 340 : 52,
      decoration: const BoxDecoration(
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
                    Icon(
                      expanded ? Icons.expand_more : Icons.expand_less,
                      color: AppTheme.fhTextSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search…',
                  hintStyle: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppTheme.fhTextSecondary),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ],
      ),
    );
  }
}

List<SubSubTask> _getAllIncompleteCheckpoints(SubTask sub) {
  final List<SubSubTask> result = [];
  void recurse(List<SubSubTask> currentList) {
    for (final cp in currentList) {
      if (!cp.completed) {
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
