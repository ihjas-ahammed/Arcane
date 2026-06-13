import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/ability_improvement_card.dart';
import 'package:missions/src/widgets/ui/gratitude_intel_card.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class WeeklyReviewScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final VoidCallback? onArchive;

  const WeeklyReviewScreen({
    super.key,
    required this.reportData,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    // Extracting data gracefully, handling legacy formats where needed.
    final summary = reportData['summary'] as String? ?? 'No summary available.';
    final wellbeingAnalysis = reportData['wellbeing_analysis'] as String? ?? '';
    
    // New GTD and Atomic Habits fields
    final gtdCurrent = reportData['gtd_get_current'] as List<dynamic>? ?? [];
    final gtdCreative = reportData['gtd_get_creative'] as List<dynamic>? ?? [];
    final atomicFriction = reportData['atomic_friction'] as List<dynamic>? ?? [];
    final identityVotes = reportData['identity_votes'] as List<dynamic>? ?? [];

    // Existing fields
    final abilities = reportData['improved_abilities'] as List<dynamic>? ?? [];
    final gratefulPeople = reportData['grateful_people'] as List<dynamic>? ?? [];
    final gratitudeHighlights = reportData['gratitude_highlights'] as List<dynamic>? ?? [];

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
          if (onArchive != null)
            IconButton(
              icon: Icon(MdiIcons.archiveArrowDownOutline, color: JweTheme.accentAmber),
              onPressed: () {
                onArchive!();
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
                        Text(
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
                        const SizedBox(height: 6),
                        Text(
                          'TACTICAL ANALYSIS & ALIGNMENT',
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
                        accent: const Color(0xFFB07BFF), // Purple
                        icon: MdiIcons.heartPulse,
                        label: 'WELL-BEING TRAJECTORY',
                      ),
                    ]
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
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

            // ── Capabilities & Intel ──────────────────────
            if (abilities.isNotEmpty || gratitudeHighlights.isNotEmpty || gratefulPeople.isNotEmpty) ...[
              const HudSectionHead(label: 'CAPABILITIES & INTEL', code: 'CAP', accent: HudTone.teal),
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
                        return _GratefulPersonCard(
                          name: pMap['name']?.toString() ?? 'Unknown',
                          reason: pMap['reason']?.toString() ?? '',
                        );
                      }),
                    ],
                    if (gratitudeHighlights.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SectionLabel(title: 'GRATITUDE HIGHLIGHTS', icon: MdiIcons.heartOutline, color: JweTheme.accentCyan),
                      ),
                      ...List.generate(gratitudeHighlights.length.clamp(0, 5), (i) {
                        final item = gratitudeHighlights[i] as Map<String, dynamic>;
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
            style: const TextStyle(
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
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
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
                  style: const TextStyle(
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
                    style: const TextStyle(
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
                    style: const TextStyle(
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
            style: const TextStyle(
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

class _GratefulPersonCard extends StatelessWidget {
  final String name;
  final String reason;

  const _GratefulPersonCard({required this.name, required this.reason});

  @override
  Widget build(BuildContext context) {
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
          Text(
            name,
            style: GoogleFonts.saira(
              color: JweTheme.accentAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(color: JweTheme.textMid, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
