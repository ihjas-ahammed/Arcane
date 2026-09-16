import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:provider/provider.dart';

class CreateGoalSheet extends StatefulWidget {
  final GoalScope initialScope;
  final DateTime selectedDate;
  final GoalModel? goalToEdit;

  const CreateGoalSheet({
    super.key,
    required this.initialScope,
    required this.selectedDate,
    this.goalToEdit,
  });

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  final _titleController = TextEditingController();
  final _filterController = TextEditingController();
  final _targetValueController = TextEditingController();
  late GoalScope _selectedScope;
  GoalMetricType _selectedMetric = GoalMetricType.check;
  double _targetValue = 1.0;
  bool _isRecurring = false;
  DateTime? _startDateTime;
  final Set<String> _selectedTaskIds = {};
  String _taskSearchQuery = '';
  final Map<String, bool> _expandedTasks = {};
  final List<String> _initialSubItems = [];
  final _newSubController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.goalToEdit?.scope ?? widget.initialScope;
    _startDateTime = widget.goalToEdit?.startDateTime ?? widget.selectedDate;
    if (widget.goalToEdit != null) {
      final g = widget.goalToEdit!;
      _titleController.text = g.title;
      _selectedMetric = g.metricType;
      _targetValue = g.targetValue;
      _targetValueController.text = g.targetValue.toInt().toString();
      _isRecurring = g.isRecurring;
      _selectedTaskIds.addAll(g.linkedTaskIds);
      _initialSubItems.addAll(g.subChecklist.map((s) => s.title));
    } else {
      _targetValueController.text = '1';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _filterController.dispose();
    _targetValueController.dispose();
    _newSubController.dispose();
    super.dispose();
  }

  void _onTargetValueInputChanged(String text) {
    final val = double.tryParse(text);
    if (val != null && val > 0) {
      setState(() {
        _targetValue = val;
      });
    }
  }

  void _onSliderChanged(double val) {
    setState(() {
      _targetValue = val;
      _targetValueController.text = val.toInt().toString();
    });
  }

