import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';

class OverallProjectProgressCard extends StatelessWidget {
  final List<Project> activeProjects;

  const OverallProjectProgressCard({super.key, required this.activeProjects});

  @override
  Widget build(BuildContext context) {
    if (activeProjects.isEmpty) return const SizedBox.shrink();

    double totalProgress = 0;
    for (var p in activeProjects) {
      totalProgress += p.calculateProgress();
    }
    final double avgProgress = totalProgress / activeProjects.length;
    final int percentage = (avgProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "GLOBAL PROGRESS",
                  style: TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontDisplay,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  "${activeProjects.length} ACTIVE OPS",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$percentage%",
                  style: const TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontDisplay,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: avgProgress,
                    minHeight: 4,
                    backgroundColor: AppTheme.fhBgDeepDark,
                    color: AppTheme.fhAccentTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}