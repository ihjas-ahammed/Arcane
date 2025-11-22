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

    return Column(
      children: [
        if (taskTimes.isNotEmpty)
          _buildExpandableSection(
            context,
            title: "Time Logged",
            icon: MdiIcons.clockOutline,
            count: taskTimes.length,
            children: taskTimes.entries.map((entry) {
              return _buildActivityCard(
                icon: MdiIcons.clockTimeFourOutline,
                title: "Task ID: ${entry.key.substring(0, 5)}...", // Simplified for now
                subtitle: "${entry.value} minutes logged",
                color: AppTheme.fhAccentTealFixed,
              );
            }).toList(),
          ),

        if (subtasksCompleted.isNotEmpty)
          _buildExpandableSection(
            context,
            title: "Completed Missions",
            icon: MdiIcons.checkCircleOutline,
            count: subtasksCompleted.length,
            children: subtasksCompleted.map((st) {
              final map = st as Map<String, dynamic>;
              return _buildActivityCard(
                icon: MdiIcons.target,
                title: map['name'] ?? 'Unknown Subtask',
                subtitle: "Logged: ${map['timeLogged']}m | Count: ${map['currentCount']}/${map['targetCount']}",
                color: AppTheme.fhAccentGreen,
              );
            }).toList(),
          ),

        if (checkpointsCompleted.isNotEmpty)
          _buildExpandableSection(
            context,
            title: "Checkpoints Reached",
            icon: MdiIcons.flagCheckered,
            count: checkpointsCompleted.length,
            children: checkpointsCompleted.map((cp) {
              final map = cp as Map<String, dynamic>;
              final timeStr = map['completionTimestamp'] != null 
                  ? DateFormat('HH:mm').format(DateTime.parse(map['completionTimestamp']))
                  : '';
              return _buildActivityCard(
                icon: MdiIcons.rhombusOutline,
                title: map['name'] ?? 'Unknown Checkpoint',
                subtitle: "In: ${map['parentSubtaskName']} ($timeStr)",
                color: AppTheme.fhAccentPurple,
                isSmall: true,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildExpandableSection(BuildContext context, {
    required String title,
    required IconData icon,
    required int count,
    required List<Widget> children
  }) {
    return Card(
      color: AppTheme.fhBgDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppTheme.fhTextSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.fhTextPrimary)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(12)
          ),
          child: Text("$count", style: const TextStyle(fontSize: 12, color: AppTheme.fhTextSecondary)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isSmall ? 14 : 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}