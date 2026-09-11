import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/gratitude_intel_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:intl/intl.dart';
import 'monthly/monthly.dart';

export 'monthly/monthly.dart';

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
                              ),
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
            MonthlyCreativeStoryWidget(creativeStory: creativeStory),

            // ── Quoted Reflections & AI Reviews ────────
            MonthlyQuotedReflectionsWidget(quoteReflections: quoteReflections),

            // ── Static Finance Briefing Card ─────────
            MonthlyFinanceCard(savedFinance: savedFinance),

            // ── The month's story ───────────────────────
            MonthlyStoryWidget(narrative: narrative),

            // ── Emotional climate ───────────────────────
            MonthlyEmotionalClimateSection(
              dominantEmotions: dominantEmotions,
              trajectory: trajectory,
              patterns: patterns,
            ),

            // ── After-action review ─────────────────────
            MonthlyAarSection(aar: aar),

            // ── Progress & identity ─────────────────────
            MonthlyProgressSection(
              progressReview: progressReview,
              identityTrajectory: identityTrajectory,
            ),

            // ── Wellbeing deltas & life domains ─────────
            MonthlySystemScanSection(
              wellbeingDeltas: wellbeingDeltas,
              lifeDomains: lifeDomains,
            ),

            // ── Relationship audit ──────────────────────
            MonthlyRelationshipAuditSection(
              relationshipAudit: relationshipAudit,
              provider: widget.provider,
            ),

            // ── Best possible self & WOOP ───────────────
            MonthlyProtocolSection(
              bestPossibleSelf: bestPossibleSelf,
              woop: woop,
              lettingGo: lettingGo,
            ),

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
