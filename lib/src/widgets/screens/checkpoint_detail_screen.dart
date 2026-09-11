import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/utils/step_expansion.dart';
import 'package:missions/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:missions/src/widgets/charts/subtask_progress_time_chart.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_add_step_input.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_detail_header.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_nested_steps_list.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_paste_dialog.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_reminders_dialog.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_selection_toolbar.dart';
import 'package:missions/src/widgets/screens/checkpoint/checkpoint_time_spent_card.dart';
import 'package:provider/provider.dart';

export 'package:missions/src/widgets/screens/checkpoint/checkpoint_add_step_input.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_detail_header.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_nested_steps_list.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_paste_dialog.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_reminders_dialog.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_selection_toolbar.dart';
export 'package:missions/src/widgets/screens/checkpoint/checkpoint_time_spent_card.dart';

class CheckpointDetailScreen extends StatefulWidget {
  final String mainTaskId;
  final String parentSubTaskId;
  final String checkpointId;

  const CheckpointDetailScreen({
    super.key,
    required this.mainTaskId,
    required this.parentSubTaskId,
    required this.checkpointId,
  });

  @override
  State<CheckpointDetailScreen> createState() => _CheckpointDetailScreenState();
}

class _CheckpointDetailScreenState extends State<CheckpointDetailScreen> {
  final TextEditingController _stepController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _newStepType = 'check';
  bool _aiMode = false;
  bool _aiLoading = false;
  bool _isSelectionMode = false;
  Set<String> _selectedKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final cp = _getLiveCheckpoint(provider);
      if (cp != null) {
        _titleController.text = cp.name;
      }
    });
  }

  @override
  void dispose() {
    _stepController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  SubSubTask? _getLiveCheckpoint(AppProvider provider) {
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      final sub = parent.subTasks.firstWhere((s) => s.id == widget.parentSubTaskId);

      SubSubTask? findRecursive(List<SubSubTask> list, String id) {
        for (var item in list) {
          if (item.id == id) return item;
          final found = findRecursive(item.substeps, id);
          if (found != null) return found;
        }
        return null;
      }

      return findRecursive(sub.subSubTasks, widget.checkpointId);
    } catch (e) {
      return null;
    }
  }

  void _copySelected(SubSubTask liveCheckpoint) {
    final buffer = StringBuffer();
    for (final step in liveCheckpoint.substeps) {
      if (_selectedKeys.contains(step.id)) {
        buffer.writeln(step.toCopyStructure());
        buffer.writeln();
      }
    }
    if (buffer.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
      showGlobalToast("Copied selected checkpoints to clipboard");
    }
    setState(() {
      _selectedKeys.clear();
      _isSelectionMode = false;
    });
  }

  void _completeSelected(AppProvider provider, SubSubTask liveCheckpoint) {
    int completedCount = 0;
    for (final stepId in _selectedKeys) {
      final step = liveCheckpoint.substeps.firstWhereOrNull((s) => s.id == stepId);
      if (step != null && !step.completed) {
        provider.taskActions.completeSubSubtask(
            widget.mainTaskId, widget.parentSubTaskId, stepId);
        completedCount++;
      }
    }
    setState(() {
      _selectedKeys.clear();
      _isSelectionMode = false;
    });
    if (completedCount > 0) {
      showGlobalToast("✓ Completed $completedCount checkpoints");
    }
  }

  void _deleteSelected(AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          "DELETE SELECTED OBJECTIVES?",
          style: TextStyle(
            color: JweTheme.textWhite,
            fontFamily: AppTheme.fontDisplay,
          ),
        ),
        content: Text(
          "This action cannot be undone.",
          style: TextStyle(color: JweTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final stepId in _selectedKeys) {
      provider.taskActions.deleteSubSubtask(
          widget.mainTaskId, widget.parentSubTaskId, stepId);
    }
    setState(() {
      _selectedKeys.clear();
      _isSelectionMode = false;
    });
    showGlobalToast("Selected checkpoints deleted");
  }

  void _saveTitle(AppProvider provider, SubSubTask cp) {
    if (_titleController.text.trim() != cp.name) {
      provider.taskActions.updateSubSubtask(
        widget.mainTaskId,
        widget.parentSubTaskId,
        cp.id,
        {'name': _titleController.text.trim()},
      );
    }
  }

  void _addOne(AppProvider provider, SubSubTask parentCp, String name) {
    provider.taskActions.addSubSubtask(
      widget.mainTaskId,
      widget.parentSubTaskId,
      {
        'name': name,
        'type': _newStepType,
        'isCountable': false,
      },
      parentCheckpointId: parentCp.id,
    );
  }

  Future<void> _handleAdd(AppProvider provider, SubSubTask parentCp) async {
    final raw = _stepController.text.trim();
    if (raw.isEmpty) return;

    if (_aiMode) {
      setState(() => _aiLoading = true);
      try {
        final names = await provider.aiGenerationActions
            .generateStepsFromDescription(
                taskName: parentCp.name, description: raw);
        if (names.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("AI returned no steps.")),
            );
          }
          return;
        }
        for (final name in names) {
          _addOne(provider, parentCp, name);
        }
        _stepController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("AI generation failed: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _aiLoading = false);
      }
      return;
    }

    for (final name in expandStepInput(raw)) {
      _addOne(provider, parentCp, name);
    }
    _stepController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final liveCheckpoint = _getLiveCheckpoint(provider);

    if (liveCheckpoint == null) {
      return Scaffold(
        backgroundColor: JweTheme.bgBase,
        body: Center(
          child: Text(
            "Checkpoint not found",
            style: TextStyle(color: JweTheme.textWhite),
          ),
        ),
      );
    }

    Color agentColor = JweTheme.accentCyan;
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      agentColor = parent.taskColor;
    } catch (_) {}

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            CheckpointDetailHeader(
              agentColor: agentColor,
              hasReminder: CheckpointRemindersDialog.hasReminder(provider, liveCheckpoint),
              onBack: () {
                _saveTitle(provider, liveCheckpoint);
                Navigator.pop(context);
              },
              onReminderPressed: () {
                CheckpointRemindersDialog.show(
                  context: context,
                  provider: provider,
                  mainTaskId: widget.mainTaskId,
                  parentSubTaskId: widget.parentSubTaskId,
                  checkpoint: liveCheckpoint,
                  onStateChanged: () => setState(() {}),
                );
              },
              onCopyPressed: () {
                Clipboard.setData(ClipboardData(text: liveCheckpoint.toCopyStructure()));
                showGlobalToast("Objective structure copied to clipboard");
              },
              onPasteTriggered: () {
                CheckpointPasteDialog.handlePaste(
                  context: context,
                  provider: provider,
                  mainTaskId: widget.mainTaskId,
                  parentSubTaskId: widget.parentSubTaskId,
                  liveCheckpoint: liveCheckpoint,
                );
              },
              onDeletePressed: () {
                provider.taskActions.deleteSubSubtask(
                  widget.mainTaskId,
                  widget.parentSubTaskId,
                  liveCheckpoint.id,
                );
                Navigator.pop(context);
              },
              onAcceptDrop: (draggedId) {
                provider.taskActions.moveCheckpointRelative(
                  widget.mainTaskId,
                  widget.parentSubTaskId,
                  draggedId,
                  widget.checkpointId,
                  'after',
                );
              },
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Objective Name",
                        hintStyle: TextStyle(color: JweTheme.textMuted),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => _saveTitle(provider, liveCheckpoint),
                      onSubmitted: (_) => _saveTitle(provider, liveCheckpoint),
                      onEditingComplete: () => _saveTitle(provider, liveCheckpoint),
                    ),
                    const SizedBox(height: 16),

                    CheckpointTimeSpentCard(
                      checkpoint: liveCheckpoint,
                      accentColor: agentColor,
                      onEdit: () {
                        CheckpointTimeSpentCard.showEditDialog(
                          context: context,
                          provider: provider,
                          mainTaskId: widget.mainTaskId,
                          parentSubTaskId: widget.parentSubTaskId,
                          checkpoint: liveCheckpoint,
                          accentColor: agentColor,
                        );
                      },
                    ),

                    ActionPlanWhyCard(
                      initialWhy: liveCheckpoint.why,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(
                        widget.mainTaskId,
                        widget.parentSubTaskId,
                        liveCheckpoint.id,
                        {'why': val},
                      ),
                    ),
                    const SizedBox(height: 16),
                    ActionPlanOutcomeCard(
                      initialWhat: liveCheckpoint.what,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(
                        widget.mainTaskId,
                        widget.parentSubTaskId,
                        liveCheckpoint.id,
                        {'what': val},
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Container(width: 3, height: 10, color: agentColor),
                        const SizedBox(width: 8),
                        Icon(MdiIcons.chartLine, size: 12, color: agentColor),
                        const SizedBox(width: 6),
                        Text(
                          "PROGRESS · TIME",
                          style: GoogleFonts.jetBrainsMono(
                            color: agentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SubtaskProgressTimeChart(
                      dataPoints: liveCheckpoint.progressDataPoints,
                      accentColor: agentColor,
                      currentSpentSeconds: math.max(
                        liveCheckpoint.currentTimeSpent,
                        liveCheckpoint.timeSpentMinutes * 60,
                      ),
                      currentProgress: liveCheckpoint.calculateProgress(),
                      onAddEntry: (progress, spentSeconds) {
                        provider.taskActions.saveSubSubtaskProgressDataPoint(
                          widget.mainTaskId,
                          widget.parentSubTaskId,
                          liveCheckpoint.id,
                          progress,
                          spentSeconds,
                        );
                      },
                      onDeleteEntry: (index) {
                        provider.taskActions.deleteSubSubtaskProgressDataPoint(
                          widget.mainTaskId,
                          widget.parentSubTaskId,
                          liveCheckpoint.id,
                          index,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    CheckpointSelectionToolbar(
                      isSelectionMode: _isSelectionMode,
                      selectedCount: _selectedKeys.length,
                      totalCount: liveCheckpoint.substeps.length,
                      agentColor: agentColor,
                      onToggleSelectAll: () {
                        setState(() {
                          if (_selectedKeys.length == liveCheckpoint.substeps.length) {
                            _selectedKeys.clear();
                          } else {
                            _selectedKeys =
                                liveCheckpoint.substeps.map((e) => e.id).toSet();
                          }
                        });
                      },
                      onCopySelected: () => _copySelected(liveCheckpoint),
                      onCompleteSelected: () =>
                          _completeSelected(provider, liveCheckpoint),
                      onDeleteSelected: () => _deleteSelected(provider),
                      onCancelSelection: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedKeys.clear();
                        });
                      },
                      onEnterSelectionMode: () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedKeys.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    CheckpointNestedStepsList(
                      substeps: liveCheckpoint.substeps,
                      agentColor: agentColor,
                      isSelectionMode: _isSelectionMode,
                      selectedKeys: _selectedKeys,
                      onToggleSubstep: (grand) {
                        if (grand.completed) {
                          provider.taskActions.uncompleteSubSubtask(
                            widget.mainTaskId,
                            widget.parentSubTaskId,
                            grand.id,
                          );
                        } else {
                          provider.taskActions.completeSubSubtask(
                            widget.mainTaskId,
                            widget.parentSubTaskId,
                            grand.id,
                          );
                        }
                      },
                      onOpenChild: (child) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckpointDetailScreen(
                              mainTaskId: widget.mainTaskId,
                              parentSubTaskId: widget.parentSubTaskId,
                              checkpointId: child.id,
                            ),
                          ),
                        );
                      },
                      onToggleCompleted: (child) {
                        final updates = {'completed': !child.completed};
                        provider.taskActions.updateSubSubtask(
                          widget.mainTaskId,
                          widget.parentSubTaskId,
                          child.id,
                          updates,
                        );
                      },
                      onDeleteChild: (child) => provider.taskActions.deleteSubSubtask(
                        widget.mainTaskId,
                        widget.parentSubTaskId,
                        child.id,
                      ),
                      onDuplicateChild: (child) =>
                          provider.taskActions.duplicateSubSubtask(
                        widget.mainTaskId,
                        widget.parentSubTaskId,
                        child.id,
                      ),
                      onToggleType: (child) {
                        final newType = child.type == 'check' ? 'info' : 'check';
                        provider.taskActions.updateSubSubtask(
                          widget.mainTaskId,
                          widget.parentSubTaskId,
                          child.id,
                          {'type': newType},
                        );
                      },
                      onSelectedChanged: (childId, isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedKeys.add(childId);
                          } else {
                            _selectedKeys.remove(childId);
                          }
                        });
                      },
                      onMoveChild: (draggedId, targetId, pos) {
                        provider.taskActions.moveCheckpointRelative(
                          widget.mainTaskId,
                          widget.parentSubTaskId,
                          draggedId,
                          targetId,
                          pos,
                        );
                      },
                    ),

                    CheckpointAddStepInput(
                      controller: _stepController,
                      stepType: _newStepType,
                      aiMode: _aiMode,
                      aiLoading: _aiLoading,
                      agentColor: agentColor,
                      onStepTypeChanged: (val) => setState(() => _newStepType = val),
                      onToggleAiMode: () => setState(() => _aiMode = !_aiMode),
                      onAdd: () => _handleAdd(provider, liveCheckpoint),
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
}