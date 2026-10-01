import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
  bool _countAllTime = false;
  DateTime? _startDateTime;
  final Set<String> _selectedTaskIds = {};
  String _taskSearchQuery = '';
  final Map<String, bool> _expandedTasks = {};
  final List<String> _initialSubItems = [];
  final _newSubController = TextEditingController();
  List<String> _reminderTimes = [];
  String? _selectedPlaceId;

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
      _countAllTime = g.countAllTime;
      _selectedTaskIds.addAll(g.linkedTaskIds);
      _initialSubItems.addAll(g.subChecklist.map((s) => s.title));
      _reminderTimes = List.from(g.reminderTimes);
      _selectedPlaceId = g.placeId;
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
        countAllTime: _countAllTime,
        reminderTimes: _selectedScope == GoalScope.daily ? _reminderTimes : const [],
        placeId: _selectedPlaceId,
        clearPlaceId: _selectedPlaceId == null,
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
        countAllTime: _countAllTime,
        reminderTimes: _selectedScope == GoalScope.daily ? _reminderTimes : const [],
        placeId: _selectedPlaceId,
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
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDateTime ?? widget.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (context, child) {
                        return Theme(
                          data: isLight
                              ? ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: themeColor,
                                    onPrimary: JweTheme.onAccent,
                                    surface: const Color(0xFFF6F3EC),
                                    onSurface: Colors.black87,
                                  ),
                                )
                              : ThemeData.dark().copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: themeColor,
                                    onPrimary: JweTheme.onAccent,
                                    surface: const Color(0xFF141923),
                                    onSurface: Colors.white,
                                  ),
                                ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _startDateTime = DateTime(picked.year, picked.month, picked.day);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFEFECE6) : const Color(0xFF12151D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(MdiIcons.calendarClock, size: 16, color: themeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GOAL START DATE (12:00 AM THRESHOLD)',
                                style: GoogleFonts.orbitron(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('yyyy-MM-dd (EEEE)').format(_startDateTime ?? widget.selectedDate),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isLight ? Colors.black87 : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar, size: 16, color: themeColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: themeColor,
                  value: _countAllTime,
                  onChanged: (val) => setState(() => _countAllTime = val),
                  title: Text(
                    'INCLUDE ALL-TIME TASK DURATION',
                    style: GoogleFonts.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.black87 : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    _countAllTime
                        ? 'Counting all historical time logged on linked tasks'
                        : 'Default: Only counts time logged on/after ${DateFormat('yyyy-MM-dd').format(_startDateTime ?? widget.selectedDate)} 12:00 AM',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      color: isLight ? Colors.black54 : Colors.white54,
                    ),
                  ),
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
              const SizedBox(height: 14),

              // PLACE / CONTEXT SELECTOR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PLACE / CONTEXT (OPTIONAL)',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isLight ? const Color(0xFF475569) : Colors.white60,
                    ),
                  ),
                  InkWell(
                    onTap: () => _showManagePlacesDialog(context, appProvider),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 12, color: themeColor),
                          const SizedBox(width: 3),
                          Text(
                            'EDIT PLACES',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...appProvider.goalPlaces.map((place) {
                    final selected = _selectedPlaceId == place.id;
                    final placeColor = Color(place.colorValue);
                    return ChoiceChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected
                              ? placeColor
                              : (isLight
                                  ? Colors.black.withValues(alpha: 0.15)
                                  : Colors.white24),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      avatar: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: placeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(
                        place.name.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? (isLight ? Colors.black87 : Colors.white)
                              : (isLight ? const Color(0xFF475569) : Colors.white60),
                        ),
                      ),
                      selected: selected,
                      selectedColor: placeColor.withValues(alpha: isLight ? 0.22 : 0.28),
                      backgroundColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                      onSelected: (val) {
                        setState(() {
                          _selectedPlaceId = val ? place.id : null;
                        });
                      },
                    );
                  }),
                  ActionChip(
                    avatar: Icon(Icons.add, size: 14, color: themeColor),
                    label: Text(
                      'NEW PLACE',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
                    ),
                    backgroundColor: themeColor.withValues(alpha: 0.08),
                    onPressed: () => _showAddPlaceDialog(context, appProvider),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // CONTEMPLATION & REMINDERS (DAILY ONLY)
              if (_selectedScope == GoalScope.daily) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'THINK ABOUT IT // CONTEMPLATION TIME',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLight ? const Color(0xFF475569) : Colors.white60,
                      ),
                    ),
                    InkWell(
                      onTap: () => _pickContemplationTime(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_alarm, size: 13, color: themeColor),
                            const SizedBox(width: 3),
                            Text(
                              '+ ADD TIME',
                              style: GoogleFonts.orbitron(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Daily reflection cue to plan execution. Features a 2-hour snooze button.',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: isLight ? Colors.black54 : Colors.white54,
                  ),
                ),
                const SizedBox(height: 6),
                if (_reminderTimes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLight ? Colors.black12 : Colors.white12,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _pickContemplationTime(context),
                      child: Row(
                        children: [
                          Icon(Icons.alarm, size: 14, color: isLight ? Colors.black45 : Colors.white38),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No reminder set. Tap "+ ADD TIME" to schedule contemplation.',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                color: isLight ? Colors.black45 : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _reminderTimes.map((t) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.access_time, size: 14, color: themeColor),
                        backgroundColor: themeColor.withValues(alpha: 0.15),
                        side: BorderSide(color: themeColor),
                        label: Text(
                          t,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _reminderTimes.remove(t);
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 14),
              ],

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

  Future<void> _pickContemplationTime(BuildContext context) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final formatted = '$hourStr:$minuteStr';
      if (!_reminderTimes.contains(formatted)) {
        setState(() {
          _reminderTimes.add(formatted);
          _reminderTimes.sort();
        });
      }
    }
  }

  void _showAddPlaceDialog(BuildContext context, AppProvider appProvider) {
    final isLight = JweTheme.isLight;
    final nameController = TextEditingController();
    int selectedColor = 0xFF10B981;
    final presetColors = [
      0xFF10B981, // Emerald
      0xFFFFB547, // Amber
      0xFF8B5CF6, // Purple
      0xFF00E5FF, // Cyan
      0xFFEF4444, // Red
      0xFF3B82F6, // Blue
      0xFFF97316, // Orange
      0xFFEC4899, // Pink
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
          return AlertDialog(
            backgroundColor: isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: themeColor, width: 1.2),
            ),
            title: Text(
              'ADD NEW PLACE',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PLACE NAME',
                    hintText: 'e.g. Gym, Library, Studio',
                    labelStyle: GoogleFonts.orbitron(fontSize: 10, color: themeColor),
                    filled: true,
                    fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'COLOR TOKEN',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetColors.map((colorVal) {
                    final isSel = selectedColor == colorVal;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = colorVal),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? (isLight ? Colors.black87 : Colors.white)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('CANCEL', style: GoogleFonts.orbitron(fontSize: 11)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: isLight ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final id = 'place_${DateTime.now().millisecondsSinceEpoch}';
                    final newPlace = GoalPlace(
                      id: id,
                      name: name,
                      colorValue: selectedColor,
                    );
                    appProvider.addGoalPlace(newPlace);
                    setState(() {
                      _selectedPlaceId = id;
                    });
                    Navigator.of(ctx).pop();
                    showGlobalToast('Place "$name" added!');
                  }
                },
                child: Text('ADD', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManagePlacesDialog(BuildContext context, AppProvider appProvider) {
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final places = appProvider.goalPlaces;
          return Material(
            color: isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14),
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              side: BorderSide(color: themeColor, width: 1.5),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MANAGE PLACES',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...places.map((place) {
                    final placeColor = Color(place.colorValue);
                    final isDefault = GoalPlace.defaultPlaces.any((dp) => dp.id == place.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: placeColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: placeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              place.name,
                              style: GoogleFonts.orbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLight ? Colors.black87 : Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.color_lens_outlined, size: 18, color: themeColor),
                            tooltip: 'Change color',
                            onPressed: () {
                              _showColorPickerDialog(context, appProvider, place, () {
                                setSheetState(() {});
                                setState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 16, color: themeColor),
                            tooltip: 'Edit name',
                            onPressed: () {
                              _showEditPlaceNameDialog(context, appProvider, place, () {
                                setSheetState(() {});
                                setState(() {});
                              });
                            },
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: JweTheme.accentRed),
                              tooltip: 'Delete place',
                              onPressed: () {
                                appProvider.deleteGoalPlace(place.id);
                                if (_selectedPlaceId == place.id) {
                                  setState(() => _selectedPlaceId = null);
                                }
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: themeColor,
                      foregroundColor: isLight ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'ADD CUSTOM PLACE',
                      style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAddPlaceDialog(context, appProvider);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPlaceNameDialog(BuildContext context, AppProvider appProvider, GoalPlace place, VoidCallback onUpdated) {
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
    final controller = TextEditingController(text: place.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeColor, width: 1.2),
        ),
        title: Text(
          'RENAME PLACE',
          style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: isLight ? Colors.black87 : Colors.white),
          decoration: InputDecoration(
            labelText: 'PLACE NAME',
            labelStyle: GoogleFonts.orbitron(fontSize: 10, color: themeColor),
            filled: true,
            fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: GoogleFonts.orbitron(fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: isLight ? Colors.white : Colors.black,
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                appProvider.updateGoalPlace(place.copyWith(name: newName));
                onUpdated();
                Navigator.of(ctx).pop();
              }
            },
            child: Text('SAVE', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, AppProvider appProvider, GoalPlace place, VoidCallback onUpdated) {
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
    final presetColors = [
      0xFF10B981, 0xFFFFB547, 0xFF8B5CF6, 0xFF00E5FF,
      0xFFEF4444, 0xFF3B82F6, 0xFFF97316, 0xFFEC4899,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeColor, width: 1.2),
        ),
        title: Text(
          'SELECT COLOR FOR ${place.name.toUpperCase()}',
          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
        ),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: presetColors.map((c) {
            final isSel = place.colorValue == c;
            return InkWell(
              onTap: () {
                appProvider.updateGoalPlace(place.copyWith(colorValue: c));
                onUpdated();
                Navigator.of(ctx).pop();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSel ? (isLight ? Colors.black87 : Colors.white) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
