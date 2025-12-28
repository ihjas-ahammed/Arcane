import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart'; // Using the new Valorant Card
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

    // Valorant Logic: If running, highlight border with Red.
    Color borderColor = AppTheme.fhBorderColor.withValues(alpha: 0.3);
    if (isRunning) borderColor = AppTheme.fhAccentRed; // Active combat color
    if (subTask.completed) borderColor = AppTheme.fhAccentTeal; // Success color

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
                  ? Icon(MdiIcons.checkAll, color: AppTheme.fhAccentTeal)
                  : RhombusCheckbox(
                      checked: subTask.completed,
                      onChanged: (val) => provider.completeSubtask(parentTask.id, subTask.id),
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
                      decoration: subTask.completed ? TextDecoration.lineThrough : null,
                      color: subTask.completed ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isRunning)
                    Text(
                      "// ACTIVE COMBAT //",
                      style: TextStyle(
                        color: AppTheme.fhAccentRed, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 2.0
                      ),
                    ),
                ],
              ),
            ),

            // Actions & Context Menu (Fixed: Added access to delete/duplicate)
            Row(
              children: [
                if (!subTask.completed) ...[
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontFamily: "RobotoMono",
                      color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Play/Pause Button
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        provider.pauseTimer(subTask.id);
                        provider.logTimerAndReset(subTask.id);
                      } else {
                        provider.startTimer(subTask.id, 'subtask', parentTask.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary),
                        shape: BoxShape.rectangle, // Square buttons in Valorant
                      ),
                      child: Icon(
                        isRunning ? MdiIcons.pause : MdiIcons.play,
                        size: 16,
                        color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Options Menu (The fix)
                PopupMenuButton<String>(
                  icon: Icon(MdiIcons.dotsVertical, color: AppTheme.fhTextSecondary, size: 20),
                  color: AppTheme.fhBgDark,
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDelete(context, provider);
                    } else if (value == 'duplicate') {
                      provider.duplicateCompletedSubtask(parentTask.id, subTask.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sub-Mission Duplicated")));
                    }
                  },
                  itemBuilder: (context) => [
                    if (subTask.completed)
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 16, color: AppTheme.fhTextPrimary),
                            SizedBox(width: 8),
                            Text("Duplicate", style: TextStyle(color: AppTheme.fhTextPrimary)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppTheme.fhAccentRed),
                          SizedBox(width: 8),
                          Text("Delete", style: TextStyle(color: AppTheme.fhAccentRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("Delete Mission?", style: TextStyle(color: AppTheme.fhTextPrimary)),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            onPressed: () {
              provider.deleteSubtask(parentTask.id, subTask.id);
              Navigator.pop(ctx);
            },
            child: const Text("Confirm"),
          )
        ],
      )
    );
  }
}