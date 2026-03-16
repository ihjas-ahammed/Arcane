import 'package:flutter/material.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/ui/spidey_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

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
        color: PersonInfoTheme.bgPanel,
        border: Border.all(color: PersonInfoTheme.spideyRed, width: 2),
        boxShadow: [
          BoxShadow(
            color: PersonInfoTheme.spideyRed.withValues(alpha: 0.2),
            blurRadius: 10,
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
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.spideyCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$percentage%",
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(
                      color: Color(0x6600f0ff),
                      blurRadius: 5.0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SpideyProgressBar(
            progress: avgProgress,
            color: PersonInfoTheme.spideyRed,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${activeProjects.length} ACTIVE OPERATIONS",
              style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.textGrey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
