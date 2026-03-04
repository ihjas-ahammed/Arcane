import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/items/checkpoint_item.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

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

  SubSubTask? _getLiveCheckpoint(AppProvider provider) {
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      final sub = parent.subTasks.firstWhere((s) => s.id == widget.parentSubTaskId);
      
      // Recursive finder
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

  void _addSubstep(AppProvider provider, SubSubTask parentCp) {
    if (_stepController.text.trim().isEmpty) return;
    
    provider.taskActions.addSubSubtask(
      widget.mainTaskId, 
      widget.parentSubTaskId, 
      {
        'name': _stepController.text.trim(),
        'type': _newStepType,
        'isCountable': false,
      },
      parentCheckpointId: parentCp.id
    );
    _stepController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final liveCheckpoint = _getLiveCheckpoint(provider);

    if (liveCheckpoint == null) {
      return const Scaffold(backgroundColor: AppTheme.fhBgDeepDark, body: Center(child: Text("Checkpoint not found")));
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("OBJECTIVE DETAIL", style: TextStyle(fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
            onPressed: () {
              provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id);
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "Objective Name"),
              onSubmitted: (_) => _saveTitle(provider, liveCheckpoint),
              onEditingComplete: () => _saveTitle(provider, liveCheckpoint),
            ),
            const SizedBox(height: 24),

            // Why/What
            ActionPlanWhyCard(
              initialWhy: liveCheckpoint.why,
              onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'why': val}),
            ),
            const SizedBox(height: 16),
            ActionPlanOutcomeCard(
              initialWhat: liveCheckpoint.what,
              onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'what': val}),
            ),

            const SizedBox(height: 32),

            // Nested Steps
            const Text("SUB-ROUTINES (NESTED)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            if (liveCheckpoint.substeps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text("No nested instructions.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic)),
              )
            else
              ...liveCheckpoint.substeps.map((child) {
                return CheckpointItem(
                  title: child.name,
                  isCompleted: child.completed,
                  type: child.type,
                  hasSubsteps: child.substeps.isNotEmpty,
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
                );
              }),

            // Add Substep
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(_newStepType == 'info' ? MdiIcons.informationOutline : MdiIcons.checkboxMarkedOutline, color: AppTheme.fhTextSecondary, size: 20),
                    onSelected: (val) => setState(() => _newStepType = val),
                    color: AppTheme.fhBgDark,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'check', child: Text("Checkable", style: TextStyle(color: AppTheme.fhTextPrimary))),
                      const PopupMenuItem(value: 'info', child: Text("Info", style: TextStyle(color: AppTheme.fhTextPrimary))),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _stepController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "ADD NESTED STEP...",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addSubstep(provider, liveCheckpoint),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppTheme.fhAccentTeal),
                    onPressed: () => _addSubstep(provider, liveCheckpoint),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}