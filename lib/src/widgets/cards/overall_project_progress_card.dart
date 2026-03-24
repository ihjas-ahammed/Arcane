import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcane/src/widgets/ui/jwe_progress_bar.dart';

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              const Text(
                "OVERALL PROGRESS",
                style: TextStyle(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$percentage%",
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          JweProgressBar(progress: avgProgress, color: JweTheme.accentCyan),
          
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${activeProjects.length} ACTIVE OPERATIONS",
              style: const TextStyle(
                  color: JweTheme.textMuted,
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