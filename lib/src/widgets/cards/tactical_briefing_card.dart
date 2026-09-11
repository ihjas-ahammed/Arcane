import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_allies_briefing_section.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_finance_briefing_section.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_goals_briefing_section.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_gratitude_briefing_section.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_quotes_briefing_section.dart';
import 'package:missions/src/widgets/cards/briefing/tactical_sops_briefing_section.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

export 'package:missions/src/widgets/cards/briefing/tactical_allies_briefing_section.dart';
export 'package:missions/src/widgets/cards/briefing/tactical_finance_briefing_section.dart';
export 'package:missions/src/widgets/cards/briefing/tactical_goals_briefing_section.dart';
export 'package:missions/src/widgets/cards/briefing/tactical_gratitude_briefing_section.dart';
export 'package:missions/src/widgets/cards/briefing/tactical_quotes_briefing_section.dart';
export 'package:missions/src/widgets/cards/briefing/tactical_sops_briefing_section.dart';

class TacticalBriefingCard extends StatelessWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onSave;
  final VoidCallback? onDeleteAndRetry;
  final bool isSaved;
  final DateTime? date;

  const TacticalBriefingCard({
    super.key,
    required this.briefingData,
    this.onSave,
    this.onDeleteAndRetry,
    this.isSaved = false,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final summary = briefingData['summary'] as String? ?? "No intel available.";
    final quoteReflections = briefingData['quote_reflections'] as List<dynamic>? ?? [];
    final improvements = briefingData['improvements'] as List<dynamic>? ?? [];
    final gratefulPeople = briefingData['grateful_people'] as List<dynamic>? ?? [];
    final gratefulToday = (briefingData['grateful_today'] as List<dynamic>?) ??
        (briefingData['grateful_assets'] as List<dynamic>?) ??
        [];
    final savorMoment = briefingData['savor_moment'] as String? ?? '';
    final smallWin = briefingData['small_win'] as String? ?? '';
    final tomorrowIntention = briefingData['tomorrow_intention'] as String? ?? '';
    final suggestedActivities = briefingData['suggested_activities'] as List<dynamic>? ?? [];
    final financeBriefing = briefingData['finance_briefing'] as Map<String, dynamic>?;
    final rawSops = briefingData['suggested_sops'] ?? briefingData['suggestedSops'];
    final List<dynamic> suggestedSops;
    if (rawSops is List && rawSops.isNotEmpty) {
      suggestedSops = rawSops;
    } else {
      suggestedSops = TacticalSopsBriefingSection.generateFallbackSuggestedSops(briefingData);
    }

    return HudPanel(
      clip: HudClip.both,
      accent: JweTheme.accentAmber,
      allBrackets: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Panel header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: JweTheme.accentAmber.withValues(alpha: 0.22),
                ),
              ),
            ),
            child: Row(children: [
              Container(width: 4, height: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TACTICAL BRIEFING',
                    maxLines: 1,
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (!isSaved && onSave != null) ...[
                Tooltip(
                  message: 'Save briefing to daily log',
                  child: InkWell(
                    onTap: onSave,
                    child: ClipPath(
                      clipper: HudCutClipper(clip: HudClip.br, cut: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withValues(alpha: 0.10),
                          border: Border.all(
                            color: JweTheme.accentCyan.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'SAVE',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (onDeleteAndRetry != null) ...[
                Tooltip(
                  message: 'Delete & Retry Briefing',
                  child: InkWell(
                    onTap: onDeleteAndRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: JweTheme.accentRed.withValues(alpha: 0.10),
                        border: Border.all(
                          color: JweTheme.accentRed.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.refresh, color: JweTheme.accentRed, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            'RETRY',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentRed,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isSaved) ...[
                Icon(MdiIcons.checkBold, color: JweTheme.accentCyan, size: 15),
                const SizedBox(width: 6),
              ],
              HudDot(tone: HudTone.amber, size: 5),
            ]),
          ),

          // ── Content ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intel summary
                HudSectionHead(
                  label: 'INTEL SUMMARY',
                  accent: HudTone.amber,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                  ),
                ).animate().fadeIn(duration: 500.ms),

                // Quoted Reflections & AI Comments
                TacticalQuotesBriefingSection(quoteReflections: quoteReflections),

                // Goal Tactical Intel Section
                TacticalGoalsBriefingSection(briefingDate: date ?? DateTime.now()),

                // Daily Finance Briefing HUD
                TacticalFinanceBriefingSection(financeBriefing: financeBriefing),

                // Suggested New Activities based on day's log
                if (suggestedActivities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SUGGESTED NEW ACTIVITIES',
                    accent: HudTone.teal,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  ...suggestedActivities.map((act) {
                    final m = act as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.06),
                        border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.compassOutline, size: 14, color: JweTheme.accentTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['activity']}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: JweTheme.accentTeal,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextSpan(
                                  text: m['reason'] ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Suggested Standard Operating Procedures (SOPs)
                TacticalSopsBriefingSection(suggestedSops: suggestedSops),

                // Savor moment
                if (savorMoment.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SAVOR THIS',
                    accent: HudTone.teal,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentTeal.withValues(alpha: 0.05),
                      border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 3)),
                    ),
                    child: Text(
                      savorMoment,
                      style: GoogleFonts.inter(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Small win
                if (smallWin.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SMALL WIN LOGGED',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(MdiIcons.trophyVariantOutline, size: 14, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          smallWin,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Ability improvements
                if (improvements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'ABILITY IMPROVEMENTS',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...improvements.map((imp) {
                    final m = imp as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.arrowUpBold, size: 13, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['ability']}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: JweTheme.textWhite,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: m['insight'] ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Allies
                TacticalAlliesBriefingSection(gratefulPeople: gratefulPeople, date: date),

                // Gratitude chips
                TacticalGratitudeBriefingSection(gratefulToday: gratefulToday),

                // Tomorrow's implementation intention
                if (tomorrowIntention.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'TOMORROW INTENTION',
                    accent: HudTone.cyan,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan.withValues(alpha: 0.06),
                      border: Border.all(
                        color: JweTheme.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '> ',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tomorrowIntention,
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
