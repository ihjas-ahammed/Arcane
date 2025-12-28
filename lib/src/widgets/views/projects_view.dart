import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/cards/project_dashboard_card.dart';
import 'package:arcane/src/widgets/cards/quick_action_card.dart';
import 'package:arcane/src/widgets/cards/overall_project_progress_card.dart';
import 'package:arcane/src/widgets/ui/completed_projects_section.dart';
import 'package:arcane/src/widgets/sheets/create_project_sheet.dart';
import 'package:arcane/src/widgets/sheets/link_submission_sheet.dart';
import 'package:arcane/src/widgets/views/ai_prompts_view.dart';
import 'package:arcane/src/screens/project_detail_screen.dart'; // Import detail screen
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    // Aggregate all projects
    final List<Map<String, dynamic>> ongoingProjects = [];
    final List<Map<String, dynamic>> completedProjects = [];
    final List<Project> rawActiveProjects = [];

    for (var task in provider.mainTasks) {
      for (var project in task.projects) {
        final double progress = project.calculateProgress();
        final bool isComplete = progress >= 1.0;

        final map = {
          'project': project,
          'mainTaskId': task.id,
          'mainTaskName': task.name,
          'color': task.taskColor,
        };

        if (isComplete) {
          completedProjects.add(map);
        } else {
          ongoingProjects.add(map);
          rawActiveProjects.add(project);
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text("Welcome Back!",
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),

          const SizedBox(height: 24),

          // Overall Progress for Ongoing Projects
          OverallProjectProgressCard(activeProjects: rawActiveProjects),

          const SizedBox(height: 32),

          // Ongoing Projects Header
          Row(
            children: [
              Icon(MdiIcons.fire, color: AppTheme.fhAccentOrange, size: 20),
              const SizedBox(width: 8),
              Text("Ongoing Projects",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // Project List
          if (ongoingProjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
                  )),
              child: Column(
                children: [
                  Icon(
                    MdiIcons.folderOutline,
                    size: 48,
                    color: AppTheme.fhTextSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text("No active projects.",
                      style: TextStyle(color: AppTheme.fhTextSecondary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showCreateProjectSheet(context),
                    child: const Text("Create your first project"),
                  )
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ongoingProjects.length,
              itemBuilder: (context, index) {
                final item = ongoingProjects[index];
                return GestureDetector(
                  onTap: () {
                    // Push to Detail Screen
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProjectDetailScreen(
                                project: item['project'] as Project,
                                mainTaskId: item['mainTaskId'] as String)));
                  },
                  child: ProjectDashboardCard(
                    project: item['project'] as Project,
                    mainTaskId: item['mainTaskId'] as String,
                    mainTaskName: item['mainTaskName'] as String,
                    accentColor: item['color'] as Color,
                  ),
                );
              },
            ),

          // Completed Projects Section
          if (completedProjects.isNotEmpty)
            CompletedProjectsSection(completedProjects: completedProjects),

          const SizedBox(height: 32),

          // Quick Actions
          Text("Quick Actions",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Primary Create Button
          GestureDetector(
            onTap: () => _showCreateProjectSheet(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4A90E2),
                      Color(0xFF9013FE)
                    ], // Blue to Purple gradient
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF9013FE).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(MdiIcons.plus, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text("Create New Project",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary Actions Grid
          Row(
            children: [
              Expanded(
                child: QuickActionCard(
                  icon: MdiIcons.robotOutline,
                  label: "AI Prompts",
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AiPromptsView())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickActionCard(
                  icon: MdiIcons.targetVariant,
                  label: "Link Task",
                  onTap: () => _showLinkSubmissionSheet(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 80), // Bottom padding for scroll
        ],
      ),
    );
  }

  void _showCreateProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateProjectSheet(),
    );
  }

  void _showLinkSubmissionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LinkSubmissionSheet(),
    );
  }
}
