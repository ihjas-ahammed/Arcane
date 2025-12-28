import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/widgets/cards/project_dashboard_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/screens/project_detail_screen.dart';

class CompletedProjectsSection extends StatelessWidget {
  final List<Map<String, dynamic>> completedProjects;

  const CompletedProjectsSection({super.key, required this.completedProjects});

  @override
  Widget build(BuildContext context) {
    if (completedProjects.isEmpty) return const SizedBox.shrink();

    // Group by Month (using a naive approach since Project doesn't have a 'completedDate' explicitly, 
    // but in a real app you'd want a 'completedDate' field. 
    // For now, we'll group them all under "Recently Completed" or simulate month based on an assumed date 
    // OR just list them if we don't have dates.
    // Assuming for this requirement we group simply or treat all as current month if no date.)
    
    // To strictly follow "Filtered by Month", we'd need a date field. 
    // Since 'Project' model lacks 'completedDate', we will render them in a single expandable list for now
    // or group by an arbitrary key if we had one. 
    // Let's wrap the whole list in an ExpansionTile titled "Completed Archives".

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Row(
              children: [
                Icon(MdiIcons.archiveCheckOutline, color: AppTheme.fhAccentGreen, size: 20),
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
              // We can show a dropdown-like filter here if we had dates,
              // for now we just show the list.
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completedProjects.length,
                itemBuilder: (context, index) {
                  final item = completedProjects[index];
                  return GestureDetector(
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
                    child: ProjectDashboardCard(
                      project: item['project'] as Project,
                      mainTaskId: item['mainTaskId'] as String,
                      mainTaskName: item['mainTaskName'] as String,
                      accentColor: AppTheme.fhTextDisabled, // Gray out completed
                    ),
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