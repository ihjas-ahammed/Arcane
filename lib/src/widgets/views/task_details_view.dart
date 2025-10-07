// lib/src/widgets/views/task_details_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskDetailsView extends StatefulWidget {
  const TaskDetailsView({super.key});

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView> {
  // State for new subtask form
  final _newSubtaskNameController = TextEditingController();
  bool _newSubtaskIsCountable = false;
  final _newSubtaskTargetCountController = TextEditingController(text: '10');

  // State for AI subquest generation form
  String _aiGenerationMode = 'text_list'; // default mode
  final _aiUserInputController = TextEditingController();
  final _aiNumSubquestsController = TextEditingController(text: '3');

  // State for new sub-subtask forms (keyed by parent subtask ID)
  final Map<String, TextEditingController> _newSubSubtaskNameControllers = {};
  final Map<String, bool> _newSubSubtaskIsCountableMap = {};
  final Map<String, TextEditingController>
      _newSubSubtaskTargetCountControllers = {};

  // Local state for editing current time/count (keyed by subtask/sub-subtask ID)
  final Map<String, TextEditingController> _localTimeControllers = {};
  final Map<String, TextEditingController> _localCountControllers =
      {}; // For subtasks
  final Map<String, TextEditingController> _localSubSubtaskCountControllers =
      {}; // For sub-subtasks

  late GameProvider gameProvider;
  MainTask? _currentTaskForInit;

  @override
  void initState() {
    super.initState();
    gameProvider = Provider.of<GameProvider>(context, listen: false);
    _initializeControllersForTask(gameProvider.getSelectedTask());
    // Add listener to re-initialize controllers if selected task changes
    gameProvider.addListener(_handleProviderChange);
  }

  @override
  void dispose() {
    _newSubtaskNameController.dispose();
    _newSubtaskTargetCountController.dispose();
    _aiUserInputController.dispose();
    _aiNumSubquestsController.dispose();
    _clearDynamicControllers();
    gameProvider.removeListener(_handleProviderChange);
    super.dispose();
  }

  void _clearDynamicControllers() {
    for (var controller in _newSubSubtaskNameControllers.values) {
      controller.dispose();
    }
    _newSubSubtaskNameControllers.clear();
    for (var controller in _newSubSubtaskTargetCountControllers.values) {
      controller.dispose();
    }
    _newSubSubtaskTargetCountControllers.clear();
    for (var controller in _localTimeControllers.values) {
      controller.dispose();
    }
    _localTimeControllers.clear();
    for (var controller in _localCountControllers.values) {
      controller.dispose();
    }
    _localCountControllers.clear();
    for (var controller in _localSubSubtaskCountControllers.values) {
      controller.dispose();
    }
    _localSubSubtaskCountControllers.clear();
    _newSubSubtaskIsCountableMap.clear();
  }

  void _handleProviderChange() {
    final selectedTask = gameProvider.getSelectedTask();
    if (_currentTaskForInit?.id != selectedTask?.id) {
      if (mounted) {
        setState(() {
          // Ensure UI rebuilds if task changes leading to different controllers
          _initializeControllersForTask(selectedTask);
        });
      } else {
        _initializeControllersForTask(selectedTask);
      }
    }
  }

  void _initializeControllersForTask(MainTask? task) {
    _clearDynamicControllers(); // Clear previous task's controllers
    _currentTaskForInit = task;

    if (task != null) {
      for (var st in task.subTasks) {
        _newSubSubtaskNameControllers[st.id] = TextEditingController();
        _newSubSubtaskIsCountableMap[st.id] = false;
        _newSubSubtaskTargetCountControllers[st.id] =
            TextEditingController(text: '5');
        _localTimeControllers[st.id] =
            TextEditingController(text: st.currentTimeSpent.toString());
        if (st.isCountable) {
          _localCountControllers[st.id] =
              TextEditingController(text: st.currentCount.toString());
        }
        for (var sss in st.subSubTasks) {
          if (sss.isCountable) {
            _localSubSubtaskCountControllers[sss.id] =
                TextEditingController(text: sss.currentCount.toString());
          }
        }
      }
    }
  }

  void _handleAddSubtask(GameProvider gameProvider, MainTask task) {
    if (_newSubtaskNameController.text.trim().isNotEmpty) {
      final subtaskData = {
        'name': _newSubtaskNameController.text.trim(),
        'isCountable': _newSubtaskIsCountable,
        'targetCount': _newSubtaskIsCountable
            ? (int.tryParse(_newSubtaskTargetCountController.text) ?? 1)
            : 0,
      };
      final newSubtaskId = gameProvider.addSubtask(task.id, subtaskData);

      // Initialize controllers for the new subtask
      _newSubSubtaskNameControllers[newSubtaskId] = TextEditingController();
      _newSubSubtaskIsCountableMap[newSubtaskId] = false;
      _newSubSubtaskTargetCountControllers[newSubtaskId] =
          TextEditingController(text: '5');
      _localTimeControllers[newSubtaskId] = TextEditingController(text: '0');
      if (subtaskData['isCountable'] as bool) {
        _localCountControllers[newSubtaskId] = TextEditingController(text: '0');
      }

      _newSubtaskNameController.clear();
      // No need to call setState if GameProvider handles UI updates via notifyListeners
      _newSubtaskIsCountable = false; // Reset local state for form
      _newSubtaskTargetCountController.text =
          '10'; // Reset local state for form
      // State for form field values for isCountable needs separate handling if not directly bound to provider
      // For instance, by calling setState if these are local state variables in _TaskDetailsViewState
      if (mounted) {
        setState(() {}); // To update the form fields for _newSubtaskIsCountable
      }
    }
  }

  void _handleAddSubSubtask(
      GameProvider gameProvider, String mainTaskId, String parentSubtaskId) {
    final name = _newSubSubtaskNameControllers[parentSubtaskId]?.text.trim();
    if (name != null && name.isNotEmpty) {
      final subSubData = {
        'name': name,
        'isCountable': _newSubSubtaskIsCountableMap[parentSubtaskId] ?? false,
        'targetCount': (_newSubSubtaskIsCountableMap[parentSubtaskId] ?? false)
            ? (int.tryParse(
                    _newSubSubtaskTargetCountControllers[parentSubtaskId]
                            ?.text ??
                        '1') ??
                1)
            : 0,
      };
      gameProvider.addSubSubtask(mainTaskId, parentSubtaskId, subSubData);
      _newSubSubtaskNameControllers[parentSubtaskId]?.clear();
      // Reset local form state
      _newSubSubtaskIsCountableMap[parentSubtaskId] = false;
      _newSubSubtaskTargetCountControllers[parentSubtaskId]?.text = '5';
      if (mounted) {
        setState(
            () {}); // To update the form fields for the specific sub-subtask add section
      }
    }
  }

  void _handleTimeOrCountBlur(
      GameProvider gp, MainTask task, SubTask subTask, String fieldType) {
    if (fieldType == 'time') {
      final newTime =
          int.tryParse(_localTimeControllers[subTask.id]?.text ?? '0') ??
              subTask.currentTimeSpent;
      if (newTime != subTask.currentTimeSpent) {
        gp.updateSubtask(task.id, subTask.id, {'currentTimeSpent': newTime});
      }
    } else if (fieldType == 'count' && subTask.isCountable) {
      final newCount =
          int.tryParse(_localCountControllers[subTask.id]?.text ?? '0') ??
              subTask.currentCount;
      if (newCount != subTask.currentCount) {
        gp.updateSubtask(task.id, subTask.id,
            {'currentCount': newCount.clamp(0, subTask.targetCount)});
      }
    }
  }

  void _handleSubSubtaskCountBlur(GameProvider gp, MainTask task,
      SubTask parentSubTask, SubSubTask subSubTask) {
    if (subSubTask.isCountable) {
      final newCount = int.tryParse(
              _localSubSubtaskCountControllers[subSubTask.id]?.text ?? '0') ??
          subSubTask.currentCount;
      if (newCount != subSubTask.currentCount) {
        gp.updateSubSubtask(task.id, parentSubTask.id, subSubTask.id,
            {'currentCount': newCount.clamp(0, subSubTask.targetCount)});
      }
    }
  }

  void _handleCheckboxChange(GameProvider gp, MainTask task, SubTask subTask) {
    if (subTask.isCountable) {
      final currentCount =
          int.tryParse(_localCountControllers[subTask.id]?.text ?? '0') ??
              subTask.currentCount;
      if (currentCount < subTask.targetCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Please complete the target count (${subTask.targetCount}) before marking as done.'),
              backgroundColor: AppTheme.fhAccentRed),
        );
        return;
      }
    }
    gp.completeSubtask(task.id, subTask.id);
  }

  void _handleSubSubtaskCheckboxChange(GameProvider gp, MainTask task,
      SubTask parentSubTask, SubSubTask subSubTask) {
    if (subSubTask.isCountable) {
      final currentCount = int.tryParse(
              _localSubSubtaskCountControllers[subSubTask.id]?.text ?? '0') ??
          subSubTask.currentCount;
      if (currentCount < subSubTask.targetCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Please complete the target count (${subSubTask.targetCount}) for this step before marking as done.'),
              backgroundColor: AppTheme.fhAccentRed),
        );
        return;
      }
    }
    gp.completeSubSubtask(task.id, parentSubTask.id, subSubTask.id);
  }

  void _handleAiGenerateSubquests(GameProvider gameProvider, MainTask task) {
    if (_aiUserInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please provide input for the AI to generate sub-quests."),
            backgroundColor: AppTheme.fhAccentOrange),
      );
      return;
    }
    gameProvider.triggerAISubquestGeneration(
        task,
        _aiGenerationMode,
        _aiUserInputController.text.trim(),
        int.tryParse(_aiNumSubquestsController.text) ?? 3);
    _aiUserInputController.clear(); // Clear after submission
  }

  @override
  Widget build(BuildContext context) {
    // Consumer is fine here for reacting to GameProvider changes if _initializeControllersForTask
    // is also called from a listener pattern as implemented.
    return Consumer<GameProvider>(
      builder: (context, gameProviderConsumer, child) {
        final task = gameProviderConsumer.getSelectedTask();
        final theme = Theme.of(context);

        if (task == null) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.textBoxSearchOutline,
                    size: 56,
                    color: (gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed)), // Updated icon and color
                const SizedBox(height: 16),
                Text('Select a Quest',
                    style: theme.textTheme.displaySmall?.copyWith(
                        color: (gameProvider.getSelectedTask()?.taskColor ??
                            AppTheme.fhAccentTealFixed))), // Updated style
                const SizedBox(height: 8),
                Text(
                  'Details of the selected quest will appear here.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppTheme.fhTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ));
        }

        // This ensures controllers are initialized if the task object itself changes.
        // Useful if the task list is reloaded or the task object gets replaced.
        if (_currentTaskForInit?.id != task.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _initializeControllersForTask(task);
              });
            }
          });
        }

        final timeProgressPercent = (task.dailyTimeSpent /
                dailyTaskGoalMinutes.toDouble() *
                100) // Ensure double division
            .clamp(0.0, 100.0);
        Color timeProgressColor = (gameProvider.getSelectedTask()?.taskColor ??
            AppTheme
                .fhAccentTealFixed); // Default progress color, Changed from fhAccentLightCyan
        if (task.dailyTimeSpent >= dailyTaskGoalMinutes * 3) {
          timeProgressColor = AppTheme.fhAccentPurple;
        } else if (task.dailyTimeSpent >= dailyTaskGoalMinutes * 2) {
          timeProgressColor =
              AppTheme.fhAccentTeal; // Changed from fhAccentBrightBlue
        } else if (task.dailyTimeSpent >= dailyTaskGoalMinutes) {
          timeProgressColor = AppTheme.fhAccentGreen;
        }

        final completedSubtasksCount =
            task.subTasks.where((st) => st.completed).length;
        final totalSubtasksCount = task.subTasks.length;
        final subtaskCompletionPercent = totalSubtasksCount > 0
            ? (completedSubtasksCount / totalSubtasksCount * 100)
            : 0.0;

        // Check if controllers for subtasks exist, if not, initialize them
        // This handles cases where subtasks are added and widget rebuilds before initState for new subtask controllers
        for (var st in task.subTasks) {
          _localTimeControllers.putIfAbsent(
              st.id,
              () =>
                  TextEditingController(text: st.currentTimeSpent.toString()));
          if (st.isCountable) {
            _localCountControllers.putIfAbsent(st.id,
                () => TextEditingController(text: st.currentCount.toString()));
          }
          _newSubSubtaskNameControllers.putIfAbsent(
              st.id, () => TextEditingController());
          _newSubSubtaskIsCountableMap.putIfAbsent(st.id, () => false);
          _newSubSubtaskTargetCountControllers.putIfAbsent(
              st.id, () => TextEditingController(text: '5'));
          for (var sss in st.subSubTasks) {
            if (sss.isCountable) {
              _localSubSubtaskCountControllers.putIfAbsent(
                  sss.id,
                  () =>
                      TextEditingController(text: sss.currentCount.toString()));
            }
          }
        }

        return Padding(
          // Removed SingleChildScrollView as parent handles it
          padding:
              const EdgeInsets.only(top: 0, bottom: 16, left: 10, right: 10),
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // Allow column to shrink wrap its content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme
                    .fhBgMedium, // Use medium background for prominent card
                margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  side: BorderSide(
                      color: AppTheme.fhBorderColor.withOpacity(0.5), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${task.theme.toUpperCase()} QUEST PROTOCOL', // Themed title
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: (gameProvider
                                        .getSelectedTask()
                                        ?.taskColor ??
                                    AppTheme.fhAccentTealFixed),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8),
                          ),
                          Container(
                            // Status chip
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: task.dailyTimeSpent >=
                                        dailyTaskGoalMinutes
                                    ? AppTheme.fhAccentGreen.withOpacity(0.2)
                                    : AppTheme.fhAccentOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: task.dailyTimeSpent >=
                                            dailyTaskGoalMinutes
                                        ? AppTheme.fhAccentGreen
                                        : AppTheme.fhAccentOrange,
                                    width: 0.5)),
                            child: Text(
                              task.dailyTimeSpent >= dailyTaskGoalMinutes
                                  ? "OBJECTIVE MET"
                                  : (task.dailyTimeSpent > 0
                                      ? "ACTIVE"
                                      : "PENDING"),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    task.dailyTimeSpent >= dailyTaskGoalMinutes
                                        ? AppTheme.fhAccentGreen
                                        : AppTheme.fhAccentOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(task.name,
                          style: theme
                              .textTheme.headlineSmall // More prominent title
                              ?.copyWith(
                                  color: AppTheme.fhTextPrimary,
                                  fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(task.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 13,
                              height: 1.5)),
                      const SizedBox(height: 16),
                      // Progress Stats Card (Inner Card)
                      Card(
                        color: AppTheme.fhBgDark
                            .withOpacity(0.7), // Darker inner card
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: (gameProvider
                                                      .getSelectedTask()
                                                      ?.taskColor ??
                                                  AppTheme
                                                      .fhAccentTealFixed) // Changed from fhAccentLightCyan
                                              .withOpacity(0.7),
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      gameProviderConsumer.romanize(
                                          task.streak > 0 ? task.streak : 1),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                              color: (gameProvider
                                                      .getSelectedTask()
                                                      ?.taskColor ??
                                                  AppTheme
                                                      .fhAccentTealFixed), // Changed from fhAccentLightCyan
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('CURRENT STREAK: ${task.streak}',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                    color:
                                                        AppTheme.fhAccentGreen,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                            'TIME LOGGED (TODAY): ${task.dailyTimeSpent}m / ${dailyTaskGoalMinutes}m Goal',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    fontSize: 11,
                                                    color: AppTheme
                                                        .fhTextSecondary)),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                            height: 8, // Thicker progress bar
                                            child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                    value: timeProgressPercent /
                                                        100,
                                                    backgroundColor: AppTheme
                                                        .fhBorderColor
                                                        .withOpacity(0.3),
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            timeProgressColor)))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (totalSubtasksCount > 0) ...[
                                const SizedBox(height: 12),
                                Divider(
                                    color:
                                        AppTheme.fhBorderColor.withOpacity(0.3),
                                    height: 1),
                                const SizedBox(height: 10),
                                Text('SUB-QUESTS TRACKING:',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                            color: AppTheme.fhTextSecondary,
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                SizedBox(
                                    height: 8, // Thicker progress bar
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                            value:
                                                subtaskCompletionPercent / 100,
                                            backgroundColor: AppTheme
                                                .fhBorderColor
                                                .withOpacity(0.3),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                        Color>(
                                                    AppTheme.fhAccentPurple)))),
                                const SizedBox(height: 4),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        '$completedSubtasksCount / $totalSubtasksCount modules completed',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                fontSize: 10,
                                                color:
                                                    AppTheme.fhTextSecondary))),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Text('Sub-Quests Log',
                    style: theme.textTheme.titleLarge?.copyWith(
                        // Updated style
                        fontFamily: AppTheme
                            .fontDisplay, // Changed from AppTheme.fontMain
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              if (task.subTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0), // Increased padding
                  child: Center(
                      child: Text(
                          'No sub-quests recorded yet. Add some below or use AI generation.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              // Use bodyLarge for better readability
                              color: AppTheme.fhTextSecondary.withOpacity(0.8),
                              fontStyle: FontStyle.italic))),
                )
              else
                ListView.builder(
                  // This ListView should not be primary scrollable
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: task.subTasks.length,
                  itemBuilder: (ctx, index) {
                    final st = task.subTasks[index];
                    // Ensure controllers are available
                    _newSubSubtaskNameControllers.putIfAbsent(
                        st.id, () => TextEditingController());
                    _newSubSubtaskIsCountableMap.putIfAbsent(
                        st.id, () => false);
                    _newSubSubtaskTargetCountControllers.putIfAbsent(
                        st.id, () => TextEditingController(text: '5'));
                    _localTimeControllers.putIfAbsent(
                        st.id,
                        () => TextEditingController(
                            text: st.currentTimeSpent.toString()));
                    if (st.isCountable) {
                      _localCountControllers.putIfAbsent(
                          st.id,
                          () => TextEditingController(
                              text: st.currentCount.toString()));
                    }
                    for (var sss in st.subSubTasks) {
                      if (sss.isCountable) {
                        _localSubSubtaskCountControllers.putIfAbsent(
                            sss.id,
                            () => TextEditingController(
                                text: sss.currentCount.toString()));
                      }
                    }

                    final timerState = gameProviderConsumer.activeTimers[st.id];
                    final displayTimeSeconds = timerState != null
                        ? (timerState.isRunning
                            ? timerState.accumulatedDisplayTime +
                                (DateTime.now()
                                        .difference(timerState.startTime)
                                        .inMilliseconds /
                                    1000)
                            : timerState.accumulatedDisplayTime)
                        : st.currentTimeSpent * 60.0;

                    final completedSubSubTasks =
                        st.subSubTasks.where((sss) => sss.completed).length;
                    final totalSubSubTasks = st.subSubTasks.length;
                    final subSubTaskProgress = totalSubSubTasks > 0
                        ? (completedSubSubTasks / totalSubSubTasks * 100)
                        : 0.0;

                    return Card(
                      // Subtask card
                      key: ValueKey(st.id),
                      margin:
                          const EdgeInsets.only(bottom: 12, left: 0, right: 0),
                      color: AppTheme
                          .fhBgLight, // Use light background for subtask cards
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        side: BorderSide(
                            color: AppTheme.fhBorderColor.withOpacity(0.5),
                            width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                RhombusCheckbox(
                                  // Themed checkbox
                                  checked: st.completed,
                                  onChanged: st.completed
                                      ? null
                                      : (bool? value) => _handleCheckboxChange(
                                          gameProviderConsumer, task, st),
                                  disabled: st.completed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(st.name,
                                        style: theme.textTheme
                                            .titleMedium // Prominent name for subtask
                                            ?.copyWith(
                                                decoration: st.completed
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                                color: st.completed
                                                    ? AppTheme.fhTextSecondary
                                                        .withOpacity(0.7)
                                                    : AppTheme.fhTextPrimary,
                                                fontWeight: st.completed
                                                    ? FontWeight.normal
                                                    : FontWeight.w600))),
                                if (!st.completed)
                                  IconButton(
                                    icon: Icon(
                                        MdiIcons
                                            .deleteForeverOutline, // Changed icon
                                        color: AppTheme.fhAccentRed
                                            .withOpacity(0.8),
                                        size: 20),
                                    onPressed: () => gameProviderConsumer
                                        .deleteSubtask(task.id, st.id),
                                    tooltip: 'Delete Sub-Quest',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (!st.completed) ...[
                              const SizedBox(height: 10),
                              Divider(
                                  color:
                                      AppTheme.fhBorderColor.withOpacity(0.3)),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 30.0, top: 8.0), // Indent details
                                child: Column(
                                  children: [
                                    // Countable progress
                                    if (st.isCountable)
                                      _buildProgressRow(
                                        theme,
                                        label: 'Progress:',
                                        controller:
                                            _localCountControllers[st.id]!,
                                        currentValue: st.currentCount,
                                        targetValue: st.targetCount,
                                        progressColor: (gameProvider
                                                .getSelectedTask()
                                                ?.taskColor ??
                                            AppTheme
                                                .fhAccentTealFixed), // Changed from fhAccentBrightBlue
                                        onBlur: () => _handleTimeOrCountBlur(
                                            gameProviderConsumer,
                                            task,
                                            st,
                                            'count'),
                                      ),
                                    const SizedBox(height: 6),
                                    // Timer row
                                    _buildTimerRow(
                                      theme,
                                      label: 'Time (m):',
                                      controller: _localTimeControllers[st.id]!,
                                      loggedTime: st.currentTimeSpent,
                                      timerState: timerState,
                                      displayTimeSeconds: displayTimeSeconds,
                                      onPlayPause: () => {
                                        timerState?.isRunning ?? false
                                            ? gameProviderConsumer
                                                .pauseTimer(st.id)
                                            : gameProviderConsumer.startTimer(
                                                st.id, 'subtask', task.id),
                                        if (timerState?.isRunning ?? false)
                                          gameProviderConsumer
                                              .logTimerAndReset(st.id)
                                      },
                                      onBlur: () => _handleTimeOrCountBlur(
                                          gameProviderConsumer,
                                          task,
                                          st,
                                          'time'),
                                    ),
                                    const SizedBox(height: 12),
                                    // Sub-subtasks
                                    if (st.subSubTasks.isNotEmpty) ...[
                                      _buildSubSubTaskList(
                                          theme,
                                          gameProviderConsumer,
                                          task,
                                          st,
                                          subSubTaskProgress),
                                    ],
                                    const SizedBox(height: 8),
                                    // Add new sub-subtask form
                                    _buildAddSubSubTaskForm(
                                        theme, gameProviderConsumer, task, st),
                                  ],
                                ),
                              ),
                            ],
                            if (st.completed) // Show completion info
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 30.0, top: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Completed info
                                    Text(
                                        'Completed: ${st.completedDate} - Logged: ${st.currentTimeSpent}m',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                color: AppTheme.fhAccentGreen
                                                    .withOpacity(0.8),
                                                fontSize: 10)),
                                    // Actions for completed subtasks
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        // Duplicate button
                                        IconButton(
                                            icon: Icon(MdiIcons.repeatVariant,
                                                size: 18,
                                                color: (gameProvider
                                                            .getSelectedTask()
                                                            ?.taskColor ??
                                                        AppTheme
                                                            .fhAccentTealFixed) // Changed from fhAccentBrightBlue
                                                    .withOpacity(0.8)),
                                            onPressed: () =>
                                                gameProviderConsumer
                                                    .duplicateCompletedSubtask(
                                                        task.id, st.id),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                maxWidth: 30, maxHeight: 24)),
                                        IconButton(
                                            icon: Icon(MdiIcons.deleteOutline,
                                                size: 18,
                                                color: AppTheme.fhAccentRed),
                                            onPressed: () =>
                                                gameProviderConsumer
                                                    .deleteSubtask(
                                                        task.id, st.id),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                maxWidth: 30, maxHeight: 24)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // "Add New Sub-Quest" and "Generate with AI" cards - apply similar themed Card styling
              _buildAddNewSubQuestCard(theme, gameProviderConsumer, task),
              _buildAISubQuestCard(theme, gameProviderConsumer, task),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for cleaner build method, with theming:
  Widget _buildProgressRow(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required int currentValue,
    required int targetValue,
    required Color progressColor,
    required VoidCallback onBlur,
  }) {
    return Row(
      children: [
        SizedBox(
            width: 70,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 11, color: AppTheme.fhTextSecondary))),
        SizedBox(
          width: 40,
          height: 28,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontSize: 12, color: AppTheme.fhTextPrimary),
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 2),
                border: InputBorder.none,
                filled: false),
            onEditingComplete: onBlur,
            onTapOutside: (_) => onBlur(),
          ),
        ),
        Text(' / $targetValue',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11, color: AppTheme.fhTextSecondary)),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: targetValue > 0 ? (currentValue / targetValue) : 0,
                backgroundColor: AppTheme.fhBorderColor.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerRow(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required int loggedTime,
    required ActiveTimerInfo? timerState,
    required double displayTimeSeconds,
    required VoidCallback onPlayPause,
    required VoidCallback onBlur,
  }) {
    return Row(
      children: [
        SizedBox(
            width: 70,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 11, color: AppTheme.fhTextSecondary))),
        SizedBox(
          width: 40,
          height: 28,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontSize: 12, color: AppTheme.fhTextPrimary),
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 2),
                border: InputBorder.none,
                filled: false),
            onEditingComplete: onBlur,
            onTapOutside: (_) => onBlur(),
          ),
        ),
        const Spacer(),
        Text('Logged: ${loggedTime}m',
            style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.fhTextSecondary.withOpacity(0.8),
                fontSize: 10)),
        IconButton(
          icon: Icon(
            timerState?.isRunning ?? false
                ? MdiIcons.pauseCircleOutline
                : MdiIcons.playCircleOutline,
            color: timerState?.isRunning ?? false
                ? AppTheme.fhAccentOrange
                : AppTheme.fhAccentGreen,
            size: 22,
          ),
          onPressed: onPlayPause,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          helper.formatTime(displayTimeSeconds),
          style: theme.textTheme.labelSmall?.copyWith(
              color: (gameProvider.getSelectedTask()?.taskColor ??
                  AppTheme.fhAccentTealFixed), // Changed from fhAccentLightCyan
              fontSize: 11,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildSubSubTaskList(
      ThemeData theme,
      GameProvider gameProviderConsumer,
      MainTask task,
      SubTask st,
      double subSubTaskProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Checkpoints:',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.fhTextSecondary.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: subSubTaskProgress / 100,
                    backgroundColor: AppTheme.fhBorderColor.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.fhAccentPurple),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: st.subSubTasks.length,
            itemBuilder: (sctx, sIndex) {
              final sss = st.subSubTasks[sIndex];
              return Padding(
                padding: const EdgeInsets.only(
                    bottom: 4.0, left: 8.0), // Indent sub-subtasks
                child: Row(
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: RhombusCheckbox(
                          checked: sss.completed,
                          onChanged: sss.completed
                              ? null
                              : (bool? val) => _handleSubSubtaskCheckboxChange(
                                  gameProviderConsumer, task, st, sss),
                          disabled: sss.completed,
                          size: CheckboxSize.small,
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${sss.name}${sss.isCountable && !sss.completed ? ' (${_localSubSubtaskCountControllers[sss.id]?.text ?? sss.currentCount}/${sss.targetCount})' : (sss.isCountable && sss.completed ? ' (${sss.currentCount}/${sss.targetCount})' : '')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              decoration: sss.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: sss.completed
                                  ? AppTheme.fhTextSecondary.withOpacity(0.6)
                                  : AppTheme.fhTextSecondary,
                            ))),
                    if (sss.isCountable && !sss.completed)
                      SizedBox(
                        width: 35,
                        height: 22,
                        child: TextField(
                          controller: _localSubSubtaskCountControllers[sss.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10, color: AppTheme.fhTextPrimary),
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 1),
                              border: InputBorder.none,
                              filled: false),
                          onEditingComplete: () => _handleSubSubtaskCountBlur(
                              gameProviderConsumer, task, st, sss),
                          onTapOutside: (_) => _handleSubSubtaskCountBlur(
                              gameProviderConsumer, task, st, sss),
                        ),
                      ),
                    if (!sss.completed)
                      IconButton(
                          icon: Icon(MdiIcons.deleteOutline,
                              color: AppTheme.fhAccentRed.withOpacity(0.7),
                              size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => gameProviderConsumer
                              .deleteSubSubtask(task.id, st.id, sss.id)),
                  ],
                ),
              );
            }),
      ],
    );
  }

  Widget _buildAddSubSubTaskForm(ThemeData theme,
      GameProvider gameProviderConsumer, MainTask task, SubTask st) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0), // Indent add form
      child: Row(
        children: [
          Expanded(
              child: SizedBox(
                  height: 36, // Consistent height
                  child: TextField(
                    controller: _newSubSubtaskNameControllers[st.id],
                    decoration: const InputDecoration(
                        hintText: 'Add a checkpoint...',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11, color: AppTheme.fhTextPrimary),
                  ))),
          Transform.scale(
            // Make switch smaller
            scale: 0.7,
            child: Switch(
              value: _newSubSubtaskIsCountableMap[st.id] ?? false,
              onChanged: (val) =>
                  setState(() => _newSubSubtaskIsCountableMap[st.id] = val),
              activeColor: (gameProvider.getSelectedTask()?.taskColor ??
                  AppTheme
                      .fhAccentTealFixed), // Changed from fhAccentBrightBlue
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_newSubSubtaskIsCountableMap[st.id] ?? false)
            SizedBox(
                width: 35,
                height: 36,
                child: TextField(
                  controller: _newSubSubtaskTargetCountControllers[st.id],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 4)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, color: AppTheme.fhTextPrimary),
                )),
          IconButton(
            icon: Icon(MdiIcons.plusCircleOutline,
                color: AppTheme.fhAccentGreen, size: 22),
            onPressed: () =>
                _handleAddSubSubtask(gameProviderConsumer, task.id, st.id),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewSubQuestCard(
      ThemeData theme, GameProvider gameProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgMedium, // Distinct background for form cards
      margin: const EdgeInsets.only(top: 20, left: 0, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
            color: AppTheme.fhBorderColor.withOpacity(0.8), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Sub-Quest (Manually)',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily:
                        AppTheme.fontDisplay, // Changed from AppTheme.fontMain
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _newSubtaskNameController,
              decoration:
                  const InputDecoration(hintText: 'Sub-quest objective...'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _newSubtaskIsCountable,
                  onChanged: (val) =>
                      setState(() => _newSubtaskIsCountable = val ?? false),
                  activeColor: (gameProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed),
                  checkColor: AppTheme.fhBgDark,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                      color: (gameProvider.getSelectedTask()?.taskColor ??
                              AppTheme.fhAccentTealFixed)
                          .withOpacity(0.7),
                      width: 1.5),
                ),
                const Text('Is it countable?',
                    style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 13,
                        fontFamily: AppTheme.fontBody)),
                const SizedBox(width: 12),
                if (_newSubtaskIsCountable)
                  Expanded(
                    child: TextField(
                      controller: _newSubtaskTargetCountController,
                      decoration: const InputDecoration(
                          labelText: 'Target #',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 13,
                          fontFamily: AppTheme.fontBody,
                          color: AppTheme.fhTextPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.plusBoxOutline, size: 18),
              label: const Text('ADD SUB-QUEST'),
              onPressed: () => _handleAddSubtask(gameProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISubQuestCard(
      ThemeData theme, GameProvider gameProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgMedium,
      margin: const EdgeInsets.only(top: 16, left: 0, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
            color: AppTheme.fhAccentPurple.withOpacity(0.5),
            width: 1), // AI card distinct border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.robotHappyOutline,
                    color: AppTheme.fhAccentPurple, size: 20),
                const SizedBox(width: 8),
                Text('Generate Sub-Quests with AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: AppTheme
                            .fontDisplay, // Changed from AppTheme.fontMain
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Generation Mode',
                  labelStyle:
                      TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody)),
              dropdownColor: AppTheme.fhBgLight,
              value: _aiGenerationMode,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
              items: const [
                DropdownMenuItem(
                    value: 'text_list',
                    child: Text('From Text List / Outline')),
                DropdownMenuItem(
                    value: 'book_chapter',
                    child: Text('From Book Chapter/Section')),
                DropdownMenuItem(
                    value: 'general_plan',
                    child: Text('From General Plan/Goal')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _aiGenerationMode = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiUserInputController,
              decoration: const InputDecoration(
                labelText: 'Your Input for AI...',
                alignLabelWithHint: true,
                labelStyle:
                    TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody),
              ),
              maxLines: null, // <--- Set maxLines to null for auto-expansion
              minLines: 2,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiNumSubquestsController,
              decoration: const InputDecoration(
                  labelText: 'Approx. # Sub-Quests',
                  labelStyle:
                      TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody)),
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: gameProviderConsumer.isGeneratingSubquests
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.fhBgDark))
                  : Icon(MdiIcons.creationOutline, size: 18), // Changed icon
              label: Text(gameProviderConsumer.isGeneratingSubquests
                  ? 'GENERATING...'
                  : 'INITIATE AI PROTOCOL'),
              onPressed: gameProviderConsumer.isGeneratingSubquests
                  ? null
                  : () =>
                      _handleAiGenerateSubquests(gameProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentPurple,
                  foregroundColor:
                      AppTheme.fhTextPrimary, // Ensure text is visible
                  disabledBackgroundColor: AppTheme.fhBgLight.withOpacity(0.5),
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }
}
