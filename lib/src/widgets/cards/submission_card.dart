import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class SubmissionCard extends StatefulWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionCard({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  @override
  State<SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<SubmissionCard> {
  final TextEditingController _checkpointController = TextEditingController();
  bool _isCheckpointCountable = false;
  final TextEditingController _checkpointCountController = TextEditingController(text: '5');

  late TextEditingController _timeController;
  
  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: widget.subTask.currentTimeSpent.toString());
  }

  @override
  void dispose() {
    _checkpointController.dispose();
    _checkpointCountController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SubmissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subTask.currentTimeSpent != widget.subTask.currentTimeSpent) {
        if (!_timeController.selection.isValid) {
           _timeController.text = widget.subTask.currentTimeSpent.toString();
        }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[widget.subTask.id];
    
    final int totalCheckpoints = widget.subTask.subSubTasks.length;
    final int completedCheckpoints = widget.subTask.subSubTasks.where((s) => s.completed).length;
    final double progress = totalCheckpoints > 0 ? completedCheckpoints / totalCheckpoints : 0.0;

    final double displayTimeSeconds = timerState != null
        ? (timerState.isRunning
            ? timerState.accumulatedDisplayTime +
                (DateTime.now().difference(timerState.startTime).inMilliseconds / 1000)
            : timerState.accumulatedDisplayTime)
        : widget.subTask.currentTimeSpent * 60.0;

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    final cardBorderColor = isRunning ? AppTheme.fhAccentTeal : AppTheme.fhBorderColor.withValues(alpha: 0.5);
    final glowColor = isRunning ? AppTheme.fhAccentTeal.withValues(alpha: 0.15) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 2)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10)
              )
            ),
            child: Row(
              children: [
                RhombusCheckbox(
                  checked: widget.subTask.completed,
                  onChanged: (val) => provider.completeSubtask(widget.parentTask.id, widget.subTask.id),
                  disabled: widget.subTask.completed,
                  size: CheckboxSize.small,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.subTask.name.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: widget.subTask.completed ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Completed state options
                if (widget.subTask.completed) ...[
                  IconButton(
                    icon:  Icon(MdiIcons.contentCopy, size: 16, color: AppTheme.fhTextSecondary),
                    onPressed: () => provider.duplicateCompletedSubtask(widget.parentTask.id, widget.subTask.id),
                    tooltip: "Duplicate Task",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:  Icon(MdiIcons.deleteOutline, size: 18, color: AppTheme.fhAccentRed.withValues(alpha: 0.7)),
                    onPressed: () => provider.deleteSubtask(widget.parentTask.id, widget.subTask.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ] else ...[
                  IconButton(
                    icon:  Icon(MdiIcons.pencilOutline, size: 16, color: AppTheme.fhTextSecondary),
                    onPressed: () {},
                    tooltip: "Edit Task",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:  Icon(MdiIcons.deleteOutline, size: 18, color: AppTheme.fhAccentRed),
                    onPressed: () => provider.deleteSubtask(widget.parentTask.id, widget.subTask.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ]
              ],
            ),
          ),

          if (!widget.subTask.completed) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TIMER SECTION ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.fhBgDeepDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5))
                        ),
                        child: Text(
                          formattedTime,
                          style: const TextStyle(
                            fontFamily: "RobotoCondensed", 
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.white
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                           if (isRunning) {
                             provider.pauseTimer(widget.subTask.id);
                             provider.logTimerAndReset(widget.subTask.id);
                           } else {
                             provider.startTimer(widget.subTask.id, 'subtask', widget.parentTask.id);
                           }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isRunning ? AppTheme.fhAccentOrange : AppTheme.fhAccentGreen,
                              width: 1.5
                            ),
                            color: (isRunning ? AppTheme.fhAccentOrange : AppTheme.fhAccentGreen).withValues(alpha: 0.1)
                          ),
                          child: Icon(
                            isRunning ? MdiIcons.pause : MdiIcons.play,
                            color: isRunning ? AppTheme.fhAccentOrange : AppTheme.fhAccentGreen,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Manual Time Edit (Compact)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text("Manually: ", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: _timeController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                                ),
                                onSubmitted: (val) {
                                  final int? newTime = int.tryParse(val);
                                  if (newTime != null) {
                                    provider.updateSubtask(widget.parentTask.id, widget.subTask.id, {'currentTimeSpent': newTime});
                                  }
                                },
                              ),
                            ),
                            const Text("m", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- CHECKLIST PROGRESS ---
                  Row(
                    children: [
                      Text("Checklist", style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppTheme.fhBgMedium,
                            color: AppTheme.fhAccentTeal,
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- CHECKLIST ITEMS ---
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.subTask.subSubTasks.length,
                    itemBuilder: (context, index) {
                      final sss = widget.subTask.subSubTasks[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.fhBgMedium.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: sss.completed ? AppTheme.fhAccentTeal.withValues(alpha: 0.3) : Colors.transparent)
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => provider.completeSubSubtask(widget.parentTask.id, widget.subTask.id, sss.id),
                              child: Icon(
                                MdiIcons.rhombusMedium, 
                                size: 16, 
                                color: sss.completed ? AppTheme.fhAccentTeal : AppTheme.fhTextDisabled
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sss.name,
                                style: TextStyle(
                                  color: sss.completed ? AppTheme.fhTextSecondary : AppTheme.fhTextPrimary,
                                  decoration: sss.completed ? TextDecoration.lineThrough : null,
                                  fontSize: 13
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => provider.deleteSubSubtask(widget.parentTask.id, widget.subTask.id, sss.id),
                              child: Icon(MdiIcons.trashCanOutline, size: 16, color: AppTheme.fhAccentRed.withValues(alpha: 0.7)),
                            )
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // --- ADD CHECKPOINT INPUT ---
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDeepDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5))
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _checkpointController,
                            style: const TextStyle(fontSize: 13, color: AppTheme.fhTextPrimary),
                            decoration: const InputDecoration(
                              hintText: "Add a checkpoint...",
                              hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12)
                            ),
                            onSubmitted: (_) => _handleAddCheckpoint(provider),
                          ),
                        ),
                        // Toggle for countable
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: _isCheckpointCountable, 
                            onChanged: (val) => setState(() => _isCheckpointCountable = val),
                            activeColor: AppTheme.fhAccentTeal,
                            inactiveThumbColor: AppTheme.fhTextDisabled,
                            inactiveTrackColor: AppTheme.fhBgMedium,
                          ),
                        ),
                        if (_isCheckpointCountable)
                          SizedBox(
                            width: 30,
                            child: TextField(
                              controller: _checkpointCountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: AppTheme.fhTextPrimary),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none
                              ),
                            ),
                          ),
                        IconButton(
                          icon:  Icon(MdiIcons.plusCircle, color: AppTheme.fhAccentGreen),
                          onPressed: () => _handleAddCheckpoint(provider),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ] else ...[
             Padding(
               padding: const EdgeInsets.all(12.0),
               child: Text(
                 "Completed on ${widget.subTask.completedDate} • ${widget.subTask.currentTimeSpent}m logged",
                 style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12, fontStyle: FontStyle.italic),
               ),
             )
          ]
        ],
      ),
    );
  }
}