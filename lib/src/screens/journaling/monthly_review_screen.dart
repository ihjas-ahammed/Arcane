import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/gratitude_intel_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class MonthlyReviewScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final AppProvider provider;
  final VoidCallback? onArchive;
  final DateTime? targetDate;

  const MonthlyReviewScreen({
    super.key,
    required this.reportData,
    required this.provider,
    this.onArchive,
    this.targetDate,
  });

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
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
      _regenerateStatus = 'Synthesizing 30-day monthly briefing for $dateStr...';
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
                type: BriefingType.monthly,
                statusMessage: _regenerateStatus,
              );
            },
          ),
        );
      },
    );

    try {
      final regenerated = await widget.provider.reportActions.generateMonthlyReport(
        effDate,
        (status) {
          if (mounted) {
            setState(() => _regenerateStatus = status);
          }
        },
      );

      await widget.provider.saveMonthlyReport(dateStr, regenerated);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog
        setState(() {
          _currentReportData = regenerated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentTeal,
            content: Text("Monthly Briefing ($dateStr) Regenerated & Saved!"),
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
    final monthLabel = _currentReportData['month_label'] as String? ?? '';
    final narrative = _currentReportData['narrative'] as String? ?? 'No narrative available.';

    final climate = _currentReportData['emotional_climate'] as Map<String, dynamic>?;
    final dominantEmotions = (climate?['dominant_emotions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final trajectory = climate?['trajectory'] as String? ?? '';
    final patterns = climate?['patterns'] as List<dynamic>? ?? [];

    final aar = _currentReportData['after_action_review'] as List<dynamic>? ?? [];
    final progressReview = _currentReportData['progress_review'] as List<dynamic>? ?? [];
    final identityTrajectory = _currentReportData['identity_trajectory'] as String? ?? '';
    final relationshipAudit = _currentReportData['relationship_audit'] as List<dynamic>? ?? [];
    final wellbeingDeltas = _currentReportData['wellbeing_deltas'] as List<dynamic>? ?? [];
    final lifeDomains = _currentReportData['life_domains'] as List<dynamic>? ?? [];
    final bestPossibleSelf = _currentReportData['best_possible_self'] as String? ?? '';
    final woop = _currentReportData['next_month_woop'] as List<dynamic>? ?? [];
    final gratitude = _currentReportData['gratitude_reminiscence'] as List<dynamic>? ?? [];
    final lettingGo = _currentReportData['letting_go'] as String? ?? '';

    final creativeStory = _currentReportData['creative_story'] as Map<String, dynamic>?;
    final quoteReflections = _currentReportData['quote_reflections'] as List<dynamic>? ?? [];
    final savedFinance = _currentReportData['saved_finance'] as Map<String, dynamic>?;

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
          '// MONTHLY BRIEFING',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentTeal,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ).animate().fadeIn(delay: 100.ms),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh, color: JweTheme.accentTeal),
            tooltip: 'Regenerate Monthly Briefing',
            onPressed: _isRegenerating ? null : _regenerateReport,
          ).animate().fadeIn(delay: 150.ms),
          if (widget.onArchive != null)
            IconButton(
              icon: Icon(MdiIcons.archiveArrowDownOutline, color: JweTheme.accentTeal),
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
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                children: [
                  HudReticle(size: 44, color: JweTheme.accentTeal)
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
                                'MONTH CLOSED',
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                        color: JweTheme.accentTeal.withValues(alpha: 0.4),
                                        blurRadius: 14),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 120.ms).slideX(begin: -0.05, end: 0),
                            ),
                            InkWell(
                              onTap: _isRegenerating ? null : _regenerateReport,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentTeal.withValues(alpha: 0.12),
                                  border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(MdiIcons.refresh, size: 12, color: JweTheme.accentTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REGENERATE',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentTeal,
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
                          monthLabel.isNotEmpty
                              ? monthLabel.toUpperCase()
                              : '30-DAY DEEP REVIEW',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal.withValues(alpha: 0.8),
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

            // ── Creative Story ───────────────────────
            if (creativeStory != null && (creativeStory['story']?.toString() ?? '').isNotEmpty) ...[
              const HudSectionHead(label: 'INSPIRATIONAL JOURNEY STORY', code: 'STR', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
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
                              (creativeStory['title']?.toString() ?? 'MONTHLY PARALLEL STORY').toUpperCase(),
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
                            color: JweTheme.accentAmber.withValues(alpha: 0.08),
                            border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 3)),
                          ),
                          child: Text(
                            'KEY LESSON: ${creativeStory['takeaway']}',
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
                ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Quoted Reflections & AI Reviews ────────
            if (quoteReflections.isNotEmpty) ...[
              const HudSectionHead(label: 'QUOTED HIGHLIGHTS & AI APPRECIATION', code: 'QUT', accent: HudTone.cyan),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: quoteReflections.map((item) {
                    final map = item as Map<String, dynamic>;
                    final userQuote = map['user_quote'] as String? ?? '';
                    final aiComment = map['ai_comment'] as String? ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase.withValues(alpha: 0.5),
                        border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            color: JweTheme.accentCyan.withValues(alpha: 0.08),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(MdiIcons.formatQuoteOpen, size: 14, color: JweTheme.accentCyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"$userQuote"',
                                    style: GoogleFonts.inter(
                                      color: JweTheme.textWhite,
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(MdiIcons.brain, size: 13, color: JweTheme.accentAmber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aiComment,
                                    style: GoogleFonts.inter(
                                      color: JweTheme.textMid,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 240.ms),
              ),
            ],

            // ── Static Finance Briefing Card ─────────
            if (savedFinance != null) ...[
              const HudSectionHead(label: 'MONTHLY FINANCE BRIEFING', code: 'FIN', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('INFLOW', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                          const SizedBox(height: 4),
                          Text('₹${(savedFinance['income'] as num?)?.toStringAsFixed(0) ?? 0}', style: GoogleFonts.chakraPetch(color: JweTheme.accentTeal, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: JweTheme.lineSoft),
                      Column(
                        children: [
                          Text('OUTFLOW', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                          const SizedBox(height: 4),
                          Text('₹${(savedFinance['expense'] as num?)?.toStringAsFixed(0) ?? 0}', style: GoogleFonts.chakraPetch(color: JweTheme.accentRed, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: JweTheme.lineSoft),
                      Column(
                        children: [
                          Text('NET', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                          const SizedBox(height: 4),
                          Text('₹${(savedFinance['net'] as num?)?.toStringAsFixed(0) ?? 0}', style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ),
            ],

            // ── The month's story ───────────────────────
            const HudSectionHead(label: 'THE STORY OF THE MONTH', code: 'LOG', accent: HudTone.cyan),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withValues(alpha: 0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: Text(
                  narrative,
                  style: TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── Emotional climate ───────────────────────
            if (dominantEmotions.isNotEmpty || trajectory.isNotEmpty || patterns.isNotEmpty) ...[
              const HudSectionHead(label: 'EMOTIONAL CLIMATE', code: 'EMO', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dominantEmotions.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: dominantEmotions
                              .map((e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: JweTheme.accentAmber.withValues(alpha: 0.10),
                                      border: Border.all(
                                          color: JweTheme.accentAmber
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      e.toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentAmber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      if (trajectory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(MdiIcons.chartTimelineVariant,
                                size: 14, color: JweTheme.accentAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trajectory,
                                style: TextStyle(
                                    color: JweTheme.textWhite,
                                    fontSize: 12.5,
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (patterns.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...patterns.map((p) {
                          final m = p as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: JweTheme.bgDeep.withValues(alpha: 0.5),
                              border: Border(
                                  left: BorderSide(
                                      color: JweTheme.accentAmber, width: 2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['pattern']?.toString() ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((m['evidence']?.toString() ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    m['evidence']?.toString() ?? '',
                                    style: TextStyle(
                                        color: JweTheme.textMid,
                                        fontSize: 11.5,
                                        height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── After-action review ─────────────────────
            if (aar.isNotEmpty) ...[
              const HudSectionHead(label: 'AFTER-ACTION REVIEW', code: 'AAR', accent: HudTone.red),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: aar.map((item) {
                    final m = item as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase.withValues(alpha: 0.5),
                        border: Border(
                            left: BorderSide(color: JweTheme.accentRed, width: 3)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KVRow(label: 'INTENDED', text: m['intended']?.toString() ?? '', color: JweTheme.accentCyan),
                          _KVRow(label: 'ACTUAL', text: m['actual']?.toString() ?? '', color: JweTheme.accentAmber),
                          _KVRow(label: 'WHY GAP', text: m['gap_why']?.toString() ?? '', color: JweTheme.accentRed),
                          _KVRow(label: 'ADJUST', text: m['adjustment']?.toString() ?? '', color: JweTheme.accentTeal),
                        ],
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Progress & identity ─────────────────────
            if (progressReview.isNotEmpty || identityTrajectory.isNotEmpty) ...[
              const HudSectionHead(label: 'COMPOUNDING PROGRESS', code: 'PRG', accent: HudTone.teal),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...progressReview.map((p) {
                        final m = p as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: JweTheme.accentTeal.withValues(alpha: 0.05),
                            border: Border.all(
                                color: JweTheme.accentTeal.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m['area']?.toString() ?? '').toUpperCase(),
                                style: GoogleFonts.saira(
                                  color: JweTheme.accentTeal,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['small_wins']?.toString() ?? '',
                                style: TextStyle(
                                    color: JweTheme.textWhite,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                              if ((m['compound_effect']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(MdiIcons.trendingUp,
                                        size: 12, color: JweTheme.accentTeal),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        m['compound_effect']?.toString() ?? '',
                                        style: TextStyle(
                                            color: JweTheme.textMid,
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (identityTrajectory.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(MdiIcons.fingerprint, size: 14, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Text(
                            'IDENTITY TRAJECTORY',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.bgDeep.withValues(alpha: 0.4),
                            border: Border(
                                left: BorderSide(
                                    color: JweTheme.accentCyan, width: 2)),
                          ),
                          child: Text(
                            identityTrajectory,
                            style: TextStyle(
                                color: JweTheme.textWhite,
                                fontSize: 12.5,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Wellbeing deltas & life domains ─────────
            if (wellbeingDeltas.isNotEmpty || lifeDomains.isNotEmpty) ...[
              const HudSectionHead(label: 'SYSTEM SCAN', code: 'SCN', accent: HudTone.cyan),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wellbeingDeltas.isNotEmpty) ...[
                        ...wellbeingDeltas.map((d) {
                          final m = d as Map<String, dynamic>;
                          final direction = (m['direction']?.toString() ?? 'flat').toLowerCase();
                          final isUp = direction == 'up';
                          final isDown = direction == 'down';
                          final color = isUp
                              ? JweTheme.accentTeal
                              : (isDown ? JweTheme.accentRed : JweTheme.textMuted);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isUp
                                      ? MdiIcons.arrowUpBold
                                      : (isDown
                                          ? MdiIcons.arrowDownBold
                                          : MdiIcons.minus),
                                  size: 13,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(children: [
                                      TextSpan(
                                        text: '${m['area'] ?? ''}: ',
                                        style: GoogleFonts.saira(
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: m['hypothesis']?.toString() ?? '',
                                        style: GoogleFonts.saira(
                                          color: JweTheme.textMid,
                                          fontSize: 12.5,
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
                      if (lifeDomains.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(MdiIcons.chartDonut, size: 14, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Text(
                            'LIFE DOMAIN BALANCE',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        ...lifeDomains.map((d) {
                          final m = d as Map<String, dynamic>;
                          final rating = (m['rating'] as num?)?.toInt() ?? 0;
                          final low = rating <= 4;
                          final barColor = low
                              ? JweTheme.accentRed
                              : (rating >= 7
                                  ? JweTheme.accentTeal
                                  : JweTheme.accentAmber);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      (m['domain']?.toString() ?? '').toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textWhite,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      '$rating/10',
                                      style: GoogleFonts.chakraPetch(
                                        color: barColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (rating.clamp(0, 10)) / 10.0,
                                    minHeight: 4,
                                    backgroundColor:
                                        JweTheme.bgDeep.withValues(alpha: 0.6),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(barColor),
                                  ),
                                ),
                                if ((m['evidence']?.toString() ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    m['evidence']?.toString() ?? '',
                                    style: TextStyle(
                                        color: JweTheme.textMuted,
                                        fontSize: 10.5,
                                        height: 1.35),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Relationship audit ──────────────────────
            if (relationshipAudit.isNotEmpty) ...[
              const HudSectionHead(label: 'RELATIONSHIP AUDIT', code: 'ALY', accent: HudTone.amber),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Builder(builder: (context) {
                  final grouped = <String, List<Map<String, dynamic>>>{};
                  for (final r in relationshipAudit) {
                    final m = r as Map<String, dynamic>;
                    final pName = m['name']?.toString() ?? '';
                    final existingPerson = widget.provider.chatbotMemory.people.firstWhereOrNull(
                        (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());
                    final category = existingPerson != null
                        ? PersonInfo.getRelationCategory(existingPerson.relation).toUpperCase()
                        : 'ACQUAINTANCES & OTHERS';
                    grouped.putIfAbsent(category, () => []).add(m);
                  }

                  return Column(
                    children: grouped.entries.map((entry) {
                      final category = entry.key;
                      final members = entry.value;
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            '$category (${members.length})',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          children: members.map((m) {
                            final pName = m['name']?.toString() ?? 'Unknown';
                            final existingPerson = widget.provider.chatbotMemory.people.firstWhereOrNull(
                                (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());

                            return InkWell(
                              onTap: existingPerson != null
                                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: existingPerson.id)))
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: JweTheme.bgBase.withValues(alpha: 0.6),
                                  border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          pName.toUpperCase(),
                                          style: GoogleFonts.saira(
                                            color: JweTheme.accentAmber,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (existingPerson != null)
                                          Icon(MdiIcons.chevronRight, size: 14, color: JweTheme.accentAmber),
                                      ],
                                    ),
                                    if ((m['trend']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        m['trend']?.toString() ?? '',
                                        style: TextStyle(
                                            color: JweTheme.textMid,
                                            fontSize: 12,
                                            height: 1.4),
                                      ),
                                    ],
                                    if ((m['action']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(MdiIcons.sendOutline, size: 11, color: JweTheme.accentTeal),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              m['action']?.toString() ?? '',
                                              style: TextStyle(
                                                  color: JweTheme.accentTeal,
                                                  fontSize: 11.5,
                                                  fontStyle: FontStyle.italic,
                                                  height: 1.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
                }),
              ),
            ],

            // ── Best possible self & WOOP ───────────────
            if (bestPossibleSelf.isNotEmpty || woop.isNotEmpty || lettingGo.isNotEmpty) ...[
              const HudSectionHead(label: 'NEXT MONTH PROTOCOL', code: 'NXT', accent: HudTone.teal),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HudPanel(
                  background: JweTheme.bgBase.withValues(alpha: 0.5),
                  allBrackets: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (bestPossibleSelf.isNotEmpty) ...[
                        Row(children: [
                          Icon(MdiIcons.telescope, size: 14, color: JweTheme.accentTeal),
                          const SizedBox(width: 8),
                          Text(
                            'ONE MONTH FROM NOW',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.accentTeal.withValues(alpha: 0.05),
                            border: Border(
                                left: BorderSide(
                                    color: JweTheme.accentTeal, width: 2)),
                          ),
                          child: Text(
                            bestPossibleSelf,
                            style: TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...woop.map((w) {
                        final m = w as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.bgDeep.withValues(alpha: 0.5),
                            border: Border.all(
                                color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _KVRow(label: 'WISH', text: m['wish']?.toString() ?? '', color: JweTheme.accentTeal),
                              _KVRow(label: 'OUTCOME', text: m['outcome']?.toString() ?? '', color: JweTheme.accentCyan),
                              _KVRow(label: 'OBSTACLE', text: m['obstacle']?.toString() ?? '', color: JweTheme.accentRed),
                              _KVRow(label: 'PLAN', text: m['plan']?.toString() ?? '', color: JweTheme.accentAmber),
                            ],
                          ),
                        );
                      }),
                      if (lettingGo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(MdiIcons.weightLifter, size: 14, color: JweTheme.accentRed),
                          const SizedBox(width: 8),
                          Text(
                            'DROP THE WEIGHT',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.accentRed.withValues(alpha: 0.05),
                            border: Border(
                                left: BorderSide(
                                    color: JweTheme.accentRed, width: 2)),
                          ),
                          child: Text(
                            lettingGo,
                            style: TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.05, end: 0),
              ),
            ],

            // ── Gratitude reminiscence ──────────────────
            if (gratitude.isNotEmpty) ...[
              const HudSectionHead(label: 'MOMENTS WORTH KEEPING', code: 'GRT', accent: HudTone.cyan),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: List.generate(gratitude.length.clamp(0, 10), (i) {
                    final item = gratitude[i] as Map<String, dynamic>;
                    final text = item['text'] as String? ?? '';
                    final iconType = item['icon_type'] as String? ?? 'general';
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
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _KVRow({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
              style: TextStyle(
                  color: JweTheme.textWhite, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