  void _saveGoal(AppProvider provider) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showGlobalToast('Please enter a goal title');
      return;
    }

    final periodKey = GoalModel.getPeriodKey(
        _selectedScope, _startDateTime ?? DateTime.now());

    if (widget.goalToEdit != null) {
      final existingGoal = widget.goalToEdit!;
      final existingSubTitles =
          existingGoal.subChecklist.map((s) => s.title).toSet();
      final updatedSubChecklist =
          List<GoalSubCheckItem>.from(existingGoal.subChecklist);

      for (var t in _initialSubItems) {
        if (!existingSubTitles.contains(t)) {
          updatedSubChecklist.add(GoalSubCheckItem(
            id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${t.hashCode}',
            title: t,
            isCompleted: false,
          ));
        }
      }

      final updatedGoal = existingGoal.copyWith(
        title: title,
        scope: _selectedScope,
        metricType: _selectedMetric,
        targetValue: _targetValue <= 0 ? 1.0 : _targetValue,
        startDateTime: _startDateTime,
        linkedTaskIds: _selectedTaskIds.toList(),
        dateKey: periodKey,
        isRecurring: _isRecurring,
        subChecklist: updatedSubChecklist,
      );

      provider.updateGoal(updatedGoal);
      Navigator.of(context).pop();
      showGlobalToast('Goal updated!');
    } else {
      final subItems = _initialSubItems
          .map((t) => GoalSubCheckItem(
                id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${t.hashCode}',
                title: t,
                isCompleted: false,
              ))
          .toList();

      final goal = GoalModel(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        scope: _selectedScope,
        metricType: _selectedMetric,
        targetValue: _targetValue <= 0 ? 1.0 : _targetValue,
        startDateTime: _startDateTime,
        linkedTaskIds: _selectedTaskIds.toList(),
        xpReward: 50,
        dateKey: periodKey,
        isRecurring: _isRecurring,
        subChecklist: subItems,
      );

      provider.addGoal(goal);
      Navigator.of(context).pop();
      showGlobalToast('New Goal Initialized!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;
    final themeColor =
        appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);

    final activeTasks = appProvider.mainTasks
        .where((t) => t.isActive && !t.isDeleted)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: sheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: themeColor, width: 1.5),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.goalToEdit != null
                        ? 'EDIT GOAL PROTOCOL'
                        : 'INITIALIZE NEW GOAL',
                    style: GoogleFonts.orbitron(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.goalToEdit != null)
                        IconButton(
                          icon: Icon(MdiIcons.deleteOutline,
                              size: 20, color: JweTheme.accentRed),
                          tooltip: 'Delete Goal',
                          onPressed: () {
                            Navigator.of(context).pop();
                            appProvider.deleteGoal(widget.goalToEdit!.id);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title Field
              TextField(
                controller: _titleController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'GOAL TITLE',
                  hintText: 'e.g., Complete 3 Coding Checkpoints',
                  labelStyle:
                      GoogleFonts.orbitron(fontSize: 10, color: themeColor),
                  filled: true,
                  fillColor: isLight
                      ? const Color(0xFFEDE9DF)
                      : const Color(0xFF14151E),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Scope Selector
              Text(
                'TARGET SCOPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalScope.values.map((scope) {
                  final selected = scope == _selectedScope;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          scope.name.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? (isLight ? Colors.white : Colors.black)
                                : (isLight
                                    ? const Color(0xFF475569)
                                    : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) =>
                            setState(() => _selectedScope = scope),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Metric Type Selector
              Text(
                'METRIC TYPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalMetricType.values.map((metric) {
                  final selected = metric == _selectedMetric;
                  String label = 'CHECK';
                  if (metric == GoalMetricType.counter) label = 'COUNTER';
                  if (metric == GoalMetricType.timeCounter) {
                    label = 'TIME COUNTER';
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          label,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? (isLight ? Colors.white : Colors.black)
                                : (isLight
                                    ? const Color(0xFF475569)
                                    : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) =>
                            setState(() => _selectedMetric = metric),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Metric Specific Settings (Slider + Manual Input)
              if (_selectedMetric == GoalMetricType.counter) ...[
                Text(
                  'TARGET COUNT',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Slider(
                        value: _targetValue.clamp(1.0, 100.0),
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        activeColor: themeColor,
                        onChanged: _onSliderChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _targetValueController,
                        keyboardType: TextInputType.number,
                        onChanged: _onTargetValueInputChanged,
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'COUNT',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedMetric == GoalMetricType.timeCounter) ...[
                Text(
                  'TARGET TIME DURATION (MINUTES)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Slider(
                        value: _targetValue.clamp(5.0, 480.0),
                        min: 5.0,
                        max: 480.0,
                        divisions: 95,
                        activeColor: themeColor,
                        onChanged: _onSliderChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _targetValueController,
                        keyboardType: TextInputType.number,
                        onChanged: _onTargetValueInputChanged,
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'MINS',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Recurring Toggle Switch
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: themeColor,
                title: Text(
                  'RECUR EVERY PERIOD (CLEAN SHEET)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Auto-creates a fresh goal instance for each new day/week/month',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    color: isLight ? Colors.black45 : Colors.white38,
                  ),
                ),
                value: _isRecurring,
                onChanged: (val) => setState(() => _isRecurring = val),
              ),
              const SizedBox(height: 12),

              // INITIAL SUBCHECKLIST CREATION (ONLY FOR CHECK GOALS)
              if (_selectedMetric == GoalMetricType.check) ...[
                Text(
                  'SUBCHECKLIST TASKS (OPTIONAL)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _initialSubItems.map((item) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeColor.withValues(alpha: 0.15),
                      side: BorderSide(color: themeColor),
                      label: Text(
                        item,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() => _initialSubItems.remove(item));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubController,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type sub-task & press Add...',
                          isDense: true,
                          filled: true,
                          fillColor: isLight
                              ? const Color(0xFFEDE9DF)
                              : const Color(0xFF14151E),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        final t = _newSubController.text.trim();
                        if (t.isNotEmpty) {
                          setState(() {
                            _initialSubItems.add(t);
                            _newSubController.clear();
                          });
                        }
                      },
                      child: const Text('ADD'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // PLANNER-STYLE TASK SELECTOR
              Text(
                'LINK TASKS (OPTIONAL)',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),

              if (_selectedTaskIds.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedTaskIds.map<Widget>((id) {
                    final label = _getTaskNameById(activeTasks, id);
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeColor.withValues(alpha: 0.18),
                      side: BorderSide(color: themeColor),
                      label: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() => _selectedTaskIds.remove(id));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              TextField(
                controller: _filterController,
                onChanged: (v) =>
                    setState(() => _taskSearchQuery = v.trim().toLowerCase()),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter tasks...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: isLight
                      ? const Color(0xFFEDE9DF)
                      : const Color(0xFF14151E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: themeColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFEDE9DF)
                      : const Color(0xFF14151E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.12)
                        : JweTheme.lineSoft.withValues(alpha: 0.5),
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children:
                      _buildTaskTreeNodes(activeTasks, themeColor, isLight),
                ),
              ),
              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: () => _saveGoal(appProvider),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  backgroundColor: themeColor,
                  foregroundColor: isLight ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  widget.goalToEdit != null ? 'SAVE GOAL' : 'CREATE GOAL',
                  style: GoogleFonts.orbitron(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  String _getTaskNameById(List<MainTask> tasks, String id) {
    for (var main in tasks) {
      if (main.id == id) return main.name;
      for (var sub in main.subTasks) {
        final subCompound = '${main.id}|${sub.id}';
        if (sub.id == id || subCompound == id) {
          return '${main.name} → ${sub.name}';
        }
      }
    }
    return id;
  }

  List<Widget> _buildTaskTreeNodes(
      List<MainTask> tasks, Color themeColor, bool isLight) {
    final List<Widget> nodes = [];
    final q = _taskSearchQuery;

    for (var main in tasks) {
      final activeSubs = main.subTasks.where((s) => !s.isDeleted).toList();
      final bool mainMatch = q.isEmpty || main.name.toLowerCase().contains(q);

      final matchingSubs = activeSubs.where((sub) {
        if (mainMatch) return true;
        return sub.name.toLowerCase().contains(q);
      }).toList();

      if (!mainMatch && matchingSubs.isEmpty) continue;

      final isExpanded = _expandedTasks[main.id] ?? (q.isNotEmpty);
      final isMainSelected = _selectedTaskIds.contains(main.id);

      nodes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: main.taskColor.withValues(alpha: isLight ? 0.08 : 0.14),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18,
                      color: main.taskColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _expandedTasks[main.id] = !isExpanded;
                      });
                    },
                  ),
                  Checkbox(
                    value: isMainSelected,
                    activeColor: main.taskColor,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTaskIds.add(main.id);
                        } else {
                          _selectedTaskIds.remove(main.id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      main.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: main.taskColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${matchingSubs.length} subtask(s)',
                      style: GoogleFonts.orbitron(
                          fontSize: 9, color: main.taskColor),
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: matchingSubs.map((sub) {
                    final subCompound = '${main.id}|${sub.id}';
                    final isSubSelected = _selectedTaskIds.contains(sub.id) ||
                        _selectedTaskIds.contains(subCompound);

                    return CheckboxListTile(
                      dense: true,
                      title: Text(
                        sub.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isLight ? Colors.black87 : Colors.white70,
                        ),
                      ),
                      activeColor: main.taskColor,
                      value: isSubSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTaskIds.add(subCompound);
                          } else {
                            _selectedTaskIds.remove(subCompound);
                            _selectedTaskIds.remove(sub.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }

    if (nodes.isEmpty) {
      nodes.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No active tasks found',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: JweTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return nodes;
  }
}
