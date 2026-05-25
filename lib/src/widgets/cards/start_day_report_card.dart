import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/startup_wellbeing_metrics.dart';
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class StartDayReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const StartDayReportCard({
    super.key,
    required this.report,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  State<StartDayReportCard> createState() => _StartDayReportCardState();
}

class _StartDayReportCardState extends State<StartDayReportCard> {
  bool _isExpanded = false;

  void _startWithNora(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final forecast = widget.report['forecast'] as String? ?? "System Started.";
    final directives = (widget.report['directives'] as List?)?.join(', ') ?? "";

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
    final forecast = widget.report['forecast'] as String? ??
        widget.report['briefing'] as String? ??
        "Systems nominal. Ready for input.";
    final directives = (widget.report['directives'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final metrics = widget.report['metrics'] as List<dynamic>?;
    final taskSnapshot = widget.report['task_snapshot'] as Map<String, dynamic>?;

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
                        color: JweTheme.accentCyan.withValues(alpha: 0.22))),
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
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      JweTheme.accentCyan)),
                            )
                          : Icon(MdiIcons.refresh,
                              size: 15, color: JweTheme.textMuted),
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
                  // Forecast
                  Text('AI FORECAST',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    forecast,
                    style: GoogleFonts.inter(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  // Directives
                  if (directives.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(width: 3, height: 10, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text('DIRECTIVES',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          )),
                    ]),
                    const SizedBox(height: 10),
                    ...directives.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('> ',
                                  style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.accentCyan,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                              Expanded(
                                child: Text(d,
                                    style: GoogleFonts.saira(
                                      color: JweTheme.textWhite,
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ],
                          ),
                        )),
                  ],

                  // Metrics
                  if (metrics != null) ...[
                    const SizedBox(height: 18),
                    StartupWellbeingMetrics(metrics: metrics),
                  ],

                  // Task progress delta
                  if (taskSnapshot != null && taskSnapshot.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    TaskProgressSnapshotView(
                      taskSnapshot: taskSnapshot,
                      liveTasks: provider.mainTasks,
                    ),
                  ],

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
                              color: JweTheme.accentCyan.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.brain,
                                size: 14, color: JweTheme.accentCyan),
                            const SizedBox(width: 8),
                            Text('INITIATE NORA LINK',
                                style: GoogleFonts.saira(
                                  color: JweTheme.accentCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                )),
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
