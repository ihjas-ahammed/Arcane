import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectStepListTile extends StatefulWidget {
  final ProjectStep step;
  final String mainTaskId;
  final String projectId;
  final String indexPrefix;

  const ProjectStepListTile({
    super.key,
    required this.step,
    required this.mainTaskId,
    required this.projectId,
    required this.indexPrefix,
  });

  @override
  State<ProjectStepListTile> createState() => _ProjectStepListTileState();
}

class _ProjectStepListTileState extends State<ProjectStepListTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final double progress = widget.step.calculateProgress();
    final int percentage = (progress * 100).toInt();

    // Determine color based on progress (Design: Green for 100%, Blue for in-progress)
    Color statusColor = AppTheme.fhAccentTeal; // Default/In-progress
    if (percentage == 100) statusColor = const Color(0xFF00C853); // Green
    if (percentage == 0) statusColor = AppTheme.fhTextDisabled;

    return Column(
      children: [
        // Main Card
        InkWell(
          onTap: () {
            // Expand if it has substeps, or toggle if it's a leaf node
            if (widget.step.substeps.isNotEmpty) {
              setState(() => _isExpanded = !_isExpanded);
            } else {
               // If no substeps, tapping the card could act as toggle or edit
               // For this design, let's just expand context menu or do nothing
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark, // White/Light grey in design, Dark here for theme
              borderRadius: BorderRadius.circular(16),
              // Subtle border
              border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Index
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${widget.indexPrefix}. ${widget.step.title}",
                            style: const TextStyle(
                              color: AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Percentage Text
                    Text(
                      "$percentage%",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.fhBgDeepDark,
                    color: statusColor,
                  ),
                ),
                
                // Expand Icon (Only if substeps exist)
                if (widget.step.substeps.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Icon(
                        _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                        size: 20,
                        color: AppTheme.fhTextSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expanded Substeps (The Checklist View)
        if (_isExpanded && widget.step.substeps.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.fhBgMedium.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ...widget.step.substeps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final substep = entry.value;
                  return _buildChecklistItem(context, provider, substep, index);
                }),
                // Add Substep Button inside expanded view
                TextButton.icon(
                  onPressed: () => _showAddSubstepDialog(context, provider),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text("Add Item", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.fhTextSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    minimumSize: const Size(0, 32),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistItem(BuildContext context, AppProvider provider, ProjectStep substep, int index) {
    // Determine if this is a leaf node or has deeper levels
    // For this UI component, we are treating level 2 as checklist items.
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          RhombusCheckbox(
            checked: substep.isCompleted, 
            size: CheckboxSize.small,
            onChanged: (val) {
               // Recursive update handled by provider usually, but here we toggle leaf
               final updated = substep..isCompleted = !substep.isCompleted;
               provider.projectActions.updateStep(widget.mainTaskId, widget.projectId, updated);
            }
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              substep.title,
              style: TextStyle(
                color: substep.isCompleted ? AppTheme.fhTextSecondary : AppTheme.fhTextPrimary,
                decoration: substep.isCompleted ? TextDecoration.lineThrough : null,
                fontSize: 13,
              ),
            ),
          ),
          // Delete action for item
          InkWell(
            onTap: () => provider.projectActions.deleteStep(widget.mainTaskId, widget.projectId, substep.id),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(MdiIcons.close, size: 14, color: AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
            ),
          )
        ],
      ),
    );
  }

  void _showAddSubstepDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("Add Item", style: TextStyle(color: AppTheme.fhTextPrimary)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: AppTheme.fhTextPrimary),
          decoration: const InputDecoration(labelText: "Description")
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.projectActions.addSubstep(widget.mainTaskId, widget.projectId, widget.step.id, controller.text);
                Navigator.pop(context);
                setState(() {}); // refresh
              }
            },
            child: const Text("Add"),
          )
        ],
      );
    });
  }
}