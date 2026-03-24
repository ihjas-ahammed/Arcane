import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/ability_improvement_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class WeeklyReportDialog extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final VoidCallback? onSave;

  const WeeklyReportDialog({super.key, required this.reportData, this.onSave});

  @override
  Widget build(BuildContext context) {
    final summary = reportData['summary'] as String? ?? "No summary available.";
    final wellbeingAnalysis = reportData['wellbeing_analysis'] as String? ?? "";
    final abilities = reportData['improved_abilities'] as List<dynamic>? ?? [];
    final timeInsight = reportData['time_insight'] as String? ?? "";
    final gratefulPeople = reportData['grateful_people'] as List<dynamic>? ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          border: Border.all(color: JweTheme.accentAmber.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: JweTheme.accentAmber.withOpacity(0.1),
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
                border: Border(bottom: BorderSide(color: JweTheme.border)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    JweTheme.accentAmber.withOpacity(0.05),
                    Colors.transparent
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: JweTheme.accentAmber),
                      color: JweTheme.accentAmber.withOpacity(0.1),
                    ),
                    child: Icon(MdiIcons.medalOutline, color: JweTheme.accentAmber, size: 24),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "WEEKLY DEBRIEF",
                          style: GoogleFonts.rajdhani(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: JweTheme.textWhite,
                            letterSpacing: 2.0,
                            height: 1.0,
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                        const SizedBox(height: 4),
                        const Text(
                          "PERFORMANCE ANALYSIS",
                          style: TextStyle(
                            color: JweTheme.accentAmber,
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
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase.withOpacity(0.5),
                        border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                      ),
                      child: Text(
                        summary,
                        style: const TextStyle(
                          color: JweTheme.textWhite,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                    const SizedBox(height: 32),

                    if (wellbeingAnalysis.isNotEmpty) ...[
                        _SectionHeader(title: "WELL-BEING TRAJECTORY", icon: MdiIcons.heartPulse, delay: 350),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: JweTheme.bgBase.withOpacity(0.5),
                            border: Border(left: BorderSide(color: const Color(0xFF8A2BE2), width: 3)), // Purple
                          ),
                          child: Text(
                            wellbeingAnalysis,
                            style: const TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                        const SizedBox(height: 32),
                    ],

                    // Abilities Section
                    if (abilities.isNotEmpty) ...[
                      _SectionHeader(title: "KEY IMPROVEMENTS", icon: MdiIcons.arrowUpBoldCircleOutline, delay: 450),
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

                    // Grateful People Section
                    if (gratefulPeople.isNotEmpty) ...[
                      _SectionHeader(title: "ALLIES ACKNOWLEDGED", icon: MdiIcons.handHeart, delay: 600),
                      const SizedBox(height: 12),
                      ...gratefulPeople.map((person) {
                        final pMap = person as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.bgBase.withOpacity(0.5),
                            border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 2))
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pMap['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: JweTheme.accentAmber)),
                              const SizedBox(height: 4),
                              Text(pMap['reason'] ?? '', style: const TextStyle(color: JweTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 650.ms);
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
                          color: const Color(0xFF8A2BE2).withOpacity(0.05),
                          border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(MdiIcons.informationOutline, size: 18, color: const Color(0xFF8A2BE2)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                timeInsight,
                                style: const TextStyle(
                                  color: JweTheme.textMuted,
                                  fontSize: 12,
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JweTheme.textMuted,
                        side: BorderSide(color: JweTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const BeveledRectangleBorder()
                      ),
                      child: const Text("ACKNOWLEDGE"),
                    ),
                  ),
                  if (onSave != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JweTheme.accentAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const BeveledRectangleBorder()
                        ),
                        child: const Text("ARCHIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]
                ],
              ).animate().fadeIn(delay: 1000.ms).scale(),
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
        Icon(icon, size: 16, color: JweTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: JweTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: JweTheme.border)),
      ],
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms);
  }
}