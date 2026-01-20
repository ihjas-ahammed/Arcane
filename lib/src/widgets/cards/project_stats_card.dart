import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProjectStatsCard extends StatelessWidget {
  final Project project;
  final List<MainTask> allTasks;

  const ProjectStatsCard({
    super.key,
    required this.project,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    final int totalSeconds = project.calculateTotalTimeSeconds(allTasks);
    final String formattedTime = helper.formatTime(totalSeconds.toDouble());
    final String createdDate = DateFormat('MMM d, yyyy').format(project.createdAt);
    final String completedDate = project.completedAt != null 
        ? DateFormat('MMM d, yyyy').format(project.completedAt!) 
        : 'Ongoing';

    // Simple weekly data mockup for the graph
    // In a real scenario, we'd iterate logs for linked tasks to get precise history per day.
    // For now, we show total time and meta stats prominently.
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("MISSION INTEL", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("TIME INVESTED", formattedTime),
              _buildStatItem("DEPLOYMENT DATE", createdDate),
              _buildStatItem("STATUS DATE", completedDate),
            ],
          ),
          const SizedBox(height: 16),
          // Decorative bar graph placeholder or visual
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.fhAccentTeal.withOpacity(0.1), AppTheme.fhAccentTeal.withOpacity(0.4)],
                      )
                    ),
                    child: Center(
                      child: Text("PROGRESS: ${(project.progress * 100).toInt()}%", style: TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12, fontFamily: 'RobotoMono', fontWeight: FontWeight.w500)),
      ],
    );
  }
}