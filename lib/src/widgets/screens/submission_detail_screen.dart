import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/dialogs/edit_subtask_dialog.dart';
import 'package:arcane/src/widgets/dialogs/add_session_dialog.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/widgets/ui/schedule_timeline.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _checkpointController.dispose();
    _checkpointCountController.dispose();
    super.dispose();
  }

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
    }
  }

  void _showAddSessionDialog(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => const AddSessionDialog(),
    );

    if (result != null) {
      // Ensure the added session respects the selected day
      final startBase = result['start']!;
      final endBase = result['end']!;

      final realStart = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        startBase.hour, startBase.minute
      );
      var realEnd = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        endBase.hour, endBase.minute
      );
      if (realEnd.isBefore(realStart)) {
        realEnd = realEnd.add(const Duration(days: 1));
      }

      provider.addSessionToSubtask(
          widget.parentTask.id, widget.subTask.id, realStart, realEnd);
    }
  }

  void _handleSessionEdit(BuildContext context, AppProvider provider,
      TaskSession session) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(
        initialStart: session.startTime,
        initialEnd: session.endTime,
      ),
    );

    if (result != null) {
      final action = result['action'];
      if (action == 'delete') {
        provider.deleteSessionFromSubtask(
            widget.parentTask.id, widget.subTask.id, session.id);
      } else if (action == 'save') {
        final newStart = result['start'] as DateTime;
        final newEnd = result['end'] as DateTime;
        provider.updateSessionInSubtask(widget.parentTask.id, widget.subTask.id,
            session.id, newStart, newEnd);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.fhAccentTeal,
              onPrimary: AppTheme.fhBgDeepDark,
              surface: AppTheme.fhBgMedium,
              onSurface: AppTheme.fhTextPrimary,
            ),
            dialogBackgroundColor: AppTheme.fhBgDark,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);
    final liveSubTask = _getLiveSubTask(provider);

    if (liveSubTask == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final timerState = provider.activeTimers[liveSubTask.id];
    final double displayTimeSeconds = timerState != null
        ? (timerState.isRunning
            ? timerState.accumulatedDisplayTime +
                (DateTime.now().difference(timerState.startTime).inMilliseconds /
                    1000)
            : timerState.accumulatedDisplayTime)
        : liveSubTask.currentTimeSpent * 60.0;

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    // Filter sessions by selected day
    final filteredSessions = liveSubTask.sessions.where((s) {
      return s.startTime.year == _selectedDate.year &&
          s.startTime.month == _selectedDate.month &&
          s.startTime.day == _selectedDate.day;
    }).toList();

    // Responsive Layout Check
    final isLandscape = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header (Task Name) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      liveSubTask.name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.pencilOutline,
                        color: AppTheme.fhTextSecondary),
                    onPressed: () =>
                        _handleEditSubtask(context, provider, liveSubTask),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLandscape
                  ? Row(
                      children: [
                        // Left Column: Timer & Checkpoints
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTimerBox(context, provider, liveSubTask,
                                    formattedTime, isRunning),
                                const SizedBox(height: 24),
                                _buildCheckpointsSection(
                                    context, provider, liveSubTask, theme),
                              ],
                            ),
                          ),
                        ),
                        // Vertical Divider
                        Container(
                            width: 1,
                            color: AppTheme.fhBorderColor.withOpacity(0.3)),
                        // Right Column: Timeline
                        Expanded(
                          flex: 5,
                          child: _buildTimelineSection(context, provider,
                              filteredSessions, theme),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTimerBox(context, provider, liveSubTask,
                              formattedTime, isRunning),
                          const SizedBox(height: 24),

                          // Checkpoints Section
                          _buildCheckpointsSection(
                              context, provider, liveSubTask, theme),

                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Timeline Section (Vertical stack on mobile)
                          SizedBox(
                            height: 400,
                            child: _buildTimelineSection(context, provider,
                                filteredSessions, theme),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerBox(BuildContext context, AppProvider provider,
      SubTask subTask, String time, bool isRunning) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isRunning
                ? AppTheme.fhAccentTeal
                : AppTheme.fhBorderColor.withOpacity(0.3),
            width: 2),
        boxShadow: isRunning
            ? [
                BoxShadow(
                    color: AppTheme.fhAccentTeal.withOpacity(0.2),
                    blurRadius: 15)
              ]
            : [],
      ),
      child: Column(
        children: [
          Text(
            time,
            style: const TextStyle(
              fontFamily: "RobotoCondensed",
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 48,
                icon: Icon(
                    isRunning ? MdiIcons.pauseCircle : MdiIcons.playCircle,
                    color: isRunning
                        ? AppTheme.fhAccentOrange
                        : AppTheme.fhAccentGreen),
                onPressed: () {
                  if (isRunning) {
                    provider.pauseTimer(subTask.id);
                    // provider.logTimerAndReset(subTask.id); // Handled by pauseTimer now for session logic
                  } else {
                    provider.startTimer(
                        subTask.id, 'subtask', widget.parentTask.id);
                  }
                },
              ),
              if (isRunning) ...[
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: AppTheme.fhAccentRed),
                  onPressed: () {
                    // provider.pauseTimer(subTask.id);
                    provider.logTimerAndReset(subTask.id);
                  },
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointsSection(BuildContext context, AppProvider provider,
      SubTask subTask, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Checkpoints",
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppTheme.fhTextSecondary)),
          ],
        ),
        const SizedBox(height: 8),

        // List
        ...subTask.subSubTasks.map((sss) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.fhBgMedium.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  RhombusCheckbox(
                    checked: sss.completed,
                    size: CheckboxSize.small,
                    onChanged: (_) => provider.completeSubSubtask(
                        widget.parentTask.id, subTask.id, sss.id),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sss.name,
                      style: TextStyle(
                        decoration:
                            sss.completed ? TextDecoration.lineThrough : null,
                        color: sss.completed
                            ? AppTheme.fhTextSecondary
                            : AppTheme.fhTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: AppTheme.fhTextSecondary),
                    onPressed: () => provider.deleteSubSubtask(
                        widget.parentTask.id, subTask.id, sss.id),
                  )
                ],
              ),
            )),

        // Input Area
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _checkpointController,
                  decoration: const InputDecoration(
                    hintText: "New checkpoint...",
                    border: InputBorder.none,
                    hintStyle:
                        TextStyle(fontSize: 13, color: AppTheme.fhTextSecondary),
                  ),
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.fhTextPrimary),
                  onSubmitted: (_) => _handleAddCheckpoint(provider),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add,
                    size: 20, color: AppTheme.fhAccentTeal),
                onPressed: () => _handleAddCheckpoint(provider),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection(BuildContext context, AppProvider provider,
      List<TaskSession> sessions, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(_selectedDate),
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.fhTextSecondary)
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Log Time"),
              onPressed: () => _showAddSessionDialog(context, provider),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.fhAccentPurple),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ScheduleTimeline(
                sessions: sessions,
                onAddSession: () => _showAddSessionDialog(context, provider),
                onEditSession: (session) =>
                    _handleSessionEdit(context, provider, session),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
