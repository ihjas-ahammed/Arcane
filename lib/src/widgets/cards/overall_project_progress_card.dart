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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2C3E50), AppTheme.fhBgDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OVERALL PROGRESS",
                style: TextStyle(
                  color: AppTheme.fhTextSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "$percentage%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontDisplay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avgProgress,
              minHeight: 8,
              backgroundColor: AppTheme.fhBgDeepDark,
              color: AppTheme.fhAccentTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${activeProjects.length} Active Projects",
            style: TextStyle(
                color: AppTheme.fhTextSecondary.withValues(alpha: 0.7),
                fontSize: 11),
          ),
        ],
      ),
    );
  }
}
