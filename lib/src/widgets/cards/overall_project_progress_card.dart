import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';

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

    return ValorantCard(
      borderColor: AppTheme.fhAccentTeal.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              const Text(
                "OVERALL PROGRESS",
                style: TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$percentage%",
                style: const TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: 24,
                  fontFamily: AppTheme.fontDisplay,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avgProgress.clamp(0.0, 1.0),
              minHeight: 6,
              color: AppTheme.fhAccentTeal,
              backgroundColor: AppTheme.fhBgDeepDark,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${activeProjects.length} ACTIVE OPERATIONS",
              style: const TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
