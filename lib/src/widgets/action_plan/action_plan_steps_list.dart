import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/items/checkpoint_item.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ActionPlanStepsList extends StatefulWidget {
  final String mainTaskId;
  final String subTaskId;
  final List<SubSubTask> steps;
  final VoidCallback onGenerate;

  const ActionPlanStepsList({
    super.key,
    required this.mainTaskId,
    required this.subTaskId,
    required this.steps,
    required this.onGenerate,
  });

  @override
  State<ActionPlanStepsList> createState() => _ActionPlanStepsListState();
}

class _ActionPlanStepsListState extends State<ActionPlanStepsList> {
  final TextEditingController _stepController = TextEditingController();
  String _newStepType = 'check'; // 'check' or 'info'

  void _addStep(AppProvider provider) {
    if (_stepController.text.trim().isEmpty) return;
    provider.addSubSubtask(widget.mainTaskId, widget.subTaskId, {
      'name': _stepController.text.trim(),
      'isCountable': false,
      'targetCount': 0,
      'type': _newStepType,
    });
    _stepController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isLoading = provider.loadingTaskName == "Generating Strategy...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("TACTICAL EXECUTION (HOW)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            if (widget.steps.isEmpty)
              TextButton.icon(
                onPressed: isLoading ? null : widget.onGenerate,
                icon: isLoading 
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Icon(MdiIcons.robotExcitedOutline, size: 14),
                label: Text(isLoading ? "THINKING..." : "GENERATE STEPS", style: const TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.fhAccentPurple,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (widget.steps.isEmpty && !isLoading)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
              color: AppTheme.fhBgDark.withOpacity(0.3)
            ),
            child: const Text("No steps defined yet.", style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
          )
        else
          ...widget.steps.map((step) {
            return CheckpointItem(
              title: step.name,
              isCompleted: step.completed,
              type: step.type,
              onToggle: () {
                if (step.completed) {
                  provider.taskActions.uncompleteSubSubtask(widget.mainTaskId, widget.subTaskId, step.id);
                } else {
                  provider.taskActions.completeSubSubtask(widget.mainTaskId, widget.subTaskId, step.id);
                }
              },
              onDelete: () => provider.deleteSubSubtask(widget.mainTaskId, widget.subTaskId, step.id),
              onDuplicate: () => provider.taskActions.duplicateSubSubtask(widget.mainTaskId, widget.subTaskId, step.id),
              onToggleType: () {
                final newType = step.type == 'check' ? 'info' : 'check';
                provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.subTaskId, step.id, {'type': newType});
              },
            );
          }),

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
                tooltip: "Change Type",
                onSelected: (val) => setState(() => _newStepType = val),
                color: AppTheme.fhBgDark,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'check', child: Text("Checkable Step", style: TextStyle(color: AppTheme.fhTextPrimary))),
                  const PopupMenuItem(value: 'info', child: Text("Info Note", style: TextStyle(color: AppTheme.fhTextPrimary))),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _stepController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "ADD STEP...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1.0),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _addStep(provider),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppTheme.fhAccentTeal),
                onPressed: () => _addStep(provider),
              )
            ],
          ),
        ),
      ],
    );
  }
}