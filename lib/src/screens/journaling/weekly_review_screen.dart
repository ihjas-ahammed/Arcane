import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/ability_improvement_card.dart';
import 'package:missions/src/widgets/ui/gratitude_intel_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';

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
    
    // New GTD and Atomic Habits fields
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
                    _TextBlock(
                      text: summary,
                      accent: JweTheme.accentCyan,
                      icon: MdiIcons.radar,
                      label: 'TACTICAL SUMMARY',
                    ),
                    if (wellbeingAnalysis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _TextBlock(
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
                      _TextBlock(
                        text: healthAnalysis,
                        accent: JweTheme.accentTeal,
                        icon: MdiIcons.heartPulse,
                        label: 'VITALITY & RECOVERY TRAJECTORY',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (healthIntel != null) ...[
                      _HealthIntelView(healthIntel: healthIntel),
                      const SizedBox(height: 16),
                    ],
                    _buildHealthTelemetrySummary(provider, effDate),
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
                child: _WeeklyGratitudeDividedByDaysWidget(
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
                child: _buildRawWeeklyMetrics(provider, effDate),
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
                        _SectionLabel(title: 'GET CURRENT: NEXT ACTIONS', icon: MdiIcons.runFast, color: JweTheme.accentAmber),
                        const SizedBox(height: 12),
                        ...gtdCurrent.map((item) {
                          final map = item as Map<String, dynamic>;
                          return _GTDItemCard(
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
                        _SectionLabel(title: 'GET CREATIVE: NEW HORIZONS', icon: MdiIcons.lightbulbOnOutline, color: JweTheme.accentTeal),
                        const SizedBox(height: 12),
                        ...gtdCreative.map((item) {
                          final map = item as Map<String, dynamic>;
                          return _GTDItemCard(
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
                        _SectionLabel(title: 'FRICTION ANALYSIS', icon: MdiIcons.alertDecagramOutline, color: JweTheme.accentRed),
                        const SizedBox(height: 12),
                        ...atomicFriction.map((item) {
                          final map = item as Map<String, dynamic>;
                          return _FrictionCard(
                            struggle: map['struggle']?.toString() ?? '',
                            adjustment: map['adjustment']?.toString() ?? '',
                          );
                        }),
                      ],
                      if (atomicFriction.isNotEmpty && identityVotes.isNotEmpty)
                        const SizedBox(height: 20),
                      if (identityVotes.isNotEmpty) ...[
                        _SectionLabel(title: 'IDENTITY VOTES', icon: MdiIcons.fingerprint, color: JweTheme.accentCyan),
                        const SizedBox(height: 12),
                        ...identityVotes.map((item) {
                          final map = item as Map<String, dynamic>;
                          return _IdentityCard(
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
                        _SectionLabel(title: 'AFTER-ACTION REVIEW', icon: MdiIcons.rotateLeft, color: JweTheme.accentCyan),
                        const SizedBox(height: 12),
                        _AARRow(label: 'INTENDED', text: afterAction['intended']?.toString() ?? '', color: JweTheme.accentCyan),
                        _AARRow(label: 'ACTUAL', text: afterAction['actual']?.toString() ?? '', color: JweTheme.accentAmber),
                        _AARRow(label: 'LESSON', text: afterAction['lesson']?.toString() ?? '', color: JweTheme.accentTeal),
                      ],
                      if ((energizers.isNotEmpty || drainers.isNotEmpty)) ...[
                        if (afterAction != null) const SizedBox(height: 20),
                        _SectionLabel(title: 'ENERGY MAP', icon: MdiIcons.lightningBoltOutline, color: JweTheme.accentAmber),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _EnergyColumn(
                                title: 'CHARGED BY',
                                items: energizers,
                                color: JweTheme.accentTeal,
                                icon: MdiIcons.batteryPlusOutline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EnergyColumn(
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
                        _SectionLabel(title: 'SHARE THE WIN', icon: MdiIcons.sendOutline, color: JweTheme.accentCyan),
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
                        child: _SectionLabel(title: 'KEY IMPROVEMENTS', icon: MdiIcons.arrowUpBoldCircleOutline, color: JweTheme.accentTeal),
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
                        child: _SectionLabel(title: 'ALLIES ACKNOWLEDGED', icon: MdiIcons.handHeart, color: JweTheme.accentAmber),
                      ),
                      ...List.generate(gratefulPeople.length, (i) {
                        final pMap = gratefulPeople[i] as Map<String, dynamic>;
                        final pName = pMap['name']?.toString() ?? 'Unknown';
                        final pReason = pMap['reason']?.toString() ?? '';
                        final existingPerson = provider.chatbotMemory.people.where(
                            (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim()).firstOrNull;
                        final category = pMap['category']?.toString() ??
                            (existingPerson != null
                                ? PersonInfo.getRelationCategory(existingPerson.relation)
                                : PersonInfo.getRelationCategory(pMap['relation']?.toString() ?? ''));
                        final relation = pMap['relation']?.toString() ?? existingPerson?.relation;
                        return _GratefulPersonCard(
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

class _TextBlock extends StatelessWidget {
  final String text;
  final Color accent;
  final IconData icon;
  final String label;

  const _TextBlock({
    required this.text,
    required this.accent,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withOpacity(0.4),
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          child: Text(
            text,
            style:   TextStyle(
              color: JweTheme.textWhite,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionLabel({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GTDItemCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _GTDItemCard({required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.saira(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style:   TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrictionCard extends StatelessWidget {
  final String struggle;
  final String adjustment;

  const _FrictionCard({required this.struggle, required this.adjustment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: JweTheme.bgDeep.withOpacity(0.6),
        border: Border(left: BorderSide(color: JweTheme.accentRed, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: JweTheme.accentRed.withOpacity(0.15),
            child: Row(
              children: [
                Icon(MdiIcons.alertCircleOutline, size: 14, color: JweTheme.accentRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    struggle,
                    style:   TextStyle(
                      color: JweTheme.textWhite,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MdiIcons.arrowRightBottom, size: 16, color: JweTheme.accentAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adjustment,
                    style:   TextStyle(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String action;
  final String identity;

  const _IdentityCard({required this.action, required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgDeep.withOpacity(0.6),
        border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$action"',
            style:   TextStyle(
              color: JweTheme.textMid,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(MdiIcons.checkDecagram, size: 14, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VOTE CAST: $identity',
                  style: GoogleFonts.saira(
                    color: JweTheme.accentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AARRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AARRow({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  const _EnergyColumn({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('—', style: TextStyle(color: JweTheme.textMuted, fontSize: 11))
          else
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $e',
                    style: TextStyle(color: JweTheme.textMid, fontSize: 11.5, height: 1.35),
                  ),
                )),
        ],
      ),
    );
  }
}

class _GratefulPersonCard extends StatelessWidget {
  final String name;
  final String reason;
  final String? category;
  final String? relation;

  const _GratefulPersonCard({
    required this.name,
    required this.reason,
    this.category,
    this.relation,
  });

  @override
  Widget build(BuildContext context) {
    final cat = (category != null && category!.isNotEmpty)
        ? category!
        : (relation != null && relation!.isNotEmpty ? PersonInfo.getRelationCategory(relation!) : 'Allies');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.6),
        border: Border(
          left: BorderSide(color: JweTheme.accentAmber, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.saira(
                    color: JweTheme.accentAmber,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: JweTheme.accentAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: JweTheme.accentAmber.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  cat.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          if (relation != null && relation!.trim().isNotEmpty && relation!.toLowerCase() != 'acquaintance') ...[
            const SizedBox(height: 2),
            Text(
              relation!.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(color: JweTheme.textMid, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

extension WeeklyReviewScreenHelper on WeeklyReviewScreen {
  Widget _buildHealthTelemetrySummary(AppProvider provider, DateTime effDate) {
    double totalWater = 0;
    double totalSleepMins = 0;
    double totalWalkKm = 0;
    double totalWorkoutMins = 0;
    int loggedDays = 0;
    for (int i = 0; i < 7; i++) {
      final dStr = DateFormat('yyyy-MM-dd').format(effDate.subtract(Duration(days: i)));
      final log = provider.getDailyHealthLog(dStr);
      final sleep = log.sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final walk = log.activityLogs.fold<double>(0, (sum, a) => sum + a.walkDistanceKm);
      final workout = log.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);
      if (log.waterGlasses > 0 || sleep > 0 || walk > 0 || workout > 0) loggedDays++;
      totalWater += log.waterGlasses;
      totalSleepMins += sleep;
      totalWalkKm += walk;
      totalWorkoutMins += workout;
    }
    final avgWater = totalWater / 7;
    final avgSleep = totalSleepMins / 7 / 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.4),
        border: Border.all(color: JweTheme.lineSoft),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(title: '7-DAY HEALTH TELEMETRY', icon: MdiIcons.chartBellCurveCumulative, color: JweTheme.accentTeal),
              Text(
                '$loggedDays/7 DAYS LOGGED',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HealthMetricTile(
                  label: 'SLEEP AVG',
                  value: '${avgSleep.toStringAsFixed(1)} H',
                  sub: avgSleep >= 7 ? 'OPTIMAL' : 'RECHARGE',
                  icon: MdiIcons.bedClock,
                  color: JweTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HealthMetricTile(
                  label: 'WATER AVG',
                  value: '${avgWater.toStringAsFixed(1)} GL',
                  sub: avgWater >= 8 ? 'HYDRATED' : 'HYDRATE',
                  icon: MdiIcons.cupWater,
                  color: JweTheme.accentTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HealthMetricTile(
                  label: 'WALKS TOTAL',
                  value: '${totalWalkKm.toStringAsFixed(1)} KM',
                  sub: 'DISTANCE',
                  icon: MdiIcons.walk,
                  color: JweTheme.accentAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HealthMetricTile(
                  label: 'WORKOUTS',
                  value: '${(totalWorkoutMins / 60).toStringAsFixed(1)} H',
                  sub: 'TOTAL ACTIVE',
                  icon: MdiIcons.dumbbell,
                  color: JweTheme.accentRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRawWeeklyMetrics(AppProvider provider, [DateTime? targetDate]) {
    final now = targetDate ?? _effectiveDate;
    final weekAgo = now.subtract(const Duration(days: 7));

    // Gather infinitely nested completed tasks & checkpoints tree
    CompletedNode? buildSubSubTaskNode(SubSubTask cp, Color color) {
      bool selfCompleted = false;
      String? compDateStr;
      if (cp.completed && cp.completionTimestamp != null) {
        try {
          final compDate = DateTime.parse(cp.completionTimestamp!);
          if (compDate.isAfter(weekAgo) && compDate.isBefore(now)) {
            selfCompleted = true;
            compDateStr = DateFormat('yyyy-MM-dd').format(compDate);
          }
        } catch (_) {}
      }

      final childNodes = <CompletedNode>[];
      for (final childCp in cp.substeps) {
        final node = buildSubSubTaskNode(childCp, color);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (selfCompleted || childNodes.isNotEmpty) {
        return CompletedNode(
          id: cp.id,
          name: cp.name,
          nodeType: 'checkpoint',
          color: color,
          date: compDateStr,
          isCompleted: selfCompleted,
          children: childNodes,
        );
      }
      return null;
    }

    CompletedNode? buildSubTaskNode(SubTask sub, Color color) {
      if (sub.isRecurring) return null;
      bool selfCompleted = false;
      String? compDateStr;
      if (sub.completed && sub.completedDate != null) {
        try {
          final compDate = DateTime.parse(sub.completedDate!);
          if (compDate.isAfter(weekAgo) && compDate.isBefore(now)) {
            selfCompleted = true;
            compDateStr = sub.completedDate;
          }
        } catch (_) {}
      }

      final childNodes = <CompletedNode>[];
      for (final cp in sub.subSubTasks) {
        final node = buildSubSubTaskNode(cp, color);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (selfCompleted || childNodes.isNotEmpty) {
        return CompletedNode(
          id: sub.id,
          name: sub.name,
          nodeType: 'subtask',
          color: color,
          date: compDateStr,
          isCompleted: selfCompleted,
          children: childNodes,
        );
      }
      return null;
    }

    final missionNodes = <CompletedNode>[];
    for (final task in provider.mainTasks.where((t) => !t.isDeleted)) {
      final childNodes = <CompletedNode>[];
      for (final sub in task.subTasks.where((s) => !s.isDeleted)) {
        final node = buildSubTaskNode(sub, task.taskColor);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (childNodes.isNotEmpty) {
        missionNodes.add(CompletedNode(
          id: task.id,
          name: task.name,
          nodeType: 'mission',
          color: task.taskColor,
          children: childNodes,
        ));
      }
    }

    // Gather finance metrics (static saved snapshot when archived, else calculated)
    double weekIncome = 0, weekExpense = 0, balance = provider.financeActions.currentBalance;
    final savedFinance = reportData['saved_finance'] as Map<String, dynamic>?;
    if (savedFinance != null) {
      weekIncome = (savedFinance['income'] as num?)?.toDouble() ?? 0;
      weekExpense = (savedFinance['expense'] as num?)?.toDouble() ?? 0;
      balance = (savedFinance['balance'] as num?)?.toDouble() ?? 0;
    } else {
      for (final t in provider.transactions) {
        if (t.timestamp.isAfter(weekAgo) && t.timestamp.isBefore(now)) {
          if (t.isIncome) {
            weekIncome += t.amount;
          } else {
            weekExpense += t.amount;
          }
        }
      }
    }

    // Gather health metrics
    double totalWater = 0;
    double totalSleepMins = 0;
    double totalWalkKm = 0;
    double totalWorkoutMins = 0;
    for (int i = 0; i < 7; i++) {
      final dStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final log = provider.getDailyHealthLog(dStr);
      totalWater += log.waterGlasses;
      totalSleepMins += log.sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      totalWalkKm += log.activityLogs.fold<double>(0, (sum, a) => sum + a.walkDistanceKm);
      totalWorkoutMins += log.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);
    }
    final avgWater = totalWater / 7;
    final avgSleep = totalSleepMins / 7 / 60;

    // Gather people (active/known) grouped by standard DEFAULT category
    final people = provider.chatbotMemory.people;
    const defaultCategories = [
      'FAMILY & PARTNER',
      'FRIENDS',
      'PROFESSIONAL & MENTORS',
      'ACQUAINTANCES & OTHERS',
    ];
    final groupedPeople = <String, List<PersonInfo>>{};
    for (final p in people) {
      final relationCategory = PersonInfo.getRelationCategory(p.relation).toUpperCase();
      groupedPeople.putIfAbsent(relationCategory, () => []).add(p);
    }

    final sortedCategories = groupedPeople.keys.toList()
      ..sort((a, b) {
        final idxA = defaultCategories.indexOf(a);
        final idxB = defaultCategories.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. COMPLETED TASKS & CHECKPOINTS (INFINITELY NESTED DROPDOWN) ──
        _WeeklyCompletedLogWidget(missions: missionNodes),
        const SizedBox(height: 24),

        // ── 2. METRIC DASHBOARDS (FINANCE & HEALTH) ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Finance Brief Card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(
                    title: 'FINANCE BRIEF',
                    icon: MdiIcons.currencyInr,
                    color: JweTheme.accentAmber,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase.withOpacity(0.4),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBriefMetricRow('INFLOW', '₹${weekIncome.toStringAsFixed(0)}', JweTheme.accentTeal),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('OUTFLOW', '₹${weekExpense.toStringAsFixed(0)}', JweTheme.accentRed),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('NET INFLOW', '₹${(weekIncome - weekExpense).toStringAsFixed(0)}', (weekIncome - weekExpense) >= 0 ? JweTheme.accentTeal : JweTheme.accentRed),
                        Divider(color: JweTheme.lineSoft, height: 16),
                        _buildBriefMetricRow('BALANCE', '₹${balance.toStringAsFixed(0)}', JweTheme.textWhite),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Health Brief Card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(
                    title: 'HEALTH BRIEF',
                    icon: MdiIcons.heartPulse,
                    color: JweTheme.accentCyan,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase.withOpacity(0.4),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBriefMetricRow('SLEEP AVG', '${avgSleep.toStringAsFixed(1)} H/DAY', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WATER AVG', '${avgWater.toStringAsFixed(1)} GL/DAY', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WALKS TOTAL', '${totalWalkKm.toStringAsFixed(1)} KM', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WORKOUTS', '${(totalWorkoutMins / 60).toStringAsFixed(1)} H', JweTheme.accentCyan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── 3. INTERACTION BRIEF (CLASSIFIED DROPDOWN) ──
        _WeeklyPeopleLogWidget(
          sortedCategories: sortedCategories,
          groupedPeople: groupedPeople,
          provider: provider,
        ),
      ],
    );
  }

  Widget _buildBriefMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.chakraPetch(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CompletedNode {
  final String id;
  final String name;
  final String nodeType; // 'mission' | 'subtask' | 'checkpoint'
  final Color color;
  final String? date;
  final bool isCompleted;
  final List<CompletedNode> children;

  CompletedNode({
    required this.id,
    required this.name,
    required this.nodeType,
    required this.color,
    this.date,
    this.isCompleted = false,
    List<CompletedNode>? children,
  }) : children = children ?? [];

  int get totalCompletedCount {
    int count = (isCompleted && nodeType != 'mission') ? 1 : 0;
    for (final child in children) {
      count += child.totalCompletedCount;
    }
    return count;
  }
}

class _WeeklyCompletedLogWidget extends StatefulWidget {
  final List<CompletedNode> missions;

  const _WeeklyCompletedLogWidget({required this.missions});

  @override
  State<_WeeklyCompletedLogWidget> createState() => _WeeklyCompletedLogWidgetState();
}

class _WeeklyCompletedLogWidgetState extends State<_WeeklyCompletedLogWidget> {
  int _expandAllTrigger = 0;
  bool _expandAllValue = false;

  void _toggleAll(bool expand) {
    setState(() {
      _expandAllTrigger++;
      _expandAllValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.missions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            title: 'WEEKLY OPERATION LOG (COMPLETED)',
            icon: MdiIcons.checkboxMarkedCircleOutline,
            color: JweTheme.accentTeal,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: JweTheme.bgBase.withOpacity(0.3),
              border: Border.all(color: JweTheme.lineSoft),
            ),
            child: Text(
              'NO COMPLETED TASKS OR CHECKPOINTS DETECTED THIS WEEK.',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final totalCompletedCount = widget.missions.fold<int>(0, (sum, m) => sum + m.totalCompletedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    title: 'WEEKLY OPERATION LOG',
                    icon: MdiIcons.checkboxMarkedCircleOutline,
                    color: JweTheme.accentTeal,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.missions.length} MISSIONS • $totalCompletedCount COMPLETED',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _toggleAll(true),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.expandAll, size: 14, color: JweTheme.accentTeal),
                        const SizedBox(width: 2),
                        Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _toggleAll(false),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.collapseAll, size: 14, color: JweTheme.accentTeal),
                        const SizedBox(width: 2),
                        Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.missions.map((missionNode) {
          return _NestedCompletedNodeWidget(
            node: missionNode,
            depth: 0,
            expandAllTrigger: _expandAllTrigger,
            expandAllValue: _expandAllValue,
          );
        }),
      ],
    );
  }
}

class _NestedCompletedNodeWidget extends StatefulWidget {
  final CompletedNode node;
  final int depth;
  final int expandAllTrigger;
  final bool expandAllValue;

  const _NestedCompletedNodeWidget({
    required this.node,
    required this.depth,
    required this.expandAllTrigger,
    required this.expandAllValue,
  });

  @override
  State<_NestedCompletedNodeWidget> createState() => _NestedCompletedNodeWidgetState();
}

class _NestedCompletedNodeWidgetState extends State<_NestedCompletedNodeWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
  }

  @override
  void didUpdateWidget(covariant _NestedCompletedNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandAllTrigger != oldWidget.expandAllTrigger) {
      _isExpanded = widget.expandAllValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final color = node.color;
    final isMission = widget.depth == 0;
    final isSubtask = node.nodeType == 'subtask';

    // ── LEAF NODE (No children) ──
    if (!hasChildren) {
      return Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: widget.depth == 0 ? 0 : 10.0 * widget.depth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.5),
          border: Border(
            left: BorderSide(
              color: isSubtask ? color : JweTheme.textMuted.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSubtask ? MdiIcons.bookmarkCheckOutline : MdiIcons.checkCircleOutline,
              size: 14,
              color: isSubtask ? color : JweTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.name.toUpperCase(),
                style: GoogleFonts.saira(
                  color: JweTheme.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            if (node.date != null) ...[
              const SizedBox(width: 8),
              Text(
                node.date!,
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ]
          ],
        ),
      );
    }

    // ── DROPDOWN NODE (Has children recursively) ──
    if (isMission) {
      // Top Level Mission Card
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.4),
          border: Border.all(
            color: _isExpanded ? color.withOpacity(0.6) : JweTheme.lineSoft,
            width: _isExpanded ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.name.toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${node.children.length} DIRECT ITEM${node.children.length > 1 ? 'S' : ''} • ${node.totalCompletedCount} COMPLETED',
                            style: GoogleFonts.jetBrainsMono(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                      color: _isExpanded ? color : JweTheme.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: color.withOpacity(0.2))),
                  color: color.withOpacity(0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: node.children.map((child) {
                    return _NestedCompletedNodeWidget(
                      node: child,
                      depth: widget.depth + 1,
                      expandAllTrigger: widget.expandAllTrigger,
                      expandAllValue: widget.expandAllValue,
                    );
                  }).toList(),
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      );
    }

    // Nested Subtask / Checkpoint Dropdown (Depth >= 1)
    return Container(
      margin: EdgeInsets.only(
        bottom: 6,
        left: 8.0 * widget.depth,
      ),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.35),
        border: Border(
          left: BorderSide(color: color.withOpacity(0.7), width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSubtask ? MdiIcons.folderCheckOutline : MdiIcons.checkboxMultipleMarkedOutline,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name.toUpperCase(),
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${node.children.length} SUB-ITEM${node.children.length > 1 ? 'S' : ''}',
                              style: GoogleFonts.jetBrainsMono(
                                color: color.withOpacity(0.9),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (node.isCompleted && node.date != null) ...[
                              Text(
                                ' • DONE ${node.date}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronDown : MdiIcons.chevronRight,
                    color: color,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: node.children.map((child) {
                  return _NestedCompletedNodeWidget(
                    node: child,
                    depth: widget.depth + 1,
                    expandAllTrigger: widget.expandAllTrigger,
                    expandAllValue: widget.expandAllValue,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _HealthMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _HealthMetricTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.chakraPetch(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthIntelView extends StatelessWidget {
  final Map<String, dynamic> healthIntel;

  const _HealthIntelView({required this.healthIntel});

  @override
  Widget build(BuildContext context) {
    final sleepInsight = healthIntel['sleep_insight']?.toString() ?? '';
    final activityInsight = healthIntel['activity_insight']?.toString() ?? '';
    final recoveryScore = healthIntel['recovery_score']?.toString() ?? '';
    final vitalityQuote = healthIntel['vitality_quote']?.toString() ?? '';
    final tip = healthIntel['actionable_tip']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.accentTeal.withOpacity(0.06),
        border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recoveryScore.isNotEmpty) ...[
            Row(
              children: [
                Icon(MdiIcons.shieldCheckOutline, size: 14, color: JweTheme.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'RECOVERY INDEX: $recoveryScore'.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (sleepInsight.isNotEmpty) ...[
            _HealthInsightRow(icon: MdiIcons.bedClock, label: 'SLEEP & RECOVERY', text: sleepInsight),
            const SizedBox(height: 6),
          ],
          if (activityInsight.isNotEmpty) ...[
            _HealthInsightRow(icon: MdiIcons.runFast, label: 'MOVEMENT & VITALITY', text: activityInsight),
            const SizedBox(height: 6),
          ],
          if (tip.isNotEmpty) ...[
            _HealthInsightRow(icon: MdiIcons.lightbulbOnOutline, label: 'ACTIONABLE TIP', text: tip, isAccent: true),
            const SizedBox(height: 6),
          ],
          if (vitalityQuote.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '"$vitalityQuote"',
                style: TextStyle(
                  color: JweTheme.textMid,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthInsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final bool isAccent;

  const _HealthInsightRow({
    required this.icon,
    required this.label,
    required this.text,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? JweTheme.accentAmber : JweTheme.accentTeal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.jetBrainsMono(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyGratitudeDividedByDaysWidget extends StatefulWidget {
  final List<Map<String, dynamic>> dailyGratitudes;
  final List<dynamic> highlights;

  const _WeeklyGratitudeDividedByDaysWidget({
    required this.dailyGratitudes,
    required this.highlights,
  });

  @override
  State<_WeeklyGratitudeDividedByDaysWidget> createState() => _WeeklyGratitudeDividedByDaysWidgetState();
}

class _WeeklyGratitudeDividedByDaysWidgetState extends State<_WeeklyGratitudeDividedByDaysWidget> {
  int _expandAllTrigger = 0;
  bool _expandAllValue = true;

  void _toggleAll(bool expand) {
    setState(() {
      _expandAllTrigger++;
      _expandAllValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalNotes = widget.dailyGratitudes.fold<int>(0, (sum, day) => sum + ((day['items'] as List?)?.length ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    title: 'DAILY GRATITUDE BREAKDOWN',
                    icon: MdiIcons.heartPulse,
                    color: JweTheme.accentCyan,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.dailyGratitudes.length} DAYS • $totalNotes GRATITUDE NOTES',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _toggleAll(true),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.expandAll, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 2),
                        Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _toggleAll(false),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.collapseAll, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 2),
                        Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.dailyGratitudes.map((dayData) {
          return _GratitudeDayTile(
            dayData: dayData,
            expandTrigger: _expandAllTrigger,
            expandValue: _expandAllValue,
          );
        }),
        if (widget.highlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionLabel(
            title: 'WEEKLY HIGHLIGHTS',
            icon: MdiIcons.starFourPointsOutline,
            color: JweTheme.accentAmber,
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.highlights.length, (i) {
            final raw = widget.highlights[i];
            final map = raw is Map<String, dynamic>
                ? raw
                : (raw is Map ? Map<String, dynamic>.from(raw) : {'text': raw.toString()});
            final text = map['text']?.toString() ?? '';
            final iconType = map['icon_type']?.toString() ?? 'general';
            if (text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GratitudeIntelCard(
                text: text,
                iconType: iconType,
                index: i + 1,
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _GratitudeDayTile extends StatefulWidget {
  final Map<String, dynamic> dayData;
  final int expandTrigger;
  final bool expandValue;

  const _GratitudeDayTile({
    required this.dayData,
    required this.expandTrigger,
    required this.expandValue,
  });

  @override
  State<_GratitudeDayTile> createState() => _GratitudeDayTileState();
}

class _GratitudeDayTileState extends State<_GratitudeDayTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = true;
  }

  @override
  void didUpdateWidget(covariant _GratitudeDayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandTrigger != oldWidget.expandTrigger) {
      _isExpanded = widget.expandValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = widget.dayData['day_name']?.toString() ?? '';
    final dateStr = widget.dayData['date']?.toString() ?? '';
    final label = widget.dayData['label']?.toString() ?? (dayName.isNotEmpty ? '$dayName ($dateStr)' : dateStr);
    final rawItems = widget.dayData['items'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.45),
        border: Border(
          left: BorderSide(
            color: rawItems.isNotEmpty ? JweTheme.accentCyan : JweTheme.textMuted.withOpacity(0.4),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.calendarTodayOutline,
                    size: 14,
                    color: rawItems.isNotEmpty ? JweTheme.accentCyan : JweTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: JweTheme.accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${rawItems.length} NOTE${rawItems.length == 1 ? '' : 'S'}',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentCyan,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    color: JweTheme.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: rawItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        'No reflections or gratitude notes recorded on this day.',
                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rawItems.map((item) {
                        final map = item is Map<String, dynamic>
                            ? item
                            : (item is Map ? Map<String, dynamic>.from(item) : {'text': item.toString()});
                        final text = map['text']?.toString() ?? '';
                        final iconType = map['icon_type']?.toString() ?? 'general';
                        if (text.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GratitudeIntelCard(
                            text: text,
                            iconType: iconType,
                            index: 0,
                          ),
                        );
                      }).toList(),
                    ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPeopleLogWidget extends StatefulWidget {
  final List<String> sortedCategories;
  final Map<String, List<PersonInfo>> groupedPeople;
  final AppProvider provider;

  const _WeeklyPeopleLogWidget({
    required this.sortedCategories,
    required this.groupedPeople,
    required this.provider,
  });

  @override
  State<_WeeklyPeopleLogWidget> createState() => _WeeklyPeopleLogWidgetState();
}

class _WeeklyPeopleLogWidgetState extends State<_WeeklyPeopleLogWidget> {
  bool _isExpanded = false;
  int _categoryToggleTrigger = 0;
  bool _categoryToggleValue = false;

  void _toggleAllCategories(bool expand) {
    setState(() {
      _isExpanded = true;
      _categoryToggleTrigger++;
      _categoryToggleValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalContacts = widget.groupedPeople.values.fold<int>(0, (sum, l) => sum + l.length);
    if (totalContacts == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.3),
          border: Border.all(color: JweTheme.lineSoft),
        ),
        child: Text(
          'NO REGISTERED CONTACTS LOGGED IN SYSTEM.',
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.4),
        border: Border.all(
          color: _isExpanded ? JweTheme.accentCyan.withOpacity(0.6) : JweTheme.lineSoft,
          width: _isExpanded ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: JweTheme.accentCyan.withOpacity(0.5), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOCIAL DOSSIER & ENCOUNTERS',
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalContacts CONTACT${totalContacts > 1 ? 'S' : ''} ACROSS ${widget.sortedCategories.length} CATEGORIES',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isExpanded) ...[
                    InkWell(
                      onTap: () => _toggleAllCategories(true),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _toggleAllCategories(false),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    color: _isExpanded ? JweTheme.accentCyan : JweTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: JweTheme.accentCyan.withOpacity(0.2))),
                color: JweTheme.accentCyan.withOpacity(0.03),
              ),
              child: Column(
                children: widget.sortedCategories.map((category) {
                  final members = widget.groupedPeople[category] ?? [];
                  return _PeopleCategoryTile(
                    category: category,
                    members: members,
                    provider: widget.provider,
                    toggleTrigger: _categoryToggleTrigger,
                    toggleValue: _categoryToggleValue,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _PeopleCategoryTile extends StatefulWidget {
  final String category;
  final List<PersonInfo> members;
  final AppProvider provider;
  final int toggleTrigger;
  final bool toggleValue;

  const _PeopleCategoryTile({
    required this.category,
    required this.members,
    required this.provider,
    required this.toggleTrigger,
    required this.toggleValue,
  });

  @override
  State<_PeopleCategoryTile> createState() => _PeopleCategoryTileState();
}

class _PeopleCategoryTileState extends State<_PeopleCategoryTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
  }

  @override
  void didUpdateWidget(covariant _PeopleCategoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toggleTrigger != oldWidget.toggleTrigger) {
      _isExpanded = widget.toggleValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.3),
        border: Border(
          left: BorderSide(color: JweTheme.accentCyan.withOpacity(0.6), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(MdiIcons.accountGroupOutline, size: 14, color: JweTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.category} (${widget.members.length})',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    size: 16,
                    color: JweTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Column(
                children: widget.members.map((p) {
                  return InkWell(
                    onTap: () {
                      final matches = widget.provider.chatbotMemory.people.where(
                          (e) => e.name.toLowerCase().trim() == p.name.toLowerCase().trim());
                      final existing = matches.isNotEmpty ? matches.first : null;
                      if (existing != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: existing.id)));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(MdiIcons.accountOutline, size: 13, color: JweTheme.accentTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name.toUpperCase(),
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (p.relation.trim().isNotEmpty && p.relation.toLowerCase() != 'acquaintance')
                                  Text(
                                    p.relation.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted,
                                      fontSize: 8.5,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(MdiIcons.chevronRight, size: 13, color: JweTheme.accentCyan),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

