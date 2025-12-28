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
import 'package:arcane/src/screens/project_detail_screen.dart';
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
          Text("PROJECT PROTOCOLS",
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.5)),
          const Text("ACTIVE OPERATIONS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 2.0, fontWeight: FontWeight.bold)),

          const SizedBox(height: 24),

          // Overall Progress for Ongoing Projects
          OverallProjectProgressCard(activeProjects: rawActiveProjects),

          const SizedBox(height: 32),

          // Ongoing Projects Header
          Row(
            children: [
              Container(width: 4, height: 16, color: AppTheme.fhAccentOrange),
              const SizedBox(width: 8),
              Text("ONGOING OPS",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 16),

          // Project List
          if (ongoingProjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppTheme.fhBgDark.withValues(alpha: 0.5),
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
                  const Text("NO ACTIVE PROJECTS",
                      style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showCreateProjectSheet(context),
                    child: const Text("INITIALIZE NEW PROJECT", style: TextStyle(color: AppTheme.fhAccentTeal)),
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
          Row(
            children: [
              Container(width: 4, height: 16, color: AppTheme.fhAccentTeal),
              const SizedBox(width: 8),
              Text("QUICK ACTIONS",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Create Button (Valorant Style)
          GestureDetector(
            onTap: () => _showCreateProjectSheet(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: AppTheme.fhAccentRed,
                  borderRadius: BorderRadius.circular(0), // Sharp edges
                  border: Border.all(color: AppTheme.fhAccentRed.withValues(alpha: 0.5))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(MdiIcons.plus, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text("CREATE NEW PROJECT",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontDisplay,
                          letterSpacing: 1.5,
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
                  label: "AI PROMPTS",
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
                  label: "LINK TASK",
                  onTap: () => _showLinkSubmissionSheet(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 80), 
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