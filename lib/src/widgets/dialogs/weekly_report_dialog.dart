import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/ability_improvement_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class WeeklyReportDialog extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final VoidCallback? onSave;

  const WeeklyReportDialog({super.key, required this.reportData, this.onSave});

  @override
  State<WeeklyReportDialog> createState() => _WeeklyReportDialogState();
}

class _WeeklyReportDialogState extends State<WeeklyReportDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.reportData['summary'] as String? ?? 'No summary available.';
    final wellbeingAnalysis = widget.reportData['wellbeing_analysis'] as String? ?? '';
    final abilities = widget.reportData['improved_abilities'] as List<dynamic>? ?? [];
    final timeInsight = widget.reportData['time_insight'] as String? ?? '';
    final gratefulPeople = widget.reportData['grateful_people'] as List<dynamic>? ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (_, __) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 16 * _entry.value,
                  sigmaY: 16 * _entry.value,
                ),
                child: Container(color: JweTheme.bgDeep.withOpacity(0.55 * _entry.value)),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
                    child: FadeTransition(
                      opacity: _entry,
                      child: HudPanel(
                        clip: HudClip.both,
                        accent: JweTheme.accentAmber,
                        allBrackets: true,
                        background: JweTheme.panel,
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Section(
                                      title: 'TACTICAL SUMMARY',
                                      icon: MdiIcons.textShort,
                                      accent: JweTheme.accentCyan,
                                      delay: 200,
                                      child: _TextBlock(
                                        text: summary,
                                        accent: JweTheme.accentCyan,
                                      ),
                                    ),
                                    if (wellbeingAnalysis.isNotEmpty)
                                      _Section(
                                        title: 'WELL-BEING TRAJECTORY',
                                        icon: MdiIcons.heartPulse,
                                        accent: const Color(0xFFB07BFF),
                                        delay: 320,
                                        child: _TextBlock(
                                          text: wellbeingAnalysis,
                                          accent: const Color(0xFFB07BFF),
                                        ),
                                      ),
                                    if (abilities.isNotEmpty)
                                      _Section(
                                        title: 'KEY IMPROVEMENTS',
                                        icon: MdiIcons.arrowUpBoldCircleOutline,
                                        accent: JweTheme.accentAmber,
                                        delay: 440,
                                        child: Column(
                                          children: List.generate(abilities.length, (i) {
                                            final map = abilities[i] as Map<String, dynamic>;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 10.0),
                                              child: AbilityImprovementCard(
                                                name: map['name'] ?? 'Skill',
                                                reason: map['reason'] ?? '',
                                                score: map['score'] as int? ?? 1,
                                              )
                                                  .animate(delay: (480 + i * 90).ms)
                                                  .fadeIn(duration: 380.ms)
                                                  .slideX(begin: 0.08, end: 0),
                                            );
                                          }),
                                        ),
                                      ),
                                    if (gratefulPeople.isNotEmpty)
                                      _Section(
                                        title: 'ALLIES ACKNOWLEDGED',
                                        icon: MdiIcons.handHeart,
                                        accent: JweTheme.accentAmber,
                                        delay: 580,
                                        child: Column(
                                          children: List.generate(gratefulPeople.length, (i) {
                                            final pMap = gratefulPeople[i] as Map<String, dynamic>;
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: JweTheme.bgBase.withOpacity(0.6),
                                                border: const Border(
                                                  left: BorderSide(color: JweTheme.accentAmber, width: 2),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pMap['name'] ?? 'Unknown',
                                                    style: GoogleFonts.saira(
                                                      color: JweTheme.accentAmber,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    pMap['reason'] ?? '',
                                                    style: const TextStyle(color: JweTheme.textMid, fontSize: 12, height: 1.4),
                                                  ),
                                                ],
                                              ),
                                            ).animate(delay: (620 + i * 70).ms).fadeIn();
                                          }),
                                        ),
                                      ),
                                    if (timeInsight.isNotEmpty)
                                      _Section(
                                        title: 'TEMPORAL INSIGHT',
                                        icon: MdiIcons.clockTimeFourOutline,
                                        accent: const Color(0xFFB07BFF),
                                        delay: 720,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0x1AB07BFF),
                                            border: Border.all(color: const Color(0x66B07BFF)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(MdiIcons.informationOutline, size: 16, color: const Color(0xFFB07BFF)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  timeInsight,
                                                  style: const TextStyle(
                                                    color: JweTheme.textMid,
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            ),
                            _Footer(onSave: widget.onSave, onClose: () => Navigator.of(context).maybePop()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JweTheme.lineSoft)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFB547), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          const HudReticle(size: 28, color: JweTheme.accentAmber)
              .animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.6, 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '// 7-DAY REVIEW',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 3),
                Text(
                  'WEEKLY DEBRIEF',
                  style: GoogleFonts.saira(
                    color: JweTheme.textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1,
                    shadows: [
                      Shadow(color: JweTheme.accentAmber.withOpacity(0.4), blurRadius: 14),
                    ],
                  ),
                ).animate().fadeIn(delay: 120.ms).slideX(begin: -0.08, end: 0),
              ],
            ),
          ),
          const HudDot(tone: HudTone.amber, size: 8),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final int delay;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 3, height: 11, color: accent),
              const SizedBox(width: 8),
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: accent.withOpacity(0.25))),
            ],
          ).animate(delay: delay.ms).fadeIn(duration: 360.ms),
          const SizedBox(height: 10),
          child.animate(delay: (delay + 60).ms).fadeIn(duration: 420.ms),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String text;
  final Color accent;
  const _TextBlock({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.6),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: JweTheme.textWhite,
          fontSize: 13,
          height: 1.55,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback onClose;
  const _Footer({required this.onSave, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: JweTheme.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onClose,
              child: ClipPath(
                clipper: HudCutClipper(clip: HudClip.br, cut: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: JweTheme.border),
                  ),
                  child: Text(
                    'ACKNOWLEDGE',
                    style: GoogleFonts.saira(
                      color: JweTheme.textMid,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onSave != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onSave,
                child: ClipPath(
                  clipper: HudCutClipper(clip: HudClip.br, cut: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JweTheme.amberSoft,
                      border: Border.all(color: JweTheme.accentAmber.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(MdiIcons.archiveArrowDownOutline, size: 14, color: JweTheme.accentAmber),
                        const SizedBox(width: 8),
                        Text(
                          'ARCHIVE',
                          style: GoogleFonts.saira(
                            color: JweTheme.accentAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ).animate(delay: 900.ms).fadeIn(),
    );
  }
}
