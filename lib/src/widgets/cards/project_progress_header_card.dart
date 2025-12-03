import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ProjectProgressHeaderCard extends StatelessWidget {
  final Project project;

  const ProjectProgressHeaderCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Recalculate to ensure UI is fresh
    final double progress = project.calculateProgress();
    final int percentage = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF536DFE)], // Blue gradient similar to design
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF536DFE).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            "$percentage%",
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: AppTheme.fontDisplay,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            project.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          // Small decorative bar
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        ],
      ),
    );
  }
}