import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/step_expansion.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:missions/src/widgets/items/checkpoint_item.dart';
import 'package:missions/src/widgets/items/draggable_checkpoint_wrapper.dart';
import 'package:missions/src/widgets/screens/checkpoint_detail_screen.dart';
import 'package:missions/src/widgets/dialogs/ai_generation_prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionPlanStepsList extends StatefulWidget {
  final String mainTaskId;
  final String subTaskId;
  final List<SubSubTask> steps;
  final Function(String) onGenerate;
  final Color accentColor;

  const ActionPlanStepsList({
    super.key,
    required this.mainTaskId,
    required this.subTaskId,
    required this.steps,
    required this.onGenerate,
    required this.accentColor,
  });

  @override
  State<ActionPlanStepsList> createState() => _ActionPlanStepsListState();
}

class _ActionPlanStepsListState extends State<ActionPlanStepsList> {
  final TextEditingController _stepController = TextEditingController();
  bool _aiMode = false;
  bool _aiLoading = false;
  bool _isSelectionMode = false;
  Set<String> _selectedKeys = {};

  void _copySelected() {
    final buffer = StringBuffer();
    for (final step in widget.steps) {
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

  void _completeSelected(AppProvider provider) {
    int completedCount = 0;
    for (final stepId in _selectedKeys) {
      final step = widget.steps.firstWhereOrNull((s) => s.id == stepId);
      if (step != null && !step.completed) {
        provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.subTaskId, stepId);
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
        backgroundColor: AppTheme.fhBgDark,
        title: Text("DELETE SELECTED OBJECTIVES?", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
        content: Text("This action cannot be undone.", style: TextStyle(color: AppTheme.fhTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete")
          ),
        ],
      )
    );
    if (confirm != true) return;

    for (final stepId in _selectedKeys) {
      provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.subTaskId, stepId);
    }
    setState(() {
      _selectedKeys.clear();
      _isSelectionMode = false;
    });
    showGlobalToast("Selected checkpoints deleted");
  }

  Future<void> _handleAdd(AppProvider provider) async {
    final raw = _stepController.text.trim();
    if (raw.isEmpty) return;

    if (_aiMode) {
      setState(() => _aiLoading = true);
      try {
        final mainTask =
            provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
        final subTask =
            mainTask.subTasks.firstWhere((s) => s.id == widget.subTaskId);
        final names = await provider.aiGenerationActions
            .generateStepsFromDescription(
                taskName: subTask.name, description: raw);
        if (names.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("AI returned no steps.")),
            );
          }
          return;
        }
        for (final name in names) {
          provider.taskActions.addSubSubtask(widget.mainTaskId, widget.subTaskId, {
            'name': name,
            'isCountable': false,
            'targetCount': 0,
            'type': 'check',
          });
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

    final names = expandStepInput(raw);
    for (final name in names) {
      provider.taskActions.addSubSubtask(widget.mainTaskId, widget.subTaskId, {
        'name': name,
        'isCountable': false,
        'targetCount': 0,
        'type': 'check',
      });
    }
    _stepController.clear();
  }

  void _navigateToStepDetail(BuildContext context, SubSubTask step) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
      mainTaskId: widget.mainTaskId,
      parentSubTaskId: widget.subTaskId,
      checkpointId: step.id,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isLoading = provider.loadingTaskName == "Generating Strategy...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3)))
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              if (_isSelectionMode) ...[
                Text(
                  "${_selectedKeys.length} SELECTED",
                  style: GoogleFonts.jetBrainsMono(
                    color: widget.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.select_all, size: 18),
                      color: JweTheme.textWhite,
                      onPressed: () {
                        setState(() {
                          if (_selectedKeys.length == widget.steps.length) {
                            _selectedKeys.clear();
                          } else {
                            _selectedKeys = widget.steps.map((e) => e.id).toSet();
                          }
                        });
                      },
                      tooltip: _selectedKeys.length == widget.steps.length ? "Deselect All" : "Select All",
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: widget.accentColor,
                      onPressed: _selectedKeys.isEmpty ? null : _copySelected,
                      tooltip: "Copy Selected",
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      color: widget.accentColor,
                      onPressed: _selectedKeys.isEmpty ? null : () => _completeSelected(provider),
                      tooltip: "Complete Selected",
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.fhAccentRed,
                      onPressed: _selectedKeys.isEmpty ? null : () => _deleteSelected(provider),
                      tooltip: "Delete Selected",
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: JweTheme.textMuted,
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedKeys.clear();
                        });
                      },
                      tooltip: "Cancel",
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ] else ...[
                Text("TACTICAL EXECUTION (HOW)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                if (widget.steps.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.playlist_add_check, color: widget.accentColor, size: 18),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedKeys.clear();
                      });
                    },
                    tooltip: "Select Multiple",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        if (widget.steps.isEmpty && !isLoading)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
              color: AppTheme.fhBgDark.withOpacity(0.5)
            ),
            child:   Text("No steps defined yet.", style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.steps.length,
            itemBuilder: (ctx, index) {
              final step = widget.steps[index];
              final item = CheckpointItem(
                key: ValueKey(step.id),
                title: step.name,
                isCompleted: step.completed,
                type: step.type,
                hasCheckableSubsteps: step.hasCheckableSubsteps,
                progress: step.calculateProgress(),
                accentColor: widget.accentColor,
                substeps: step.substeps,
                onToggleSubstep: (sub) {
                  if (sub.completed) {
                    provider.taskActions.uncompleteSubSubtask(widget.mainTaskId, widget.subTaskId, sub.id);
                  } else {
                    provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.subTaskId, sub.id);
                  }
                },
                onTap: () => _navigateToStepDetail(context, step),
                onPlay: null,
                isRunning: false,
                onToggle: () {
                  if (step.completed) {
                    provider.taskActions.uncompleteSubSubtask(widget.mainTaskId, widget.subTaskId, step.id);
                  } else {
                    provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.subTaskId, step.id);
                  }
                },
                onDelete: () => provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.subTaskId, step.id),
                onDuplicate: () => provider.taskActions.duplicateSubSubtask(widget.mainTaskId, widget.subTaskId, step.id),
                onToggleType: () {
                  final newType = step.type == 'check' ? 'info' : 'check';
                  provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.subTaskId, step.id, {'type': newType});
                },
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedKeys.contains(step.id),
                onSelectedChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedKeys.add(step.id);
                    } else {
                      _selectedKeys.remove(step.id);
                    }
                  });
                },
              );

              if (_isSelectionMode) {
                return item;
              }
              return DraggableCheckpointWrapper(
                checkpointId: step.id,
                onMove: (draggedId, targetId, pos) {
                  provider.taskActions.moveCheckpointRelative(widget.mainTaskId, widget.subTaskId, draggedId, targetId, pos);
                },
                child: item,
              );
            },
          ),

        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Expanded(
                child: TextField(
                  controller: _stepController,
                  style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 14),
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _aiMode
                        ? "DESCRIBE STEPS FOR AI..."
                        : "ADD STEP...   (try  Push-ups*5  or  Lap %d * 3)",
                    hintStyle:   TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12, letterSpacing: 1.0),
                    border:   OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                    enabledBorder:   OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.accentColor)),
                    filled: true,
                    fillColor: AppTheme.fhBgDark.withOpacity(0.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _aiLoading ? null : () => setState(() => _aiMode = !_aiMode),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _aiMode
                        ? widget.accentColor.withOpacity(0.18)
                        : Colors.transparent,
                    border: Border.all(
                      color: _aiMode
                          ? widget.accentColor
                          : AppTheme.fhBorderColor,
                    ),
                  ),
                  child: Icon(
                    MdiIcons.autoFix,
                    color: _aiMode ? widget.accentColor : AppTheme.fhTextSecondary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _aiLoading ? null : () => _handleAdd(provider),
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(top: 2),
                  color: widget.accentColor.withOpacity(0.2),
                  alignment: Alignment.center,
                  child: _aiLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                          ),
                        )
                      : Text("+", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}