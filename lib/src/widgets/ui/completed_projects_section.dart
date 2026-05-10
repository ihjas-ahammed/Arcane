import 'package:flutter/material.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/theme/app_theme.dart';

import 'package:missions/src/widgets/cards/project_dashboard_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/project_detail_screen.dart';

class CompletedProjectsSection extends StatelessWidget {
  final List<Map<String, dynamic>> completedProjects;

  const CompletedProjectsSection({super.key, required this.completedProjects});

  @override
  Widget build(BuildContext context) {
    if (completedProjects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Row(
              children: [
                Icon(MdiIcons.archiveCheckOutline,
                    color: AppTheme.fhAccentGreen, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Completed Archives",
                  style: TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            childrenPadding: EdgeInsets.zero,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completedProjects.length,
                itemBuilder: (context, index) {
                  final item = completedProjects[index];
                  // Passed onTap directly to ProjectDashboardCard instead of wrapping with GestureDetector
                  return ProjectDashboardCard(
                    project: item['project'] as Project,
                    mainTaskId: item['mainTaskId'] as String,
                    mainTaskName: item['mainTaskName'] as String,
                    accentColor:
                        AppTheme.fhTextDisabled, // Gray out completed
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailScreen(
                            project: item['project'] as Project,
                            mainTaskId: item['mainTaskId'] as String,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
