import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_contingency_section.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_goals_section.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_health_section.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_inspiration_section.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_interactions_section.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_recommended_tasks.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_yesterday_progress.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/startup_wellbeing_metrics.dart';
import 'package:missions/src/widgets/dialogs/start_new_day_dialog.dart';
import 'package:provider/provider.dart';

export 'package:missions/src/widgets/cards/start_day/start_day_contingency_section.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_goals_section.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_health_section.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_inspiration_section.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_interactions_section.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_recommended_tasks.dart';
export 'package:missions/src/widgets/cards/start_day/start_day_yesterday_progress.dart';

class StartDayReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final String? date;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const StartDayReportCard({
    super.key,
    required this.report,
    this.date,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  State<StartDayReportCard> createState() => _StartDayReportCardState();
}

class _StartDayReportCardState extends State<StartDayReportCard> {
  bool _isExpanded = false;

  // Defensive readers so a malformed/older saved report never crashes the build.
  static String? _str(dynamic v) => v?.toString();
  static Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  void _startWithNora(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final forecast = _str(widget.report['forecast']) ?? "System Started.";
    final directivesRaw = widget.report['directives'];
    final directives = directivesRaw is List ? directivesRaw.join(', ') : "";

    final customContext = """
    STARTUP CONTEXT:
    Forecast: $forecast
    Directives: $directives

    The user has just initiated the system. Act as a supportive tactical commander or friend to prepare them for the day.
    """;

    provider.createNoraSession(
      title: "STARTUP LINK",
      tone: "Tactician",
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      customContext: customContext,
    );

    Navigator.push(context, MaterialPageRoute(builder: (_) => const NoraAiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final forecast = _str(widget.report['forecast']) ??
        _str(widget.report['briefing']) ??
        "Systems nominal. Ready for input.";
    final directivesRaw = widget.report['directives'];
    final directives = directivesRaw is List
        ? directivesRaw.map((e) => e.toString()).toList()
        : <String>[];
    final highlight = _str(widget.report['highlight']) ?? '';
    final anticipate = _str(widget.report['anticipate']) ?? '';
    final obstaclePlan = _map(widget.report['obstacle_plan']);
    final obstacle = _str(obstaclePlan?['obstacle']) ?? '';
    final ifThen = _str(obstaclePlan?['if_then']) ?? '';
    final metricsRaw = widget.report['metrics'];
    final metrics = metricsRaw is List ? metricsRaw : null;
    final snapshotTimeStr = _str(widget.report['snapshot_time']);
    final reportDate = snapshotTimeStr != null
        ? (DateTime.tryParse(snapshotTimeStr) ?? DateTime.now())
        : DateTime.now();
    final yesterday = reportDate.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final yesterdayQuote = _str(widget.report['yesterday_quote']) ?? '';
    final aiTodayAdvice = _str(widget.report['ai_today_advice']) ?? '';
    final motivationalQuote = _map(widget.report['motivational_quote']);

    return HudPanel(
      clip: HudClip.both,
      accent: JweTheme.accentCyan,
      allBrackets: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: JweTheme.accentCyan.withValues(alpha: 0.22),
                  ),
                ),
              ),
              child: Row(children: [
                Container(width: 4, height: 14, color: JweTheme.accentCyan),
                const SizedBox(width: 10),
                Icon(MdiIcons.power, color: JweTheme.accentCyan, size: 13),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SYSTEM STARTUP OVERVIEW',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (widget.onRegenerate != null && _isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: widget.isRegenerating ? null : widget.onRegenerate,
                      child: widget.isRegenerating
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  JweTheme.accentCyan,
                                ),
                              ),
                            )
                          : Icon(MdiIcons.refresh, size: 15, color: JweTheme.textMuted),
                    ),
                  ),
                HudDot(tone: HudTone.cyan, size: 5),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                  color: JweTheme.textMuted,
                  size: 18,
                ),
              ]),
            ),
          ),

          // ── Day Commencement Banner ──────────────────────
          if (widget.report['day_started'] != true)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: JweTheme.accentCyan.withValues(alpha: 0.12),
                border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(MdiIcons.playCircleOutline, size: 20, color: JweTheme.accentCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "STARTUP DIRECTIVES READY · DAY PENDING",
                          style: GoogleFonts.rajdhani(
                            color: JweTheme.accentCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          "Commence day to calibrate your live task baseline and begin tracking.",
                          style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                    onPressed: () {
                      final effectiveDate = widget.date ?? DateFormat('yyyy-MM-dd').format(reportDate);
                      StartNewDayDialog.show(context, date: effectiveDate);
                    },
                    child: Text(
                      "START DAY",
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 1.0),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Row(
                children: [
                  Icon(MdiIcons.checkCircleOutline, size: 12, color: JweTheme.accentCyan),
                  const SizedBox(width: 6),
                  Text(
                    "DAY COMMENCED · TASK TRACKING ACTIVE",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      final effectiveDate = widget.date ?? DateFormat('yyyy-MM-dd').format(reportDate);
                      StartNewDayDialog.show(context, date: effectiveDate);
                    },
                    child: Text(
                      "RE-CALIBRATE",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 9,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Collapsed preview ────────────────────────────
          if (!_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                forecast,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: JweTheme.textMid,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),

          // ── Expanded body ────────────────────────────────
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inspiration
                  StartDayInspirationSection(
                    yesterdayQuote: yesterdayQuote,
                    aiTodayAdvice: aiTodayAdvice,
                    motivationalQuote: motivationalQuote,
                  ),

                  // Forecast
                  Row(
                    children: [
                      Container(width: 3, height: 10, color: JweTheme.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        'COGNITIVE FORECAST MATRIX',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withValues(alpha: 0.65),
                      border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      forecast,
                      style: GoogleFonts.inter(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Today's Highlight
                  if (highlight.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(width: 3, height: 10, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text(
                        "TODAY'S HIGHLIGHT",
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber.withValues(alpha: 0.06),
                        border: Border(
                          left: BorderSide(color: JweTheme.accentAmber, width: 3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.starFourPointsOutline, size: 14, color: JweTheme.accentAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              highlight,
                              style: GoogleFonts.saira(
                                color: JweTheme.textWhite,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Directives
                  if (directives.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(width: 3, height: 10, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text(
                        'TACTICAL DIRECTIVES',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber.withValues(alpha: 0.04),
                        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: directives
                            .map((d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '> ',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentAmber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          d,
                                          style: GoogleFonts.saira(
                                            color: JweTheme.textWhite,
                                            fontSize: 12.5,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],

                  // Goals & Expected Increments Section
                  StartDayGoalsSection(provider: provider, reportDate: reportDate),

                  // Contingency & Anticipate
                  StartDayContingencySection(
                    obstacle: obstacle,
                    ifThen: ifThen,
                    anticipate: anticipate,
                  ),

                  // Yesterday's Task Progress
                  const SizedBox(height: 18),
                  StartDayYesterdayProgress(provider: provider, yesterdayStr: yesterdayStr),

                  // Yesterday's Health Data
                  const SizedBox(height: 18),
                  StartDayHealthSection(provider: provider, yesterdayStr: yesterdayStr),

                  // Metrics
                  if (metrics != null) ...[
                    const SizedBox(height: 18),
                    StartupWellbeingMetrics(metrics: metrics),
                  ],

                  // Recommended Tasks
                  const SizedBox(height: 18),
                  StartDayRecommendedTasks(provider: provider),

                  // Suggested Interactions
                  StartDayInteractionsSection(
                    savedContacts: widget.report['suggested_contacts'] is List
                        ? widget.report['suggested_contacts'] as List<dynamic>
                        : null,
                    provider: provider,
                  ),

                  const SizedBox(height: 18),

                  // NORA LINK button
                  InkWell(
                    onTap: () => _startWithNora(context),
                    child: ClipPath(
                      clipper: HudCutClipper(clip: HudClip.br, cut: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withValues(alpha: 0.10),
                          border: Border.all(
                            color: JweTheme.accentCyan.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.brain, size: 14, color: JweTheme.accentCyan),
                            const SizedBox(width: 8),
                            Text(
                              'INITIATE NORA LINK',
                              style: GoogleFonts.saira(
                                color: JweTheme.accentCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06, end: 0);
  }
}
