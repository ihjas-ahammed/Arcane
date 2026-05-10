import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/cards/submission_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class RecurringCompletedSection extends StatelessWidget {
  final MainTask parentTask;
  final List<SubTask> completedSubtasks;

  const RecurringCompletedSection({
    super.key,
    required this.parentTask,
    required this.completedSubtasks,
  });

  @override
  Widget build(BuildContext context) {
    if (completedSubtasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(MdiIcons.timerSand,
                color: AppTheme.fhAccentTeal, size: 20),
            title: Row(
              children: [
                Text(
                  "COOLDOWN",
                  style: TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontDisplay,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.fhAccentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.3)),
                  ),
                  child: const Text(
                    "RESETS 00:00",
                    style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            childrenPadding: EdgeInsets.zero,
            children: completedSubtasks.map((st) {
              return SubmissionCard(parentTask: parentTask, subTask: st);
            }).toList(),
          ),
        ),
      ],
    );
  }
}