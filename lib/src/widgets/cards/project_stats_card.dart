import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MISSION INTEL", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("TIME INVESTED", formattedTime),
              _buildStatItem("DEPLOYMENT DATE", createdDate),
              _buildStatItem("STATUS DATE", completedDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: JweTheme.textWhite, fontSize: 12, fontFamily: 'RobotoMono', fontWeight: FontWeight.w500)),
      ],
    );
  }
}