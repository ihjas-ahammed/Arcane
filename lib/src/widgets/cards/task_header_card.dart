import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskHeaderCard extends StatelessWidget {
  final MainTask task;
  final int yesterdayTime;
  final List<bool> weeklyCompletion;

  const TaskHeaderCard({
    super.key,
    required this.task,
    required this.yesterdayTime,
    required this.weeklyCompletion,
  });

  String _formatMinutesToHHMM(int totalMinutes) {
    final hours = (totalMinutes / 3600).floor().round();
    final minutes = ((totalMinutes/60) % 60).floor().round();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double maxTime = yesterdayTime > 0 ? yesterdayTime.toDouble() : 60.0;
    final double progress = task.dailyTimeSpent / maxTime;
    final String timeSpentFormatted = _formatMinutesToHHMM(task.dailyTimeSpent);
    final String maxTimeFormatted = _formatMinutesToHHMM(maxTime.toInt());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDeepDark,
        image: const DecorationImage(
          image: NetworkImage("https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80"),
          fit: BoxFit.cover,
          opacity: 0.05,
        ),
        border: Border(
          bottom: BorderSide(color: task.taskColor, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: task.taskColor.withOpacity(0.2),
                child: Text(
                  task.theme.toUpperCase(),
                  style: TextStyle(
                    color: task.taskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 2.0
                  ),
                ),
              ),
              const Spacer(),
              Icon(MdiIcons.chartLine, color: AppTheme.fhTextSecondary, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          // Resized Main Title for better wrapping
          Text(
            task.name.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 32, // Reduced from 48
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: AppTheme.fhTextPrimary,
              letterSpacing: 1.2
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Text(
            task.description,
            style: const TextStyle(
              color: AppTheme.fhTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          
          // Stat Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SESSION DURATION", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    "$timeSpentFormatted / $maxTimeFormatted",
                    style: const TextStyle(
                      fontFamily: "RobotoMono",
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
              // Progress Bar Visual
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.fhBgMedium,
                    color: task.taskColor,
                    minHeight: 4,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}