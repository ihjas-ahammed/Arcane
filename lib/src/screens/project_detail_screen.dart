import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/cards/project_progress_header_card.dart';
import 'package:arcane/src/widgets/ui/project_step_list_tile.dart';
import 'package:arcane/src/widgets/dialogs/project_dialogs.dart'; // Import unified dialogs
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectDetailScreen extends StatelessWidget {
  final Project project;
  final String mainTaskId;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.mainTaskId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);

    // Ensure we are working with the latest data from provider
    Project currentProject = project;
    try {
      final task = provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      currentProject = task.projects.firstWhere((p) => p.id == project.id);
    } catch (e) {
      // Fallback if project was deleted while viewing
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // EDIT PROJECT BUTTON
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 20),
            tooltip: "Edit Project Details",
            onPressed: () async {
              final result = await showDialog<Map<String, String>>(
                context: context,
                builder: (ctx) => AddEditProjectDialog(
                  mainTaskId: mainTaskId,
                  projectId: currentProject.id,
                  initialTitle: currentProject.title,
                  initialDescription: currentProject.description,
                ),
              );
              
              if (result != null) {
                provider.projectActions.updateProjectDetails(
                  mainTaskId, 
                  currentProject.id, 
                  result['title']!, 
                  result['desc']!
                );
              }
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.deleteOutline, size: 20, color: AppTheme.fhAccentRed),
            onPressed: () {
              _confirmDelete(context, provider, currentProject);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Text(
              currentProject.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentProject.description.isNotEmpty 
                ? currentProject.description 
                : "No description provided.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.fhTextSecondary,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 24),

            // Big Progress Header Card
            ProjectProgressHeaderCard(project: currentProject),

            const SizedBox(height: 24),

            // Steps List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Root Steps",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.fhTextPrimary
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddRootStepDialog(context, provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add Step"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.fhAccentTeal,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            if (currentProject.steps.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(MdiIcons.stairsBox, size: 48, color: AppTheme.fhTextSecondary.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        "No steps defined.\nAdd a root step to begin.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.fhTextSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentProject.steps.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final step = currentProject.steps[index];
                  // Use the updated Tile which now navigates to StepDetailScreen
                  return ProjectStepListTile(
                    step: step,
                    mainTaskId: mainTaskId,
                    projectId: currentProject.id,
                    indexPrefix: "${index + 1}",
                  );
                },
              ),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showAddRootStepDialog(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddEditStepDialog(),
    );

    if (result != null) {
      provider.projectActions.addRootStep(
        mainTaskId, 
        project.id, 
        result['title']!, 
        result['desc']!
      );
    }
  }

  void _confirmDelete(BuildContext context, AppProvider provider, Project project) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Delete Project?", style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: const Text("This action cannot be undone."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
          onPressed: () {
            provider.projectActions.deleteProject(mainTaskId, project.id);
            Navigator.pop(ctx);
            Navigator.pop(context); // Go back to projects view
          }, 
          child: const Text("Delete")
        )
      ],
    ));
  }
}