import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/weekly/weekly_common_widgets.dart';
import 'package:missions/src/screens/journaling/weekly/weekly_gratitude_widget.dart';
import 'package:missions/src/screens/journaling/weekly/weekly_health_intel_widget.dart';
import 'package:missions/src/screens/journaling/weekly/weekly_raw_metrics_section.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/ability_improvement_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';

export 'package:missions/src/screens/journaling/weekly/weekly_common_widgets.dart';
export 'package:missions/src/screens/journaling/weekly/weekly_completed_log_widget.dart';
export 'package:missions/src/screens/journaling/weekly/weekly_gratitude_widget.dart';
export 'package:missions/src/screens/journaling/weekly/weekly_health_intel_widget.dart';
export 'package:missions/src/screens/journaling/weekly/weekly_people_log_widget.dart';
export 'package:missions/src/screens/journaling/weekly/weekly_raw_metrics_section.dart';

class WeeklyReviewScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final AppProvider provider;
  final VoidCallback? onArchive;
  final DateTime? targetDate;

  const WeeklyReviewScreen({
    super.key,
    required this.reportData,
    required this.provider,
    this.onArchive,
    this.targetDate,
  });

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late Map<String, dynamic> _currentReportData;
  bool _isRegenerating = false;
  String? _regenerateStatus;

  @override
  void initState() {
    super.initState();
    _currentReportData = Map<String, dynamic>.from(widget.reportData);
  }

  DateTime get _effectiveDate =>
      widget.targetDate ??
      (_currentReportData['report_date'] != null ? DateTime.tryParse(_currentReportData['report_date']!) : null) ??
      (_currentReportData['generated_at'] != null ? DateTime.tryParse(_currentReportData['generated_at']!) : null) ??
      DateTime.now();

  Future<void> _regenerateReport() async {
    final effDate = _effectiveDate;

    final canProceed = await GoalBriefingHelper.showWeeklyGoalsCheckDialog(
      context,
      widget.provider,
      effDate,
    );
    if (!canProceed || !mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(effDate);

    setState(() {
      _isRegenerating = true;
      _regenerateStatus = 'Synthesizing 7-day performance review for $dateStr...';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return TacticalBriefingIndicator(
                type: BriefingType.weekly,
                statusMessage: _regenerateStatus,
              );
            },
          ),
        );
      },
    );

    try {
      final regenerated = await widget.provider.reportActions.generateWeeklyReport(
        effDate,
        (status) {
          if (mounted) {
            setState(() => _regenerateStatus = status);
          }
        },
      );

      await widget.provider.saveWeeklyReport(dateStr, regenerated);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog
        setState(() {
          _currentReportData = regenerated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentAmber,
            content: Text("7-Day Review ($dateStr) Regenerated & Saved!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentRed,
            content: Text("Regeneration failed: $e"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effDate = _effectiveDate;
    final weekStart = effDate.subtract(const Duration(days: 7));
    final weekRangeLabel = '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d, yyyy').format(effDate)}';

    // Extracting data gracefully, handling legacy formats where needed.
    final summary = _currentReportData['summary'] as String? ?? 'No summary available.';
    final wellbeingAnalysis = _currentReportData['wellbeing_analysis'] as String? ?? '';
    final healthAnalysis = _currentReportData['health_analysis'] as String? ?? '';
    final healthIntel = _currentReportData['health_intel'] as Map<String, dynamic>?;

    // GTD and Atomic Habits fields
    final gtdCurrent = _currentReportData['gtd_get_current'] as List<dynamic>? ?? [];
    final gtdCreative = _currentReportData['gtd_get_creative'] as List<dynamic>? ?? [];
    final atomicFriction = _currentReportData['atomic_friction'] as List<dynamic>? ?? [];
    final identityVotes = _currentReportData['identity_votes'] as List<dynamic>? ?? [];

    // Existing fields
    final abilities = _currentReportData['improved_abilities'] as List<dynamic>? ?? [];
    final gratefulPeople = _currentReportData['grateful_people'] as List<dynamic>? ?? [];
    final rawGratitudeByDay = (_currentReportData['gratitude_by_day'] as List<dynamic>?)
        ?? widget.provider.getWeeklyGratitudeBreakdown(effDate);
    final gratitudeHighlights = _currentReportData['gratitude_highlights'] as List<dynamic>? ?? [];

    // Convert raw gratitude by day to structured map list
    final List<Map<String, dynamic>> dailyGratitudes = [];
    for (final d in rawGratitudeByDay) {
      if (d is Map) {
        dailyGratitudes.add(Map<String, dynamic>.from(d));
      }
    }

    // After-action review, energy map, capitalization (share a win)
    final afterAction = _currentReportData['after_action'] as Map<String, dynamic>?;
    final energyMap = _currentReportData['energy_map'] as Map<String, dynamic>?;
    final energizers = (energyMap?['energizers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final drainers = (energyMap?['drainers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final shareWin = _currentReportData['share_win'] as Map<String, dynamic>?;
    final creativeStory = _currentReportData['creative_story'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(MdiIcons.chevronLeft, color: JweTheme.accentCyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '// 7-DAY REVIEW',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentAmber,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ).animate().fadeIn(delay: 100.ms),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh, color: JweTheme.accentAmber),
            tooltip: 'Regenerate 7-Day Review',
            onPressed: _isRegenerating ? null : _regenerateReport,
          ).animate().fadeIn(delay: 150.ms),
          if (widget.onArchive != null)
            IconButton(
              icon: Icon(MdiIcons.archiveArrowDownOutline, color: JweTheme.accentAmber),
              onPressed: () {
                widget.onArchive!();
                Navigator.of(context).pop();
              },
            ).animate().fadeIn(delay: 200.ms),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Section ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                children: [
                  HudReticle(size: 44, color: JweTheme.accentAmber)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.6, 0.6)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'SYSTEM DEBRIEF',
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  height: 1,
                                  shadows: [
                                    Shadow(color: JweTheme.accentAmber.withOpacity(0.4), blurRadius: 14),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 120.ms).slideX(begin: -0.05, end: 0),
                            ),
                            InkWell(
                              onTap: _isRegenerating ? null : _regenerateReport,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentAmber.withValues(alpha: 0.12),
                                  border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(MdiIcons.refresh, size: 12, color: JweTheme.accentAmber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REGENERATE',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentAmber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekRangeLabel.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber.withOpacity(0.8),
                            fontSize: 10,
                            letterSpacing: 2.0,
                          ),
                        ).animate().fadeIn(delay: 180.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Creative Inspiration Story ──────────────────────
            if (creativeStory != null && (creativeStory['story']?.toString() ?? '').isNotEmpty) ...[
              const HudSectionHead(label: 'PARALLEL JOURNEY STORY', code: 'STR', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withOpacity(0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(MdiIcons.bookOpenVariant, size: 16, color: JweTheme.accentAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (creativeStory['title']?.toString() ?? 'THE PARALLEL JOURNEY').toUpperCase(),
                              style: GoogleFonts.saira(
                                color: JweTheme.accentAmber,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        creativeStory['story']?.toString() ?? '',
                        style: TextStyle(
                          color: JweTheme.textWhite,
                          fontSize: 13,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if ((creativeStory['takeaway']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: JweTheme.accentAmber.withOpacity(0.08),
                            border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 3)),
                          ),
                          child: Text(
                            'LESSON: ${creativeStory['takeaway']}',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Telemetry (Summary & Wellbeing) ──────────────────────
            const HudSectionHead(label: 'TELEMETRY & STATUS', code: 'TLM', accent: HudTone.cyan),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withOpacity(0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextBlock(
                      text: summary,
                      accent: JweTheme.accentCyan,
                      icon: MdiIcons.radar,
                      label: 'TACTICAL SUMMARY',
                    ),
                    if (wellbeingAnalysis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      TextBlock(
                        text: wellbeingAnalysis,
                        accent: ArcAccents.violetBright, // Purple
                        icon: MdiIcons.heartPulse,
                        label: 'WELL-BEING TRAJECTORY',
                      ),
                    ]
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── Health & Vitality Debrief Section ────────────────
            const HudSectionHead(label: 'HEALTH & VITALITY DEBRIEF', code: 'HLT', accent: HudTone.teal),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withOpacity(0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (healthAnalysis.isNotEmpty) ...[
                      TextBlock(
                        text: healthAnalysis,
                        accent: JweTheme.accentTeal,
                        icon: MdiIcons.heartPulse,
                        label: 'VITALITY & RECOVERY TRAJECTORY',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (healthIntel != null) ...[
                      HealthIntelView(healthIntel: healthIntel),
                      const SizedBox(height: 16),
                    ],
                    WeeklyHealthTelemetrySummary(provider: widget.provider, effDate: effDate),
                  ],
                ),
              ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── Gratitude Intelligence (Divided by Days) ──────────
            const HudSectionHead(label: 'GRATITUDE INTELLIGENCE', code: 'GRT', accent: HudTone.cyan),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withOpacity(0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: WeeklyGratitudeDividedByDaysWidget(
                  dailyGratitudes: dailyGratitudes,
                  highlights: gratitudeHighlights,
                ),
              ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── Weekly Metrics & Operations Dossiers Section ──
            const HudSectionHead(label: 'WEEKLY METRICS & DOSSIERS', code: 'MTR', accent: HudTone.teal),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withOpacity(0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: WeeklyRawMetricsSection(
                  provider: widget.provider,
                  effectiveDate: effDate,
                  currentReportData: _currentReportData,
                ),
              ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── GTD Protocol ──────────────────────
            if (gtdCurrent.isNotEmpty || gtdCreative.isNotEmpty) ...[
              const HudSectionHead(label: 'GTD PROTOCOL', code: 'GTD', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withOpacity(0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (gtdCurrent.isNotEmpty) ...[
                        SectionLabel(title: 'GET CURRENT: NEXT ACTIONS', icon: MdiIcons.runFast, color: JweTheme.accentAmber),
                        const SizedBox(height: 12),
                        ...gtdCurrent.map((item) {
                          final map = item as Map<String, dynamic>;
                          return GTDItemCard(
                            title: map['task']?.toString() ?? 'Task',
                            description: map['next_action']?.toString() ?? '',
                            icon: MdiIcons.target,
                            color: JweTheme.accentAmber,
                          );
                        }),
                      ],
                      if (gtdCurrent.isNotEmpty && gtdCreative.isNotEmpty)
                        const SizedBox(height: 20),
                      if (gtdCreative.isNotEmpty) ...[
                        SectionLabel(title: 'GET CREATIVE: NEW HORIZONS', icon: MdiIcons.lightbulbOnOutline, color: JweTheme.accentTeal),
                        const SizedBox(height: 12),
                        ...gtdCreative.map((item) {
                          final map = item as Map<String, dynamic>;
                          return GTDItemCard(
                            title: map['idea']?.toString() ?? 'Idea',
                            description: map['reason']?.toString() ?? '',
                            icon: MdiIcons.compassOutline,
                            color: JweTheme.accentTeal,
                          );
                        }),
                      ]
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Atomic Habits ──────────────────────
            if (atomicFriction.isNotEmpty || identityVotes.isNotEmpty) ...[
              const HudSectionHead(label: 'ATOMIC ADJUSTMENTS', code: 'ATM', accent: HudTone.red),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withOpacity(0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (atomicFriction.isNotEmpty) ...[
                        SectionLabel(title: 'FRICTION ANALYSIS', icon: MdiIcons.alertDecagramOutline, color: JweTheme.accentRed),
                        const SizedBox(height: 12),
                        ...atomicFriction.map((item) {
                          final map = item as Map<String, dynamic>;
                          return FrictionCard(
                            struggle: map['struggle']?.toString() ?? '',
                            adjustment: map['adjustment']?.toString() ?? '',
                          );
                        }),
                      ],
                      if (atomicFriction.isNotEmpty && identityVotes.isNotEmpty)
                        const SizedBox(height: 20),
                      if (identityVotes.isNotEmpty) ...[
                        SectionLabel(title: 'IDENTITY VOTES', icon: MdiIcons.fingerprint, color: JweTheme.accentCyan),
                        const SizedBox(height: 12),
                        ...identityVotes.map((item) {
                          final map = item as Map<String, dynamic>;
                          return IdentityCard(
                            action: map['action']?.toString() ?? '',
                            identity: map['identity']?.toString() ?? '',
                          );
                        }),
                      ]
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── After-Action Review & Energy ──────────────
            if (afterAction != null || energizers.isNotEmpty || drainers.isNotEmpty || shareWin != null) ...[
              const HudSectionHead(label: 'DEBRIEF & ENERGY', code: 'AAR', accent: HudTone.cyan),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withOpacity(0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (afterAction != null) ...[
                        SectionLabel(title: 'AFTER-ACTION REVIEW', icon: MdiIcons.rotateLeft, color: JweTheme.accentCyan),
                        const SizedBox(height: 12),
                        AARRow(label: 'INTENDED', text: afterAction['intended']?.toString() ?? '', color: JweTheme.accentCyan),
                        AARRow(label: 'ACTUAL', text: afterAction['actual']?.toString() ?? '', color: JweTheme.accentAmber),
                        AARRow(label: 'LESSON', text: afterAction['lesson']?.toString() ?? '', color: JweTheme.accentTeal),
                      ],
                      if ((energizers.isNotEmpty || drainers.isNotEmpty)) ...[
                        if (afterAction != null) const SizedBox(height: 20),
                        SectionLabel(title: 'ENERGY MAP', icon: MdiIcons.lightningBoltOutline, color: JweTheme.accentAmber),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EnergyColumn(
                                title: 'CHARGED BY',
                                items: energizers,
                                color: JweTheme.accentTeal,
                                icon: MdiIcons.batteryPlusOutline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EnergyColumn(
                                title: 'DRAINED BY',
                                items: drainers,
                                color: JweTheme.accentRed,
                                icon: MdiIcons.batteryMinusOutline,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (shareWin != null && (shareWin['win']?.toString().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 20),
                        SectionLabel(title: 'SHARE THE WIN', icon: MdiIcons.sendOutline, color: JweTheme.accentCyan),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.accentCyan.withOpacity(0.06),
                            border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shareWin['win']?.toString() ?? '',
                                style: TextStyle(color: JweTheme.textWhite, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'TELL: ${(shareWin['person']?.toString() ?? '').toUpperCase()}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              if ((shareWin['how']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '"${shareWin['how']}"',
                                  style: TextStyle(
                                    color: JweTheme.textMid,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Capabilities & Allies ──────────────────────
            if (abilities.isNotEmpty || gratefulPeople.isNotEmpty) ...[
              const HudSectionHead(label: 'CAPABILITIES & ALLIES', code: 'CAP', accent: HudTone.teal),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (abilities.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionLabel(title: 'KEY IMPROVEMENTS', icon: MdiIcons.arrowUpBoldCircleOutline, color: JweTheme.accentTeal),
                      ),
                      ...List.generate(abilities.length, (i) {
                        final map = abilities[i] as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: AbilityImprovementCard(
                            name: map['name'] ?? 'Skill',
                            reason: map['reason'] ?? '',
                            score: map['score'] as int? ?? 1,
                          ),
                        );
                      }),
                    ],
                    if (gratefulPeople.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionLabel(title: 'ALLIES ACKNOWLEDGED', icon: MdiIcons.handHeart, color: JweTheme.accentAmber),
                      ),
                      ...List.generate(gratefulPeople.length, (i) {
                        final pMap = gratefulPeople[i] as Map<String, dynamic>;
                        final pName = pMap['name']?.toString() ?? 'Unknown';
                        final pReason = pMap['reason']?.toString() ?? '';
                        final existingPerson = widget.provider.chatbotMemory.people.where(
                            (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim()).firstOrNull;
                        final category = pMap['category']?.toString() ??
                            (existingPerson != null
                                ? PersonInfo.getRelationCategory(existingPerson.relation)
                                : PersonInfo.getRelationCategory(pMap['relation']?.toString() ?? ''));
                        final relation = pMap['relation']?.toString() ?? existingPerson?.relation;
                        return GratefulPersonCard(
                          name: pName,
                          reason: pReason,
                          category: category,
                          relation: relation,
                        );
                      }),
                    ],
                  ],
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
