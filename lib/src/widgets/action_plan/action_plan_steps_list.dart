import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
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
  String _newStepType = 'check'; 

  void _addStep(AppProvider provider) {
    if (_stepController.text.trim().isEmpty) return;
    provider.taskActions.addSubSubtask(widget.mainTaskId, widget.subTaskId, {
      'name': _stepController.text.trim(),
      'isCountable': false,
      'targetCount': 0,
      'type': _newStepType,
    });
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
              const Text("TACTICAL EXECUTION (HOW)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
              if (widget.steps.isEmpty)
                TextButton.icon(
                  onPressed: isLoading ? null : () async {
                    final prompt = await showDialog<String>(
                      context: context,
                      builder: (_) => const AiGenerationPromptDialog(
                        title: "GENERATE STRATEGY",
                        hintText: "Add specific instructions, e.g. Focus on low budget...",
                        actionLabel: "GENERATE",
                      ),
                    );
                    if (prompt != null && prompt.isNotEmpty) {
                      widget.onGenerate(prompt);
                    }
                  },
                  icon: isLoading 
                    ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: widget.accentColor)) 
                    : Icon(MdiIcons.robotExcitedOutline, size: 14, color: widget.accentColor),
                  label: Text(isLoading ? "THINKING..." : "GENERATE STEPS", style: TextStyle(fontSize: 10, color: widget.accentColor)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap
                  ),
                ),
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
            child: const Text("No steps defined yet.", style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.steps.length,
            itemBuilder: (ctx, index) {
              final step = widget.steps[index];
              return DraggableCheckpointWrapper(
                checkpointId: step.id,
                onMove: (draggedId, targetId, pos) {
                  provider.taskActions.moveCheckpointRelative(widget.mainTaskId, widget.subTaskId, draggedId, targetId, pos);
                },
                child: CheckpointItem(
                  key: ValueKey(step.id),
                  title: step.name,
                  isCompleted: step.completed,
                  type: step.type,
                  hasCheckableSubsteps: step.hasCheckableSubsteps,
                  progress: step.calculateProgress(), 
                  accentColor: widget.accentColor,
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
                ),
              );
            },
          ),

        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children:[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.fhBorderColor)),
                child: PopupMenuButton<String>(
                  icon: Icon(_newStepType == 'info' ? MdiIcons.informationOutline : MdiIcons.checkboxMarkedOutline, color: AppTheme.fhTextSecondary, size: 16),
                  tooltip: "Change Type",
                  onSelected: (val) => setState(() => _newStepType = val),
                  color: AppTheme.fhBgDark,
                  itemBuilder: (context) =>[
                    const PopupMenuItem(value: 'check', child: Text("Checkable Step", style: TextStyle(color: AppTheme.fhTextPrimary))),
                    const PopupMenuItem(value: 'info', child: Text("Info Note", style: TextStyle(color: AppTheme.fhTextPrimary))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stepController,
                  style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "ADD STEP...",
                    hintStyle: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12, letterSpacing: 1.0),
                    border: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.accentColor)),
                    filled: true,
                    fillColor: AppTheme.fhBgDark.withOpacity(0.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onSubmitted: (_) => _addStep(provider),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _addStep(provider),
                child: Container(
                  width: 40, height: 40,
                  color: widget.accentColor.withOpacity(0.2),
                  alignment: Alignment.center,
                  child: Text("+", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}