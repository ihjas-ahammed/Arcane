import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/dialogs/edit_subtask_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionDetailScreen({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final TextEditingController _checkpointController = TextEditingController();
  bool _isCheckpointCountable = false;
  final TextEditingController _checkpointCountController =
      TextEditingController(text: '5');

  late TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    _timeController =
        TextEditingController(text: widget.subTask.currentTimeSpent.toString());
  }

  @override
  void dispose() {
    _checkpointController.dispose();
    _checkpointCountController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // Sync logic might be needed if the provider updates the subtask while this screen is open
  // effectively the `subTask` object passed in is a reference, so it "should" update,
  // but if the list of subtasks in provider is replaced, we might lose sync.
  // Ideally we should look up the subtask from the provider in build.

  SubTask? _getLiveSubTask(AppProvider provider) {
    try {
      final parent =
          provider.mainTasks.firstWhere((t) => t.id == widget.parentTask.id);
      return parent.subTasks.firstWhere((s) => s.id == widget.subTask.id);
    } catch (e) {
      return null;
    }
  }

  void _handleAddCheckpoint(AppProvider provider) {
    if (_checkpointController.text.trim().isEmpty) return;

    final subSubData = {
      'name': _checkpointController.text.trim(),
      'isCountable': _isCheckpointCountable,
      'targetCount': _isCheckpointCountable
          ? (int.tryParse(_checkpointCountController.text) ?? 1)
          : 0,
    };

    provider.addSubSubtask(widget.parentTask.id, widget.subTask.id, subSubData);
    _checkpointController.clear();
    setState(() {
      _isCheckpointCountable = false;
      _checkpointCountController.text = '5';
    });
  }

  Future<void> _handleEditSubtask(
      BuildContext context, AppProvider provider, SubTask textSubTask) async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => EditSubtaskDialog(initialName: textSubTask.name),
    );

    if (newName != null && newName.isNotEmpty && newName != textSubTask.name) {
      provider.updateSubtask(
          widget.parentTask.id, widget.subTask.id, {'name': newName});
      // Ensure UI updates if local state is relevant, though provider listener triggers rebuild
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);

    // Get live data to ensure updates propagate (e.g. from timer ticks or other edits)
    final liveSubTask = _getLiveSubTask(provider);

    // If task was deleted, close screen
    if (liveSubTask == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final timerState = provider.activeTimers[liveSubTask.id];

    final int totalCheckpoints = liveSubTask.subSubTasks.length;
    final int completedCheckpoints =
        liveSubTask.subSubTasks.where((s) => s.completed).length;
    final double progress =
        totalCheckpoints > 0 ? completedCheckpoints / totalCheckpoints : 0.0;

    final double displayTimeSeconds = timerState != null
        ? (timerState.isRunning
            ? timerState.accumulatedDisplayTime +
                (DateTime.now()
                        .difference(timerState.startTime)
                        .inMilliseconds /
                    1000)
            : timerState.accumulatedDisplayTime)
        : liveSubTask.currentTimeSpent * 60.0;

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    // Update local controller if needed (when not editing)
    if (!_timeController.selection.isValid &&
        _timeController.text != liveSubTask.currentTimeSpent.toString()) {
      _timeController.text = liveSubTask.currentTimeSpent.toString();
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Submission Details",
            style: theme.textTheme.titleLarge
                ?.copyWith(color: AppTheme.fhTextPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.fhBorderColor.withValues(alpha: 0.5))),
              child: Row(
                children: [
                  RhombusCheckbox(
                    checked: liveSubTask.completed,
                    onChanged: (val) => provider.completeSubtask(
                        widget.parentTask.id, liveSubTask.id),
                    disabled: liveSubTask.completed,
                    size: CheckboxSize.medium,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      liveSubTask.name.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: liveSubTask.completed
                              ? AppTheme.fhTextDisabled
                              : AppTheme.fhTextPrimary),
                    ),
                  ),
                  if (!liveSubTask.completed) ...[
                    IconButton(
                      icon: Icon(MdiIcons.pencilOutline,
                          color: AppTheme.fhTextSecondary),
                      onPressed: () =>
                          _handleEditSubtask(context, provider, liveSubTask),
                    ),
                    IconButton(
                      icon: Icon(MdiIcons.deleteOutline,
                          color: AppTheme.fhAccentRed),
                      onPressed: () {
                        provider.deleteSubtask(
                            widget.parentTask.id, liveSubTask.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(MdiIcons.deleteOutline,
                          color: AppTheme.fhAccentRed.withValues(alpha: 0.7)),
                      onPressed: () {
                        provider.deleteSubtask(
                            widget.parentTask.id, liveSubTask.id);
                        Navigator.of(context).pop();
                      },
                    )
                  ]
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- TIMER SECTION ---
            if (!liveSubTask.completed)
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppTheme.fhBgDeepDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isRunning
                                  ? AppTheme.fhAccentTeal
                                  : AppTheme.fhBorderColor
                                      .withValues(alpha: 0.5),
                              width: 2)),
                      child: Text(
                        formattedTime,
                        style: const TextStyle(
                            fontFamily: "RobotoCondensed",
                            fontSize: 48,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () {
                        if (isRunning) {
                          provider.pauseTimer(liveSubTask.id);
                          provider.logTimerAndReset(liveSubTask.id);
                        } else {
                          provider.startTimer(
                              liveSubTask.id, 'subtask', widget.parentTask.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(60),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isRunning
                                    ? AppTheme.fhAccentOrange
                                    : AppTheme.fhAccentGreen,
                                width: 3),
                            color: (isRunning
                                    ? AppTheme.fhAccentOrange
                                    : AppTheme.fhAccentGreen)
                                .withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(
                                  color: (isRunning
                                          ? AppTheme.fhAccentOrange
                                          : AppTheme.fhAccentGreen)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2)
                            ]),
                        child: Icon(
                          isRunning ? MdiIcons.pause : MdiIcons.play,
                          color: isRunning
                              ? AppTheme.fhAccentOrange
                              : AppTheme.fhAccentGreen,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Adjust Time: ",
                            style: TextStyle(color: AppTheme.fhTextSecondary)),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _timeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: AppTheme.fhBorderColor)),
                            ),
                            onSubmitted: (val) {
                              final int? newTime = int.tryParse(val);
                              if (newTime != null) {
                                provider.updateSubtask(
                                    widget.parentTask.id,
                                    liveSubTask.id,
                                    {'currentTimeSpent': newTime});
                              }
                            },
                          ),
                        ),
                        const Text(" min",
                            style: TextStyle(color: AppTheme.fhTextSecondary)),
                      ],
                    )
                  ],
                ),
              ),

            if (liveSubTask.completed)
              Center(
                child: Text(
                  "Completed on ${liveSubTask.completedDate} • ${liveSubTask.currentTimeSpent}m logged",
                  style: const TextStyle(
                      color: AppTheme.fhTextDisabled,
                      fontSize: 16,
                      fontStyle: FontStyle.italic),
                ),
              ),

            const SizedBox(height: 40),

            // --- CHECKLIST SECTION ---
            Row(
              children: [
                Text("Checklist",
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.fhBgMedium,
                      color: AppTheme.fhAccentTeal,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text("${(progress * 100).toInt()}%",
                    style: const TextStyle(color: AppTheme.fhTextSecondary))
              ],
            ),
            const SizedBox(height: 16),

            // List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: liveSubTask.subSubTasks.length,
              itemBuilder: (context, index) {
                final sss = liveSubTask.subSubTasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.fhBgMedium.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sss.completed
                              ? AppTheme.fhAccentTeal.withValues(alpha: 0.3)
                              : Colors.transparent)),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => provider.completeSubSubtask(
                            widget.parentTask.id, liveSubTask.id, sss.id),
                        child: Icon(
                            sss.completed
                                ? MdiIcons.checkboxMarked
                                : MdiIcons.checkboxBlankOutline,
                            size: 24,
                            color: sss.completed
                                ? AppTheme.fhAccentTeal
                                : AppTheme.fhTextDisabled),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sss.name,
                          style: TextStyle(
                              color: sss.completed
                                  ? AppTheme.fhTextSecondary
                                  : AppTheme.fhTextPrimary,
                              decoration: sss.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontSize: 16),
                        ),
                      ),
                      if (sss.targetCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: AppTheme.fhBgDeepDark,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text("Target: ${sss.targetCount}",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.fhTextSecondary)),
                        ),
                      if (!liveSubTask.completed)
                        InkWell(
                          onTap: () => provider.deleteSubSubtask(
                              widget.parentTask.id, liveSubTask.id, sss.id),
                          child: Icon(MdiIcons.trashCanOutline,
                              size: 20,
                              color:
                                  AppTheme.fhAccentRed.withValues(alpha: 0.7)),
                        )
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Input
            if (!liveSubTask.completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.fhBgDeepDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.fhBorderColor.withValues(alpha: 0.5))),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          Icon(MdiIcons.plus, color: AppTheme.fhTextSecondary),
                      onPressed: () => _handleAddCheckpoint(provider),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _checkpointController,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.fhTextPrimary),
                        decoration: const InputDecoration(
                            hintText: "Add new checkpoint item...",
                            hintStyle: TextStyle(
                                color: AppTheme.fhTextDisabled, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8)),
                        onSubmitted: (_) => _handleAddCheckpoint(provider),
                      ),
                    ),
                    // Toggle for countable
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isCheckpointCountable,
                        onChanged: (val) =>
                            setState(() => _isCheckpointCountable = val),
                        activeThumbColor: AppTheme.fhAccentTeal,
                        inactiveThumbColor: AppTheme.fhTextDisabled,
                        inactiveTrackColor: AppTheme.fhBgMedium,
                      ),
                    ),
                    if (_isCheckpointCountable)
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _checkpointCountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.fhTextPrimary),
                          decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: "#"),
                        ),
                      ),
                    TextButton(
                        onPressed: () => _handleAddCheckpoint(provider),
                        child: const Text("ADD"))
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}
