import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/ui/project_step_card.dart';
import 'package:arcane/src/widgets/dialogs/project_generation_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final selectedTask = provider.getSelectedTask();

    if (selectedTask == null) {
      return const Center(child: Text("Select a Mission to view Projects."));
    }

    final projects = selectedTask.projects;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ACTIVE PROJECTS", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: Icon(MdiIcons.plus, size: 18),
                label: const Text("New Project"),
                onPressed: () => _showAddProjectDialog(context, provider, selectedTask.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentTealFixed,
                  foregroundColor: AppTheme.fhBgDeepDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AI Gen Button
          ElevatedButton.icon(
            icon: Icon(MdiIcons.creationOutline, size: 18),
            label: const Text("Create Project from AI Prompt"),
            onPressed: () => showDialog(
              context: context, 
              builder: (context) => ProjectGenerationDialog(mainTaskId: selectedTask.id)
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fhAccentPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: projects.isEmpty
              ? Center(
                  child: Text(
                    "No projects active for this mission.",
                    style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(context, provider, selectedTask.id, project);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, AppProvider provider, String mainTaskId, Project project) {
    return Card(
      color: AppTheme.fhBgDark,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if(project.description.isNotEmpty)
              Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.progress,
                backgroundColor: AppTheme.fhBgMedium,
                color: AppTheme.fhAccentTeal,
                minHeight: 6,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
          onPressed: () => _confirmDeleteProject(context, provider, mainTaskId, project.id),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Button to add root step
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(MdiIcons.plus, size: 16),
                    label: const Text("Add Root Step"),
                    onPressed: () => _showAddStepDialog(context, provider, mainTaskId, project.id, null),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: project.steps.length,
                  itemBuilder: (context, index) {
                    return ProjectStepCard(
                      step: project.steps[index],
                      mainTaskId: mainTaskId,
                      projectId: project.id,
                      depth: 0,
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context, AppProvider provider, String mainTaskId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text("New Project"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Project Title")),
            const SizedBox(height: 8),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                provider.projectActions.addProject(mainTaskId, titleController.text, descController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          )
        ],
      );
    });
  }

  void _showAddStepDialog(BuildContext context, AppProvider provider, String mainTaskId, String projectId, String? parentStepId) {
    final titleController = TextEditingController();
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text("Add Step"),
        content: TextField(controller: titleController, decoration: const InputDecoration(labelText: "Step Title")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                if(parentStepId == null) {
                  provider.projectActions.addRootStep(mainTaskId, projectId, titleController.text);
                } else {
                  // Not reachable from here directly for root add, but generic handler
                }
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      );
    });
  }

  void _confirmDeleteProject(BuildContext context, AppProvider provider, String mainTaskId, String projectId) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Delete Project?"),
      content: const Text("This cannot be undone."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
          onPressed: () {
            provider.projectActions.deleteProject(mainTaskId, projectId);
            Navigator.pop(context);
          },
          child: const Text("Delete"),
        )
      ],
    ));
  }
}