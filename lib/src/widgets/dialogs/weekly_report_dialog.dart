import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/ability_improvement_card.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class WeeklyReportDialog extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const WeeklyReportDialog({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final summary = reportData['summary'] as String? ?? "No summary available.";
    final abilities = reportData['improved_abilities'] as List<dynamic>? ?? [];
    final timeInsight = reportData['time_insight'] as String? ?? "";

    return Dialog(
      backgroundColor: AppTheme.fhBgDeepDark,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.fhAccentGold.withOpacity(0.5), width: 1.5)
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.fileChartOutline, color: AppTheme.fhAccentGold, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "WEEKLY REPORT",
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.fhTextPrimary,
                        letterSpacing: 1.5
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 2, color: AppTheme.fhAccentGold.withOpacity(0.3)),
              const SizedBox(height: 24),
              
              // Summary
              Text(
                "TACTICAL SUMMARY",
                style: TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                style: const TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: 14,
                  height: 1.5
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Abilities
              if (abilities.isNotEmpty) ...[
                Text(
                  "ABILITY IMPROVEMENTS",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0
                  ),
                ),
                const SizedBox(height: 12),
                ...abilities.map((a) {
                  final map = a as Map<String, dynamic>;
                  return AbilityImprovementCard(
                    name: map['name'] ?? 'Skill',
                    reason: map['reason'] ?? '',
                    score: map['score'] as int? ?? 1,
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Time Insight
              if (timeInsight.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark,
                    border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 3))
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(MdiIcons.clockFast, size: 14, color: AppTheme.fhAccentTeal),
                          const SizedBox(width: 8),
                          const Text("TEMPORAL ANALYSIS", style: TextStyle(color: AppTheme.fhAccentTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeInsight,
                        style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Close
              SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: "DISMISS",
                  isPrimary: true,
                  color: AppTheme.fhAccentGold,
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}