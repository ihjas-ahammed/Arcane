import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/project_step_list_tile.dart';
import 'package:arcane/src/widgets/dialogs/project_dialogs.dart';
import 'package:arcane/src/widgets/dialogs/link_submission_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class StepDetailScreen extends StatelessWidget {
  final ProjectStep step;
  final String mainTaskId;
  final String projectId;
  final String stepNumber;

  const StepDetailScreen({
    super.key,
    required this.step,
    required this.mainTaskId,
    required this.projectId,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);

    // Re-fetch the step from provider to ensure reactivity
    ProjectStep currentStep = step;
    try {
      final task = provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      final project = task.projects.firstWhere((p) => p.id == projectId);

      // Recursive finder
      ProjectStep? findStep(List<ProjectStep> list) {
        for (var s in list) {
          if (s.id == step.id) return s;
          var found = findStep(s.substeps);
          if (found != null) return found;
        }
        return null;
      }

      var found = findStep(project.steps);
      if (found != null) currentStep = found;
    } catch (e) {
      // Fallback
    }

    final double progress = currentStep.calculateProgress();
    final int percentage = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Step $stepNumber", style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: "Link to Submission",
            icon: Icon(MdiIcons.linkVariant, size: 20),
            onPressed: () async {
              // 1. Find the MainTask
              try {
                final task =
                    provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
                
                // Filter for incomplete subtasks
                final incompleteSubtasks = task.subTasks.where((s) => !s.completed).toList();

                // 2. Show Dialog
                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (ctx) => LinkSubmissionDialog(
                    initialName: currentStep.title,
                    availableSubmissions: incompleteSubtasks,
                  ),
                );

                if (!context.mounted) return;
                if (result != null) {
                  final String name = result['name'];
                  final String type = result['type'];

                  if (type == 'submission') {
                    provider.addSubtask(mainTaskId, {
                      'name': name,
                      'completed': currentStep.isCompleted,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Linked to new Sub-Mission: $name")));
                  } else if (type == 'checkpoint') {
                    final String parentId = result['parentId'];
                    provider.addSubSubtask(mainTaskId, parentId, {
                      'name': name,
                      'completed': currentStep.isCompleted,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Linked to new Checkpoint: $name")));
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text("Error linking: $e")));
              }
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 20),
            onPressed: () async {
              final result = await showDialog<Map<String, String>>(
                context: context,
                builder: (ctx) => AddEditStepDialog(
                  initialTitle: currentStep.title,
                  initialDescription: currentStep.description,
                  isEditing: true,
                ),
              );
              if (!context.mounted) return;
              if (result != null) {
                final updated = currentStep
                  ..title = result['title']!
                  ..description = result['desc']!;
                provider.projectActions
                    .updateStep(mainTaskId, projectId, updated);
              }
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.deleteOutline,
                size: 20, color: AppTheme.fhAccentRed),
            onPressed: () {
              // Confirm Delete
              showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.fhBgMedium,
                        title: const Text("Delete Step?",
                            style: TextStyle(color: AppTheme.fhTextPrimary)),
                        content: const Text(
                            "This will delete this step and all its sub-steps."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel")),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentRed),
                              onPressed: () {
                                provider.projectActions.deleteStep(
                                    mainTaskId, projectId, currentStep.id);
                                Navigator.pop(ctx); // Close dialog
                                Navigator.pop(context); // Close screen
                              },
                              child: const Text("Delete"))
                        ],
                      ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Text(
              currentStep.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
              ),
            ),
            if (currentStep.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                currentStep.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.fhTextSecondary,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Progress Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Step Progress",
                          style: TextStyle(color: AppTheme.fhTextSecondary)),
                      Text("$percentage%",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.fhAccentTeal,
                              fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: AppTheme.fhBgDeepDark,
                      color: AppTheme.fhAccentTeal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Substeps List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Sub-steps",
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.fhTextPrimary),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final result = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (ctx) => const AddEditStepDialog(),
                    );
                    if (!context.mounted) return;
                    if (result != null) {
                      provider.projectActions.addSubstep(mainTaskId, projectId,
                          currentStep.id, result['title']!, result['desc']!);
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add"),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.fhAccentTeal),
                )
              ],
            ),
            const SizedBox(height: 12),

            if (currentStep.substeps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppTheme.fhBgMedium.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(style: BorderStyle.none)),
                child: Column(
                  children: [
                    Icon(MdiIcons.fileTreeOutline,
                        size: 32,
                        color: AppTheme.fhTextSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    const Text("No sub-steps yet.",
                        style: TextStyle(color: AppTheme.fhTextSecondary)),
                    const SizedBox(height: 4),
                    const Text(
                        "Break this step down further or mark it as complete.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.fhTextDisabled, fontSize: 12)),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentStep.substeps.length,
                onReorder: (oldIndex, newIndex) {
                  provider.projectActions.reorderSubSteps(mainTaskId, projectId,
                      currentStep.id, oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.5),
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final substep = currentStep.substeps[index];
                  // Recursive numbering: e.g., 1.2.1
                  final displayPrefix = "$stepNumber.${index + 1}";

                  return KeyedSubtree(
                    key: ValueKey(substep.id),
                    child: ProjectStepListTile(
                      step: substep,
                      mainTaskId: mainTaskId,
                      projectId: projectId,
                      indexPrefix: displayPrefix,
                    ),
                  );
                },
              ),

            // Manual Completion Toggle (Only if leaf node)
            if (currentStep.substeps.isEmpty) ...[
              const SizedBox(height: 30),
              Divider(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Mark as Complete",
                    style: TextStyle(color: AppTheme.fhTextPrimary)),
                subtitle: const Text(
                    "This step has no sub-steps, so you can toggle it directly.",
                    style: TextStyle(fontSize: 12)),
                value: currentStep.isCompleted,
                activeThumbColor: AppTheme.fhAccentGreen,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final updated = currentStep..isCompleted = val;
                  provider.projectActions
                      .updateStep(mainTaskId, projectId, updated);
                },
              )
            ]
          ],
        ),
      ),
    );
  }
}
