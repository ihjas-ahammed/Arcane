import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectStepCard extends StatefulWidget {
  final ProjectStep step;
  final String mainTaskId;
  final String projectId;
  final int depth;

  const ProjectStepCard({
    super.key,
    required this.step,
    required this.mainTaskId,
    required this.projectId,
    this.depth = 0,
  });

  @override
  State<ProjectStepCard> createState() => _ProjectStepCardState();
}

class _ProjectStepCardState extends State<ProjectStepCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final progress = widget.step.calculateProgress();

    return Container(
      margin: EdgeInsets.only(left: widget.depth * 16.0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.step.isCompleted ? AppTheme.fhAccentGreen.withOpacity(0.5) : AppTheme.fhBorderColor.withOpacity(0.3)
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: IconButton(
              icon: Icon(
                widget.step.isCompleted ? MdiIcons.checkboxMarkedCircleOutline : MdiIcons.checkboxBlankCircleOutline,
                color: widget.step.isCompleted ? AppTheme.fhAccentGreen : AppTheme.fhTextSecondary,
              ),
              onPressed: () {
                // Toggle completion manually
                final updatedStep = widget.step..isCompleted = !widget.step.isCompleted;
                provider.projectActions.updateStep(widget.mainTaskId, widget.projectId, updatedStep);
              },
            ),
            title: Text(
              widget.step.title,
              style: TextStyle(
                decoration: widget.step.isCompleted ? TextDecoration.lineThrough : null,
                color: widget.step.isCompleted ? AppTheme.fhTextSecondary : AppTheme.fhTextPrimary,
              ),
            ),
            subtitle: progress > 0 && progress < 1.0 
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: LinearProgressIndicator(value: progress, minHeight: 4, color: AppTheme.fhAccentTeal, backgroundColor: AppTheme.fhBgDeepDark),
                )
              : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 IconButton(
                  icon: Icon(MdiIcons.targetVariant, size: 18, color: AppTheme.fhAccentPurple),
                  tooltip: "Promote to Mission Submission",
                  onPressed: () {
                     provider.projectActions.promoteStepToSubmission(widget.mainTaskId, widget.step);
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added as Submission to Mission")));
                  },
                ),
                IconButton(
                  icon: Icon(MdiIcons.plus, size: 18),
                  tooltip: "Add Substep",
                  onPressed: () => _showAddSubstepDialog(context, provider),
                ),
                IconButton(
                  icon: Icon(MdiIcons.deleteOutline, size: 18, color: AppTheme.fhAccentRed),
                  onPressed: () => provider.projectActions.deleteStep(widget.mainTaskId, widget.projectId, widget.step.id),
                ),
                if (widget.step.substeps.isNotEmpty)
                  IconButton(
                    icon: Icon(_isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
              ],
            ),
          ),
          if (_isExpanded && widget.step.substeps.isNotEmpty)
            Column(
              children: widget.step.substeps.map((substep) {
                return ProjectStepCard(
                  step: substep,
                  mainTaskId: widget.mainTaskId,
                  projectId: widget.projectId,
                  depth: 1, // Indent relative to parent container, logical depth handled by widget recursive placement
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showAddSubstepDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text("Add Substep"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Substep Title")),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.projectActions.addSubstep(widget.mainTaskId, widget.projectId, widget.step.id, controller.text);
                Navigator.pop(context);
                setState(() => _isExpanded = true);
              }
            },
            child: const Text("Add"),
          )
        ],
      );
    });
  }
}