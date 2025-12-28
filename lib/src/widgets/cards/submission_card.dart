import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart'; // Import detail screen
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
// import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // Removed as unused according to lint, but let me check if I used it. I used Icons.play_arrow_rounded.
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
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[subTask.id];

    // Calculate display time
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

    final cardBorderColor = isRunning
        ? AppTheme.fhAccentTeal
        : AppTheme.fhBorderColor.withValues(alpha: 0.5);
    final glowColor = isRunning
        ? AppTheme.fhAccentTeal.withValues(alpha: 0.15)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 2)
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetailScreen(context), // Open detail on tap
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (subTask.completed) ...[
                  // --- COMPLETED STATE ---
                  // Name (Left Aligned)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subTask.name.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              decoration: TextDecoration
                                  .lineThrough, // Optional: strikethrough for completed
                              color: AppTheme.fhTextDisabled),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text("COMPLETED",
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.fhAccentGreen,
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),

                  // Actions: Duplicate & Delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(MdiIcons.contentCopy,
                            size: 20, color: AppTheme.fhTextSecondary),
                        tooltip: "Duplicate Sub-mission",
                        onPressed: () => provider.duplicateCompletedSubtask(
                            parentTask.id, subTask.id),
                      ),
                      IconButton(
                        icon: Icon(MdiIcons.trashCanOutline,
                            size: 20, color: AppTheme.fhAccentRed),
                        tooltip: "Delete Sub-mission",
                        onPressed: () =>
                            provider.deleteSubtask(parentTask.id, subTask.id),
                      ),
                    ],
                  ),
                ] else ...[
                  // --- ACTIVE STATE ---
                  RhombusCheckbox(
                    checked: subTask.completed,
                    onChanged: (val) =>
                        provider.completeSubtask(parentTask.id, subTask.id),
                    disabled: subTask.completed,
                    size: CheckboxSize.small,
                  ),
                  const SizedBox(width: 12),

                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subTask.name.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppTheme.fhTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Time Display
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.fhBgDeepDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                AppTheme.fhBorderColor.withValues(alpha: 0.3))),
                    child: Text(
                      formattedTime,
                      style: TextStyle(
                          fontFamily: "RobotoCondensed",
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color:
                              isRunning ? AppTheme.fhAccentTeal : Colors.white),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Play/Open Button
                  InkWell(
                    onTap: () {
                      if (isRunning) {
                        provider.pauseTimer(subTask.id);
                        provider.logTimerAndReset(subTask.id);
                      } else {
                        // FIXED: Pass parentTask.id as the mainTaskId
                        provider.startTimer(
                            subTask.id, 'subtask', parentTask.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(60),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isRunning
                                  ? AppTheme.fhAccentOrange
                                  : AppTheme.fhAccentGreen,
                              width: 3),
                          color: (isRunning
                                  ? AppTheme.fhAccentOrange
                                  : AppTheme.fhAccentGreen)
                              .withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                                color: (isRunning
                                        ? AppTheme.fhAccentOrange
                                        : AppTheme.fhAccentGreen)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2)
                          ]),
                      child: Icon(
                        isRunning ? MdiIcons.pause : MdiIcons.play,
                        color: isRunning
                            ? AppTheme.fhAccentOrange
                            : AppTheme.fhAccentGreen,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
