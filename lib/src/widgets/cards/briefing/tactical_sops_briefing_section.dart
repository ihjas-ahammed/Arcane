import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/settings/sop_edit_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TacticalSopsBriefingSection extends StatelessWidget {
  final List<dynamic> suggestedSops;

  const TacticalSopsBriefingSection({
    super.key,
    required this.suggestedSops,
  });

  static List<Map<String, String>> generateFallbackSuggestedSops(Map<String, dynamic> data) {
    final acts = data['suggested_activities'] as List<dynamic>? ?? [];
    String? firstAct;
    String? firstActReason;
    if (acts.isNotEmpty && acts.first is Map) {
      firstAct = acts.first['activity']?.toString();
      firstActReason = acts.first['reason']?.toString();
    }

    return [
      {
        'title': (firstAct != null && firstAct.isNotEmpty)
            ? 'Protocol: $firstAct Routine'
            : 'Protocol: Workday Shutdown & Demarcation',
        'description': (firstActReason != null && firstActReason.isNotEmpty)
            ? 'Initiated as part of today\'s recommended focus: $firstActReason. Codifies repeatable steps to maximize efficiency.'
            : 'Executed at the end of the working session to close open cognitive loops, log remaining tasks, and transition into evening rest.',
      },
      {
        'title': 'SOP: Deep Focus & Distraction Shield',
        'description': 'Triggered prior to high-cognitive demanding sessions to eliminate notification noise, establish single-objective focus, and maintain flow.',
      },
      {
        'title': 'Protocol: Friction & Task Paralysis Reset',
        'description': 'Activated when encountering acute resistance, overwhelm, or procrastination to rapidly decompose the roadblock into a 2-minute micro-action.',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (suggestedSops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'SUGGESTED OPERATIONAL PROCEDURES (SOP)',
          accent: HudTone.amber,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Text(
          'Codify repeatable tactical protocols from today\'s experiences. Tap any SOP to configure in the SOP editor:',
          style: GoogleFonts.inter(
            color: JweTheme.textMuted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        ...suggestedSops.take(3).map((sopItem) {
          final m = sopItem is Map<String, dynamic>
              ? sopItem
              : (sopItem is Map ? Map<String, dynamic>.from(sopItem) : <String, dynamic>{});
          final title = (m['title'] ?? m['name'] ?? 'Untitled SOP').toString().trim();
          final description = (m['description'] ?? m['situation'] ?? m['reason'] ?? '').toString().trim();

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SopEditScreen(
                      initialTitle: title,
                      initialSituation: description,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.isLight
                      ? JweTheme.panel2
                      : JweTheme.bgDeep.withValues(alpha: 0.6),
                  border: Border.all(
                    color: JweTheme.isLight
                        ? JweTheme.border
                        : JweTheme.accentAmber.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(MdiIcons.clipboardTextOutline, size: 16, color: JweTheme.accentAmber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.chakraPetch(
                              fontWeight: FontWeight.bold,
                              color: JweTheme.textWhite,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: JweTheme.accentAmber.withValues(alpha: JweTheme.isLight ? 0.14 : 0.12),
                            border: Border.all(
                              color: JweTheme.accentAmber.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CONFIGURE',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.accentAmber,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(MdiIcons.arrowRight, size: 10, color: JweTheme.accentAmber),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: JweTheme.textMid,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms);
        }),
      ],
    );
  }
}
