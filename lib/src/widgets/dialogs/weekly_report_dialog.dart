import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDeepDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.fhAccentGold.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.fhAccentGold.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhAccentGold.withOpacity(0.1))),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.fhAccentGold.withOpacity(0.05),
                    Colors.transparent
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.fhAccentGold),
                      color: AppTheme.fhAccentGold.withOpacity(0.1),
                    ),
                    child: Icon(MdiIcons.medalOutline, color: AppTheme.fhAccentGold, size: 24),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "WEEKLY DEBRIEF",
                          style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.fhTextPrimary,
                            letterSpacing: 2.0,
                            height: 1.0,
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                        const SizedBox(height: 4),
                        const Text(
                          "PERFORMANCE ANALYSIS",
                          style: TextStyle(
                            color: AppTheme.fhAccentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Section
                    _SectionHeader(title: "TACTICAL SUMMARY", icon: MdiIcons.textShort, delay: 200),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark.withOpacity(0.5),
                        border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 3)),
                      ),
                      child: Text(
                        summary,
                        style: const TextStyle(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                    const SizedBox(height: 32),

                    // Abilities Section
                    if (abilities.isNotEmpty) ...[
                      _SectionHeader(title: "KEY IMPROVEMENTS", icon: MdiIcons.arrowUpBoldCircleOutline, delay: 400),
                      const SizedBox(height: 12),
                      ...abilities.asMap().entries.map((entry) {
                        final index = entry.key;
                        final map = entry.value as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: AbilityImprovementCard(
                            name: map['name'] ?? 'Skill',
                            reason: map['reason'] ?? '',
                            score: map['score'] as int? ?? 1,
                          ).animate().fadeIn(delay: (500 + index * 100).ms).slideX(begin: 0.1, end: 0),
                        );
                      }),
                      const SizedBox(height: 32),
                    ],

                    // Time Insight Section
                    if (timeInsight.isNotEmpty) ...[
                      _SectionHeader(title: "TEMPORAL INSIGHT", icon: MdiIcons.clockTimeFourOutline, delay: 700),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.fhAccentPurple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(MdiIcons.informationOutline, size: 18, color: AppTheme.fhAccentPurple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                timeInsight,
                                style: TextStyle(
                                  color: AppTheme.fhTextSecondary,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: "ACKNOWLEDGE",
                  isPrimary: true,
                  color: AppTheme.fhAccentGold,
                  onPressed: () => Navigator.pop(context),
                ).animate().fadeIn(delay: 1000.ms).scale(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int delay;

  const _SectionHeader({required this.title, required this.icon, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.fhTextSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.fhTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppTheme.fhBorderColor.withOpacity(0.3))),
      ],
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms);
  }
}