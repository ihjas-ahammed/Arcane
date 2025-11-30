import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/cards/project_progress_header_card.dart';
import 'package:arcane/src/widgets/ui/project_step_list_tile.dart';
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
    // We find the project again in the provider to ensure state updates (like checkbox toggles) reflect immediately
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
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 20),
            onPressed: () {
              // Edit Project Logic here if needed
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.dotsVertical, size: 20),
            onPressed: () {
              // Menu Logic
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
            const SizedBox(height: 4),
            Text(
              currentProject.description.isNotEmpty 
                ? currentProject.description 
                : "Project Workflow",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.fhTextSecondary,
              ),
            ),
            
            const SizedBox(height: 24),

            // Big Progress Header Card
            ProjectProgressHeaderCard(project: currentProject),

            const SizedBox(height: 24),

            // Steps List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Workflow Steps",
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
                  child: Text(
                    "No steps defined.\nAdd a step to begin tracking.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.fhTextSecondary),
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

  void _showAddRootStepDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("Add Root Step", style: TextStyle(color: AppTheme.fhTextPrimary)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: AppTheme.fhTextPrimary),
          decoration: const InputDecoration(
            labelText: "Step Title",
            labelStyle: TextStyle(color: AppTheme.fhTextSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fhTextSecondary)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
          )
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: AppTheme.fhTextSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.projectActions.addRootStep(mainTaskId, project.id, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Add", style: TextStyle(color: AppTheme.fhBgDeepDark, fontWeight: FontWeight.bold)),
          )
        ],
      );
    });
  }
}