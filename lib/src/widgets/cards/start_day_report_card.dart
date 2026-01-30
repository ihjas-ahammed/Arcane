import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class StartDayReportCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const StartDayReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final briefing = report['briefing'] as String? ?? "Systems nominal.";
    final upgrades = (report['upgrades'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final projectedOps = (report['projected_ops'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.fhAccentTeal.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.robotIndustrial, color: AppTheme.fhAccentTeal, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "SYSTEM STARTUP REPORT",
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppTheme.fhTextPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            briefing,
            style: const TextStyle(
              color: AppTheme.fhTextSecondary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          
          if (upgrades.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "INSTALLED UPGRADES",
              style: TextStyle(
                color: AppTheme.fhAccentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ...upgrades.map((u) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(MdiIcons.arrowUpBold, size: 14, color: AppTheme.fhAccentGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(u, style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13))),
                ],
              ),
            )),
          ],

          if (projectedOps.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "PROJECTED OPERATIONS",
              style: TextStyle(
                color: AppTheme.fhAccentPurple,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ...projectedOps.map((op) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(MdiIcons.targetVariant, size: 14, color: AppTheme.fhAccentPurple),
                  const SizedBox(width: 8),
                  Expanded(child: Text(op, style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}