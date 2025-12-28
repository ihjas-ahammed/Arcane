import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
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
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[subTask.id];

    final double displayTimeSeconds = timerState != null
        ? (timerState.isRunning
            ? timerState.accumulatedDisplayTime +
                (DateTime.now().difference(timerState.startTime).inMilliseconds / 1000)
            : timerState.accumulatedDisplayTime)
        : subTask.currentTimeSpent.toDouble();

    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;

    Color borderColor = AppTheme.fhBorderColor.withOpacity(0.3);
    if (isRunning) borderColor = AppTheme.fhAccentRed;
    if (subTask.completed) borderColor = AppTheme.fhAccentTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ValorantCard(
        borderColor: borderColor,
        isSelected: isRunning,
        onTap: () => _openDetailScreen(context),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: subTask.completed
                  ? Icon(MdiIcons.checkAll, color: AppTheme.fhAccentTeal, size: 20)
                  : RhombusCheckbox(
                      checked: subTask.completed,
                      onChanged: (val) => provider.completeSubtask(parentTask.id, subTask.id),
                      size: CheckboxSize.small,
                    ),
            ),

            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subTask.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      height: 1.1,
                      decoration: subTask.completed ? TextDecoration.lineThrough : null,
                      color: subTask.completed ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "// ACTIVE COMBAT",
                        style: TextStyle(
                          color: AppTheme.fhAccentRed, 
                          fontSize: 9, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.5
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Time & Controls
            const SizedBox(width: 8),
            if (!subTask.completed) ...[
              Text(
                formattedTime,
                style: TextStyle(
                  fontFamily: "RobotoMono",
                  color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(width: 12),
              // Play/Pause
              InkWell(
                onTap: () {
                  if (isRunning) {
                    provider.pauseTimer(subTask.id);
                    provider.logTimerAndReset(subTask.id);
                  } else {
                    provider.startTimer(subTask.id, 'subtask', parentTask.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isRunning ? AppTheme.fhAccentRed.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary.withOpacity(0.5)),
                  ),
                  child: Icon(
                    isRunning ? MdiIcons.pause : MdiIcons.play,
                    size: 16,
                    color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextPrimary,
                  ),
                ),
              ),
            ],
            
            // Context Menu
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(MdiIcons.dotsVertical, color: AppTheme.fhTextSecondary, size: 18),
              color: AppTheme.fhBgDark,
              onSelected: (value) {
                if (value == 'delete') {
                  // _confirmDelete(context, provider); // Needs method logic
                  provider.deleteSubtask(parentTask.id, subTask.id); // Direct for now or add confirm
                } else if (value == 'duplicate') {
                  provider.duplicateCompletedSubtask(parentTask.id, subTask.id);
                }
              },
              itemBuilder: (context) => [
                if (subTask.completed)
                  const PopupMenuItem(value: 'duplicate', child: Text("Duplicate", style: TextStyle(color: AppTheme.fhTextPrimary))),
                const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: AppTheme.fhAccentRed))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}