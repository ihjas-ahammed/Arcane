import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/cards/submission_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class InactiveSubmissionsSection extends StatelessWidget {
  final MainTask parentTask;
  final List<SubTask> inactiveSubtasks;

  const InactiveSubmissionsSection({
    super.key,
    required this.parentTask,
    required this.inactiveSubtasks,
  });

  @override
  Widget build(BuildContext context) {
    if (inactiveSubtasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(MdiIcons.pauseCircleOutline,
                color: AppTheme.fhTextDisabled, size: 20),
            title: Text(
              "INACTIVE PROTOCOLS (${inactiveSubtasks.length})",
              style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontDisplay,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            childrenPadding: EdgeInsets.zero,
            children: inactiveSubtasks.map((st) {
              return Opacity(
                opacity: 0.6,
                child: SubmissionCard(parentTask: parentTask, subTask: st)
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}