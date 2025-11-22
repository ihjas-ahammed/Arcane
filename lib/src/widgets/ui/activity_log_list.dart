import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ActivityLogList extends StatelessWidget {
  final Map<String, dynamic> taskTimes;
  final List<dynamic> subtasksCompleted;
  final List<dynamic> checkpointsCompleted;

  const ActivityLogList({
    super.key,
    required this.taskTimes,
    required this.subtasksCompleted,
    required this.checkpointsCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (taskTimes.isEmpty && subtasksCompleted.isEmpty && checkpointsCompleted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "No detailed activity recorded for this day.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.fhTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    List<Widget> items = [];

    // 1. Time Logged Summary
    if (taskTimes.isNotEmpty) {
      items.add(_buildSectionHeader("Time Logged"));
      items.addAll(taskTimes.entries.map((entry) {
        return _buildActivityCard(
          icon: MdiIcons.clockOutline,
          title: "Task ID: ${entry.key}", // Ideally resolve name via provider if accessible or pass map
          subtitle: "${entry.value} minutes logged",
          color: AppTheme.fhAccentTealFixed,
        );
      }));
    }

    // 2. Subtasks
    if (subtasksCompleted.isNotEmpty) {
      items.add(_buildSectionHeader("Completed Missions"));
      items.addAll(subtasksCompleted.map((st) {
        final map = st as Map<String, dynamic>;
        return _buildActivityCard(
          icon: MdiIcons.checkCircleOutline,
          title: map['name'] ?? 'Unknown Subtask',
          subtitle: "Logged: ${map['timeLogged']}m | Count: ${map['currentCount']}/${map['targetCount']}",
          color: AppTheme.fhAccentGreen,
        );
      }));
    }

    // 3. Checkpoints
    if (checkpointsCompleted.isNotEmpty) {
      items.add(_buildSectionHeader("Checkpoints Reached"));
      items.addAll(checkpointsCompleted.map((cp) {
        final map = cp as Map<String, dynamic>;
        final timeStr = map['completionTimestamp'] != null 
            ? DateFormat('HH:mm').format(DateTime.parse(map['completionTimestamp']))
            : '';
        return _buildActivityCard(
          icon: MdiIcons.flagCheckered,
          title: map['name'] ?? 'Unknown Checkpoint',
          subtitle: "In: ${map['parentSubtaskName']} ($timeStr)",
          color: AppTheme.fhAccentPurple,
          isSmall: true,
        );
      }));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.fhTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isSmall = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: isSmall ? 16 : 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppTheme.fhTextPrimary,
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
        ),
        dense: isSmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}