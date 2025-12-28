import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart'; // New Import
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class SubmissionCard extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionCard({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  void _openDetailScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubmissionDetailScreen(
          parentTask: parentTask,
          subTask: subTask,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[subTask.id];

    final double displayTimeSeconds = timerState != null
        ? (timerState.isRunning
            ? timerState.accumulatedDisplayTime +
                (DateTime.now()
                        .difference(timerState.startTime)
                        .inMilliseconds /
                    1000)
            : timerState.accumulatedDisplayTime)
        : subTask.currentTimeSpent.toDouble();

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    // Valorant Logic: If running, highlight border with accent color.
    // If completed, maybe dim or green.
    Color borderColor = AppTheme.fhBorderColor.withValues(alpha: 0.3);
    if (isRunning) borderColor = AppTheme.fhAccentRed; // Active combat color
    if (subTask.completed) borderColor = AppTheme.fhAccentGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ValorantCard(
        borderColor: borderColor,
        isSelected: isRunning, // Use selected state for running effect
        onTap: () => _openDetailScreen(context),
        child: Row(
          children: [
            // Status Icon / Checkbox
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: subTask.completed
                  ? Icon(MdiIcons.checkAll, color: AppTheme.fhAccentGreen)
                  : RhombusCheckbox(
                      checked: subTask.completed,
                      onChanged: (val) =>
                          provider.completeSubtask(parentTask.id, subTask.id),
                      size: CheckboxSize.small,
                    ),
            ),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subTask.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.5,
                      decoration:
                          subTask.completed ? TextDecoration.lineThrough : null,
                      color: subTask.completed
                          ? AppTheme.fhTextDisabled
                          : AppTheme.fhTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isRunning)
                    Text(
                      "// ACTIVE //",
                      style: TextStyle(
                          color: AppTheme.fhAccentRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0),
                    ),
                ],
              ),
            ),

            // Timer / Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedTime,
                  style: TextStyle(
                      fontFamily: "RobotoMono", // Monospace for numbers
                      color: isRunning
                          ? AppTheme.fhAccentRed
                          : AppTheme.fhTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // Play Button (Mini)
                if (!subTask.completed)
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        provider.pauseTimer(subTask.id);
                        provider.logTimerAndReset(subTask.id);
                      } else {
                        provider.startTimer(
                            subTask.id, 'subtask', parentTask.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isRunning
                                ? AppTheme.fhAccentRed
                                : AppTheme.fhTextSecondary),
                        shape: BoxShape.rectangle, // Square buttons in Valorant
                      ),
                      child: Icon(
                        isRunning ? MdiIcons.pause : MdiIcons.play,
                        size: 14,
                        color: isRunning
                            ? AppTheme.fhAccentRed
                            : AppTheme.fhTextPrimary,
                      ),
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}
