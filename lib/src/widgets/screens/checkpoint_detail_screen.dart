import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/utils/step_expansion.dart';
import 'package:missions/src/widgets/items/checkpoint_item.dart';
import 'package:missions/src/widgets/items/draggable_checkpoint_wrapper.dart';
import 'package:missions/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:missions/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:missions/src/theme/jwe_theme.dart';

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
  bool _isHeaderHovered = false;
  bool _aiMode = false;
  bool _aiLoading = false;
  bool _isSelectionMode = false;
  Set<String> _selectedKeys = {};

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
        provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.parentSubTaskId, stepId);
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
      provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, stepId);
    }
    setState(() {
      _selectedKeys.clear();
      _isSelectionMode = false;
    });
    showGlobalToast("Selected checkpoints deleted");
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

  void _saveTitle(AppProvider provider, SubSubTask cp) {
    if (_titleController.text.trim() != cp.name) {
      provider.taskActions.updateSubSubtask(
        widget.mainTaskId, widget.parentSubTaskId, cp.id,
        {'name': _titleController.text.trim()}
      );
    }
  }

  bool _hasReminder(AppProvider provider, SubSubTask cp) {
    return provider.getCheckpointReminders(cp.id).any((r) => r.isActive);
  }

  void _showRemindersListDialog(BuildContext context, AppProvider provider, SubSubTask cp) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rems = provider.getCheckpointReminders(cp.id);
            return AlertDialog(
              backgroundColor: AppTheme.fhBgDark,
              title: Text(
                "OBJECTIVE REMINDERS",
                style: GoogleFonts.rajdhani(
                  color: AppTheme.fhAccentTeal,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rems.isEmpty)
                        Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No reminders configured.",
                          style: TextStyle(color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: rems.length,
                          itemBuilder: (context, index) {
                            final r = rems[index];
                            String timeStr = '';
                            if (r.repeat == 'daily') {
                              timeStr = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')} (Daily)';
                            } else if (r.time != null) {
                              timeStr = '${DateFormat('MMM d, HH:mm').format(r.time!)} (Once)';
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.fhBgDeepDark,
                                border: Border.all(color: AppTheme.fhBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(MdiIcons.bellRing, color: AppTheme.fhAccentTeal, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      timeStr,
                                      style: GoogleFonts.jetBrainsMono(color: AppTheme.fhTextPrimary, fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed, size: 18),
                                    onPressed: () {
                                      provider.deleteReminder(r.id);
                                      setDialogState(() {});
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(MdiIcons.plus, size: 16),
                      label: const Text("ADD REMINDER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.fhAccentTeal,
                        foregroundColor: JweTheme.onAccent,
                        shape: const BeveledRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final repeat = await showDialog<String>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            backgroundColor: AppTheme.fhBgDark,
                            title:   Text("REPEAT OPTION", style: TextStyle(color: AppTheme.fhTextPrimary)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title:   Text("ONCE", style: TextStyle(color: AppTheme.fhTextPrimary)),
                                  onTap: () => Navigator.pop(ctx2, 'once'),
                                ),
                                ListTile(
                                  title:   Text("DAILY", style: TextStyle(color: AppTheme.fhTextPrimary)),
                                  onTap: () => Navigator.pop(ctx2, 'daily'),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (repeat == null) return;

                        final now = DateTime.now();
                        DateTime date = now;
                        if (repeat == 'once') {
                          final pickedDate = await showDatePicker(
                            context: ctx,
                            initialDate: now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme:   ColorScheme.dark(
                                  primary: AppTheme.fhAccentTeal,
                                  surface: AppTheme.fhBgDark,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (pickedDate == null) return;
                          date = pickedDate;
                        }

                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(now),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme:   ColorScheme.dark(
                                primary: AppTheme.fhAccentTeal,
                                surface: AppTheme.fhBgDark,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (time == null) return;

                        var scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        if (repeat == 'daily' && scheduled.isBefore(now)) {
                          scheduled = scheduled.add(const Duration(days: 1));
                        }

                        await provider.addCheckpointReminder(widget.mainTaskId, widget.parentSubTaskId, cp.id, scheduled, repeat);
                        setDialogState(() {});
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:   Text("CLOSE", style: TextStyle(color: AppTheme.fhTextSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
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
      return   Scaffold(backgroundColor: AppTheme.fhBgDeepDark, body: Center(child: Text("Checkpoint not found", style: TextStyle(color: AppTheme.fhTextPrimary))));
    }

    Color agentColor = AppTheme.fhAccentTeal;
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      agentColor = parent.taskColor;
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children:[
            // Header (Drag Target to move item outside/after)
            DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                provider.taskActions.moveCheckpointRelative(
                  widget.mainTaskId, widget.parentSubTaskId, details.data, widget.checkpointId, 'after'
                );
                setState(() => _isHeaderHovered = false);
              },
              onMove: (_) => setState(() => _isHeaderHovered = true),
              onLeave: (_) => setState(() => _isHeaderHovered = false),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _isHeaderHovered ? AppTheme.fhAccentTeal : AppTheme.fhBorderColor.withOpacity(0.3))),
                    color: _isHeaderHovered ? AppTheme.fhAccentTeal.withOpacity(0.1) : AppTheme.fhBgDark,
                  ),
                  child: Row(
                    children:[
                       InkWell(
                        onTap: () {
                          _saveTitle(provider, liveCheckpoint);
                          Navigator.pop(context);
                        },
                        child:   Icon(Icons.arrow_back, color: AppTheme.fhTextSecondary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _isHeaderHovered ? "DROP TO MOVE OUTSIDE" : "OBJECTIVE DETAIL",
                          style: TextStyle(
                            color: agentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            fontFamily: AppTheme.fontDisplay
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _hasReminder(provider, liveCheckpoint)
                              ? MdiIcons.bellRing
                              : MdiIcons.bellOutline,
                          color: _hasReminder(provider, liveCheckpoint)
                              ? AppTheme.fhAccentTeal
                              : AppTheme.fhTextSecondary,
                        ),
                        onPressed: () => _showRemindersListDialog(context, provider, liveCheckpoint),
                        tooltip: 'Set Reminder',
                      ),
                      GestureDetector(
                        onLongPress: () => _handlePaste(context, provider, liveCheckpoint),
                        onSecondaryTap: () => _handlePaste(context, provider, liveCheckpoint),
                        child: IconButton(
                          icon: Icon(MdiIcons.contentCopy, color: AppTheme.fhTextSecondary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: liveCheckpoint.toCopyStructure()));
                            showGlobalToast("Objective structure copied to clipboard");
                          },
                        ),
                      ),
                      IconButton(
                        icon:  Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
                        onPressed: () {
                          provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id);
                          Navigator.pop(context);
                        },
                      )
                    ],
                  ),
                );
              }
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    // Title Input
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "Objective Name"),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => _saveTitle(provider, liveCheckpoint),
                      onSubmitted: (_) => _saveTitle(provider, liveCheckpoint),
                      onEditingComplete: () => _saveTitle(provider, liveCheckpoint),
                    ),
                    const SizedBox(height: 24),

                    // Why/What
                    ActionPlanWhyCard(
                      initialWhy: liveCheckpoint.why,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'why': val}),
                    ),
                    const SizedBox(height: 16),
                    ActionPlanOutcomeCard(
                      initialWhat: liveCheckpoint.what,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'what': val}),
                    ),

                    const SizedBox(height: 32),

                    // Nested Steps
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3)))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_isSelectionMode) ...[
                            Text(
                              "${_selectedKeys.length} SELECTED",
                              style: GoogleFonts.jetBrainsMono(
                                color: agentColor,
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
                                      if (_selectedKeys.length == liveCheckpoint.substeps.length) {
                                        _selectedKeys.clear();
                                      } else {
                                        _selectedKeys = liveCheckpoint.substeps.map((e) => e.id).toSet();
                                      }
                                    });
                                  },
                                  tooltip: _selectedKeys.length == liveCheckpoint.substeps.length ? "Deselect All" : "Select All",
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  color: agentColor,
                                  onPressed: _selectedKeys.isEmpty ? null : () => _copySelected(liveCheckpoint),
                                  tooltip: "Copy Selected",
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  color: agentColor,
                                  onPressed: _selectedKeys.isEmpty ? null : () => _completeSelected(provider, liveCheckpoint),
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
                            Text("SUB-ROUTINES (NESTED)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            if (liveCheckpoint.substeps.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.playlist_add_check, color: agentColor, size: 18),
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
                    
                    if (liveCheckpoint.substeps.isEmpty)
                        Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text("No nested instructions.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: liveCheckpoint.substeps.length,
                        itemBuilder: (ctx, index) {
                          final child = liveCheckpoint.substeps[index];
                          final item = CheckpointItem(
                            key: ValueKey(child.id),
                            title: child.name,
                            isCompleted: child.completed,
                            type: child.type,
                            accentColor: agentColor,
                            hasCheckableSubsteps: child.hasCheckableSubsteps,
                            progress: child.calculateProgress(),
                            substeps: child.substeps,
                            onToggleSubstep: (grand) {
                              if (grand.completed) {
                                provider.taskActions.uncompleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, grand.id);
                              } else {
                                provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.parentSubTaskId, grand.id);
                              }
                            },
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
                                mainTaskId: widget.mainTaskId,
                                parentSubTaskId: widget.parentSubTaskId,
                                checkpointId: child.id,
                              )));
                            },
                            onToggle: () {
                              final updates = {'completed': !child.completed};
                              provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id, updates);
                            },
                            onDelete: () => provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id),
                            onDuplicate: () => provider.taskActions.duplicateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id),
                            onToggleType: () {
                              final newType = child.type == 'check' ? 'info' : 'check';
                              provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id, {'type': newType});
                            },
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedKeys.contains(child.id),
                            onSelectedChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedKeys.add(child.id);
                                } else {
                                  _selectedKeys.remove(child.id);
                                }
                              });
                            },
                          );

                          if (_isSelectionMode) {
                            return item;
                          }
                          return DraggableCheckpointWrapper(
                            checkpointId: child.id,
                            onMove: (draggedId, targetId, pos) {
                               provider.taskActions.moveCheckpointRelative(widget.mainTaskId, widget.parentSubTaskId, draggedId, targetId, pos);
                            },
                            child: item,
                          );
                        },
                      ),

                    // Add Substep
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark.withOpacity(0.5),
                        border: Border.all(color: AppTheme.fhBorderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: PopupMenuButton<String>(
                              icon: Icon(_newStepType == 'info' ? MdiIcons.informationOutline : MdiIcons.checkboxMarkedOutline, color: AppTheme.fhTextSecondary, size: 20),
                              onSelected: (val) => setState(() => _newStepType = val),
                              color: AppTheme.fhBgDark,
                              itemBuilder: (context) =>[
                                  PopupMenuItem(value: 'check', child: Text("Checkable", style: TextStyle(color: AppTheme.fhTextPrimary))),
                                  PopupMenuItem(value: 'info', child: Text("Info", style: TextStyle(color: AppTheme.fhTextPrimary))),
                              ],
                            ),
                          ),
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
                                    ? "DESCRIBE NESTED STEPS FOR AI..."
                                    : "ADD NESTED STEP...   (try  Rep*8  or  Set %d * 4)",
                                hintStyle:   TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _aiMode ? "AI mode on" : "Turn on AI mode",
                            icon: Icon(
                              MdiIcons.autoFix,
                              color: _aiMode ? agentColor : AppTheme.fhTextSecondary,
                            ),
                            onPressed: _aiLoading
                                ? null
                                : () => setState(() => _aiMode = !_aiMode),
                          ),
                          _aiLoading
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(agentColor),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(Icons.add, color: agentColor),
                                  onPressed: () => _handleAdd(provider, liveCheckpoint),
                                ),
                        ],
                      ),
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

  void _showPasteAlertDialog(BuildContext context, String title, Function(String) onImport) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        title: Text(title, style: GoogleFonts.rajdhani(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              Text("Paste the copied structure text here to import:", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: GoogleFonts.jetBrainsMono(color: AppTheme.fhTextPrimary, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.fhBgDeepDark,
                border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:   Text("CANCEL", style: TextStyle(color: AppTheme.fhTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fhAccentTeal,
              foregroundColor: JweTheme.onAccent,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                onImport(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  void _handlePaste(BuildContext context, AppProvider provider, SubSubTask liveCheckpoint) {
    _showPasteAlertDialog(context, "PASTE NESTED OBJECTIVE", (pastedText) {
      final parsed = parseTaskOutline(pastedText);
      if (parsed.isNotEmpty) {
        final newSubstep = SubSubTask(
          id: const Uuid().v4(),
          name: parsed['name'] as String? ?? 'Unnamed Objective',
          why: parsed['why'] as String? ?? '',
          what: parsed['what'] as String? ?? '',
          type: 'check',
          substeps: (parsed['children'] as List<dynamic>).map((c) {
            return SubSubTask(
              id: const Uuid().v4(),
              name: c['name'] as String? ?? 'Unnamed Objective',
              why: c['why'] as String? ?? '',
              what: c['what'] as String? ?? '',
              type: 'check',
            );
          }).toList(),
        );

        provider.taskActions.updateSubSubtask(
          widget.mainTaskId,
          widget.parentSubTaskId,
          liveCheckpoint.id,
          {
            'substeps': [...liveCheckpoint.substeps, newSubstep],
          },
        );
        showGlobalToast("Nested objective pasted as new child");
      }
    });
  }
}