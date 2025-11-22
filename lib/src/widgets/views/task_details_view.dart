// lib/src/widgets/views/task_details_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
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
  final _newSubtaskNameController = TextEditingController();
  bool _newSubtaskIsCountable = false;
  final _newSubtaskTargetCountController = TextEditingController(text: '10');
  // Priority removed

  String _aiGenerationMode = 'text_list';
  final _aiUserInputController = TextEditingController();
  final _aiNumSubquestsController = TextEditingController(text: '3');

  final Map<String, TextEditingController> _newSubSubtaskNameControllers = {};
  final Map<String, bool> _newSubSubtaskIsCountableMap = {};
  final Map<String, TextEditingController>
      _newSubSubtaskTargetCountControllers = {};

  final Map<String, TextEditingController> _localTimeControllers = {};
  final Map<String, TextEditingController> _localCountControllers = {};
  final Map<String, TextEditingController> _localSubSubtaskCountControllers =
      {};

  late AppProvider appProvider;
  MainTask? _currentTaskForInit;

  @override
  void initState() {
    super.initState();
    appProvider = Provider.of<AppProvider>(context, listen: false);
    _initializeControllersForTask(appProvider.getSelectedTask());
    appProvider.addListener(_handleProviderChange);
  }

  @override
  void dispose() {
    _newSubtaskNameController.dispose();
    _newSubtaskTargetCountController.dispose();
    _aiUserInputController.dispose();
    _aiNumSubquestsController.dispose();
    _clearDynamicControllers();
    appProvider.removeListener(_handleProviderChange);
    super.dispose();
  }

  void _clearDynamicControllers() {
    _newSubSubtaskNameControllers.values.forEach((c) => c.dispose());
    _newSubSubtaskNameControllers.clear();
    _newSubSubtaskTargetCountControllers.values.forEach((c) => c.dispose());
    _newSubSubtaskTargetCountControllers.clear();
    _localTimeControllers.values.forEach((c) => c.dispose());
    _localTimeControllers.clear();
    _localCountControllers.values.forEach((c) => c.dispose());
    _localCountControllers.clear();
    _localSubSubtaskCountControllers.values.forEach((c) => c.dispose());
    _localSubSubtaskCountControllers.clear();
    _newSubSubtaskIsCountableMap.clear();
  }

  void _handleProviderChange() {
    final selectedTask = appProvider.getSelectedTask();
    if (_currentTaskForInit?.id != selectedTask?.id) {
      if (mounted) {
        setState(() => _initializeControllersForTask(selectedTask));
      } else {
        _initializeControllersForTask(selectedTask);
      }
    }
  }

  void _initializeControllersForTask(MainTask? task) {
    _clearDynamicControllers();
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

  void _handleAddSubtask(AppProvider appProvider, MainTask task) {
    if (_newSubtaskNameController.text.trim().isNotEmpty) {
      final subtaskData = {
        'name': _newSubtaskNameController.text.trim(),
        'isCountable': _newSubtaskIsCountable,
        'targetCount': _newSubtaskIsCountable
            ? (int.tryParse(_newSubtaskTargetCountController.text) ?? 1)
            : 0,
      };
      final newSubtaskId = appProvider.addSubtask(task.id, subtaskData);

      _newSubSubtaskNameControllers[newSubtaskId] = TextEditingController();
      _newSubSubtaskIsCountableMap[newSubtaskId] = false;
      _newSubSubtaskTargetCountControllers[newSubtaskId] =
          TextEditingController(text: '5');
      _localTimeControllers[newSubtaskId] = TextEditingController(text: '0');
      if (subtaskData['isCountable'] as bool) {
        _localCountControllers[newSubtaskId] = TextEditingController(text: '0');
      }

      _newSubtaskNameController.clear();
      if (mounted) {
        setState(() {
          _newSubtaskIsCountable = false;
          _newSubtaskTargetCountController.text = '10';
        });
      }
    }
  }

  void _handleAddSubSubtask(
      AppProvider appProvider, String mainTaskId, String parentSubtaskId) {
    final name = _newSubSubtaskNameControllers[parentSubtaskId]?.text.trim();
    if (name != null && name.isNotEmpty) {
      final subSubData = {
        'name': name,
        'isCountable': _newSubSubtaskIsCountableMap[parentSubtaskId] ?? false,
        'targetCount': (_newSubSubtaskIsCountableMap[parentSubtaskId] ?? false)
            ? (int.tryParse(_newSubSubtaskTargetCountControllers[
                        parentSubtaskId]
                    ?.text ??
                '1') ??
                1)
            : 0,
      };
      appProvider.addSubSubtask(mainTaskId, parentSubtaskId, subSubData);
      _newSubSubtaskNameControllers[parentSubtaskId]?.clear();
      if (mounted) {
        setState(() {
          _newSubSubtaskIsCountableMap[parentSubtaskId] = false;
          _newSubSubtaskTargetCountControllers[parentSubtaskId]?.text = '5';
        });
      }
    }
  }

  void _handleTimeOrCountBlur(
      AppProvider gp, MainTask task, SubTask subTask, String fieldType) {
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

  void _handleSubSubtaskCountBlur(AppProvider gp, MainTask task,
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

  void _handleCheckboxChange(AppProvider gp, MainTask task, SubTask subTask) {
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

  void _handleSubSubtaskCheckboxChange(AppProvider gp, MainTask task,
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

  void _handleAiGenerateSubquests(AppProvider appProvider, MainTask task) {
    if (_aiUserInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please provide input for the AI to generate sub-quests."),
            backgroundColor: AppTheme.fhAccentOrange),
      );
      return;
    }
    appProvider.triggerAISubquestGeneration(
        task,
        _aiGenerationMode,
        _aiUserInputController.text.trim(),
        int.tryParse(_aiNumSubquestsController.text) ?? 3);
    _aiUserInputController.clear();
  }

  String _formatMinutesToHHMM(int totalMinutes) {
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProviderConsumer, child) {
        final task = appProviderConsumer.getSelectedTask();
        final theme = Theme.of(context);

        if (task == null) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.textBoxSearchOutline,
                    size: 56, color: AppTheme.fhAccentTealFixed),
                const SizedBox(height: 16),
                Text('Select a Mission',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: AppTheme.fhAccentTealFixed)),
                const SizedBox(height: 8),
                Text(
                  'Details of the selected mission will appear here.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppTheme.fhTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ));
        }

        if (_currentTaskForInit?.id != task.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _initializeControllersForTask(task);
              });
            }
          });
        }

        final sortedSubTasks = List<SubTask>.from(task.subTasks);
        // Priority sort removed

        for (var st in task.subTasks) {
          _localTimeControllers.putIfAbsent(st.id,
              () => TextEditingController(text: st.currentTimeSpent.toString()));
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

        const double dailyGoalMinutes = 60.0;
        final double progress = task.dailyTimeSpent / dailyGoalMinutes;
        final timeSpentFormatted = _formatMinutesToHHMM(task.dailyTimeSpent);
        final weeklyCompletion =
            appProviderConsumer.getCompletionStatusForCurrentWeek(task);
        final int daysCompleted = weeklyCompletion.where((c) => c).length;
        final String streakText = daysCompleted >= 7
            ? "SEVEN DAY STREAK ACHIEVED!"
            : "WEEKLY PROGRESS";

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: 8, bottom: 16, left: 10, right: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.fhBgMedium,
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
                      Text(
                        '${task.theme.toUpperCase()} MISSION PROTOCOL',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color:
                                (appProvider.getSelectedTask()?.taskColor ??
                                    AppTheme.fhAccentTealFixed),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(task.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(task.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 13,
                              height: 1.5)),
                      const SizedBox(height: 16),
                      // TIME PROGRESS BAR
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.fhAccentTeal.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                  "TIME PROGRESS: $timeSpentFormatted / 01:00 HOURS",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.fhTextPrimary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.fhBgDark.withOpacity(0.5),
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.0, 2.0),
                                    child: Container(
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10)),
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF00F8F8),
                                            Color(0xFF32CD32),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // STREAK PANEL
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.fhAccentGreen.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(7, (index) {
                                final isComplete =
                                    weeklyCompletion.length > index &&
                                        weeklyCompletion[index];
                                return Icon(
                                  isComplete
                                      ? MdiIcons.checkCircle
                                      : MdiIcons.checkboxBlankCircleOutline,
                                  color: isComplete
                                      ? AppTheme.fhAccentGreen
                                      : AppTheme.fhTextDisabled.withOpacity(0.5),
                                  size: 24,
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(streakText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppTheme.fhTextPrimary,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sub-Missions Log',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: AppTheme.fontDisplay,
                            color: AppTheme.fhTextPrimary,
                            fontWeight: FontWeight.w600)),
                    // Priority sort button removed
                  ],
                ),
              ),
              if (task.subTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                      child: Text(
                          'No sub-missions recorded yet. Add some below or use AI generation.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.fhTextSecondary.withOpacity(0.8),
                              fontStyle: FontStyle.italic))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedSubTasks.length,
                  itemBuilder: (ctx, index) {
                    final st = sortedSubTasks[index];
                    final timerState = appProviderConsumer.activeTimers[st.id];
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
                      key: ValueKey(st.id),
                      margin:
                          const EdgeInsets.only(bottom: 12, left: 0, right: 0),
                      color: AppTheme.fhBgLight,
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
                                  checked: st.completed,
                                  onChanged: st.completed
                                      ? null
                                      : (bool? value) => _handleCheckboxChange(
                                          appProviderConsumer, task, st),
                                  disabled: st.completed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(st.name,
                                        style: theme.textTheme.titleMedium
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
                                // Priority icon removed
                                const SizedBox(width: 8),
                                if (!st.completed)
                                  IconButton(
                                    icon: Icon(MdiIcons.deleteForeverOutline,
                                        color: AppTheme.fhAccentRed
                                            .withOpacity(0.8),
                                        size: 20),
                                    onPressed: () => appProviderConsumer
                                        .deleteSubtask(task.id, st.id),
                                    tooltip: 'Delete Sub-Mission',
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
                                    left: 30.0, top: 8.0),
                                child: Column(
                                  children: [
                                    if (st.isCountable)
                                      _buildProgressRow(
                                        theme,
                                        label: 'Progress:',
                                        controller:
                                            _localCountControllers[st.id]!,
                                        currentValue: st.currentCount,
                                        targetValue: st.targetCount,
                                        progressColor:
                                            (appProvider.getSelectedTask()?.taskColor ??
                                                AppTheme.fhAccentTealFixed),
                                        onBlur: () => _handleTimeOrCountBlur(
                                            appProviderConsumer,
                                            task,
                                            st,
                                            'count'),
                                      ),
                                    const SizedBox(height: 6),
                                    _buildTimerRow(
                                      theme,
                                      label: 'Time (m):',
                                      controller: _localTimeControllers[st.id]!,
                                      loggedTime: st.currentTimeSpent,
                                      timerState: timerState,
                                      displayTimeSeconds: displayTimeSeconds,
                                      onPlayPause: () => {
                                        timerState?.isRunning ?? false
                                            ? appProviderConsumer
                                                .pauseTimer(st.id)
                                            : appProviderConsumer.startTimer(
                                                st.id, 'subtask', task.id),
                                        if (timerState?.isRunning ?? false)
                                          appProviderConsumer
                                              .logTimerAndReset(st.id)
                                      },
                                      onBlur: () => _handleTimeOrCountBlur(
                                          appProviderConsumer,
                                          task,
                                          st,
                                          'time'),
                                    ),
                                    const SizedBox(height: 12),
                                    if (st.subSubTasks.isNotEmpty) ...[
                                      _buildSubSubTaskList(
                                          theme,
                                          appProviderConsumer,
                                          task,
                                          st,
                                          subSubTaskProgress),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildAddSubSubTaskForm(
                                        theme, appProviderConsumer, task, st),
                                  ],
                                ),
                              ),
                            ],
                            if (st.completed)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 30.0, top: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Completed: ${st.completedDate} - Logged: ${st.currentTimeSpent}m',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                color: AppTheme.fhAccentGreen
                                                    .withOpacity(0.8),
                                                fontSize: 10)),
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        IconButton(
                                            icon: Icon(MdiIcons.repeatVariant,
                                                size: 18,
                                                color: (appProvider.getSelectedTask()?.taskColor ??
                                                        AppTheme
                                                            .fhAccentTealFixed)
                                                    .withOpacity(0.8)),
                                            onPressed: () =>
                                                appProviderConsumer
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
                                                appProviderConsumer
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
              _buildAddNewSubQuestCard(theme, appProviderConsumer, task),
              _buildAISubQuestCard(theme, appProviderConsumer, task),
            ],
          ),
        );
      },
    );
  }

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
              color: (appProvider.getSelectedTask()?.taskColor ??
                  AppTheme.fhAccentTealFixed),
              fontSize: 11,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildSubSubTaskList(ThemeData theme, AppProvider appProviderConsumer,
      MainTask task, SubTask st, double subSubTaskProgress) {
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
                padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
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
                                  appProviderConsumer, task, st, sss),
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
                              appProviderConsumer, task, st, sss),
                          onTapOutside: (_) => _handleSubSubtaskCountBlur(
                              appProviderConsumer, task, st, sss),
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
                          onPressed: () => appProviderConsumer
                              .deleteSubSubtask(task.id, st.id, sss.id)),
                  ],
                ),
              );
            }),
      ],
    );
  }

  Widget _buildAddSubSubTaskForm(ThemeData theme,
      AppProvider appProviderConsumer, MainTask task, SubTask st) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
      child: Row(
        children: [
          Expanded(
              child: SizedBox(
                  height: 36,
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
            scale: 0.7,
            child: Switch(
              value: _newSubSubtaskIsCountableMap[st.id] ?? false,
              onChanged: (val) =>
                  setState(() => _newSubSubtaskIsCountableMap[st.id] = val),
              activeColor: (appProvider.getSelectedTask()?.taskColor ??
                  AppTheme.fhAccentTealFixed),
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
                _handleAddSubSubtask(appProviderConsumer, task.id, st.id),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewSubQuestCard(
      ThemeData theme, AppProvider appProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgMedium,
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
            Text('Add New Sub-Mission (Manually)',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.fontDisplay,
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _newSubtaskNameController,
              decoration:
                  const InputDecoration(hintText: 'Sub-mission objective...'),
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
                  activeColor: (appProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed),
                  checkColor: AppTheme.fhBgDark,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                      color: (appProvider.getSelectedTask()?.taskColor ??
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
            // Priority removed from UI
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.plusBoxOutline, size: 18),
              label: const Text('ADD SUB-MISSION'),
              onPressed: () => _handleAddSubtask(appProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISubQuestCard(
      ThemeData theme, AppProvider appProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgMedium,
      margin: const EdgeInsets.only(top: 16, left: 0, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
            color: AppTheme.fhAccentPurple.withOpacity(0.5), width: 1),
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
                Text('Generate Sub-Missions with AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
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
              maxLines: null,
              minLines: 2,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiNumSubquestsController,
              decoration: const InputDecoration(
                  labelText: 'Approx. # Sub-Missions',
                  labelStyle:
                      TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody)),
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: appProviderConsumer.isGeneratingSubquests
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.fhBgDark))
                  : Icon(MdiIcons.creationOutline, size: 18),
              label: Text(appProviderConsumer.isGeneratingSubquests
                  ? 'GENERATING...'
                  : 'INITIATE AI PROTOCOL'),
              onPressed: appProviderConsumer.isGeneratingSubquests
                  ? null
                  : () => _handleAiGenerateSubquests(appProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentPurple,
                  foregroundColor: AppTheme.fhTextPrimary,
                  disabledBackgroundColor: AppTheme.fhBgLight.withOpacity(0.5),
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }
}