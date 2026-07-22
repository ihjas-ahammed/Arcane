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
import 'package:missions/src/theme/arc/arc_theme.dart';

class WeeklyReviewScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final AppProvider provider;
  final VoidCallback? onArchive;

  const WeeklyReviewScreen({
    super.key,
    required this.reportData,
    required this.provider,
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

    // After-action review, energy map, capitalization (share a win)
    final afterAction = reportData['after_action'] as Map<String, dynamic>?;
    final energyMap = reportData['energy_map'] as Map<String, dynamic>?;
    final energizers = (energyMap?['energizers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final drainers = (energyMap?['drainers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final shareWin = reportData['share_win'] as Map<String, dynamic>?;

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
                        accent: ArcAccents.violetBright, // Purple
                        icon: MdiIcons.heartPulse,
                        label: 'WELL-BEING TRAJECTORY',
                      ),
                    ]
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
            ),

            // ── Weekly Metrics & Dossiers Section ──
            const HudSectionHead(label: 'WEEKLY METRICS & DOSSIERS', code: 'MTR', accent: HudTone.teal),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: HudPanel(
                background: JweTheme.bgBase.withOpacity(0.5),
                allBrackets: false,
                padding: const EdgeInsets.all(16),
                child: _buildRawWeeklyMetrics(provider),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0),
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
            style:  TextStyle(color: JweTheme.textMid, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

extension WeeklyReviewScreenHelper on WeeklyReviewScreen {
  Widget _buildRawWeeklyMetrics(AppProvider provider) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Gather infinitely nested completed tasks & checkpoints tree
    CompletedNode? buildSubSubTaskNode(SubSubTask cp, Color color) {
      bool selfCompleted = false;
      String? compDateStr;
      if (cp.completed && cp.completionTimestamp != null) {
        try {
          final compDate = DateTime.parse(cp.completionTimestamp!);
          if (compDate.isAfter(weekAgo)) {
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
          if (compDate.isAfter(weekAgo)) {
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

    // Gather finance metrics
    double weekIncome = 0, weekExpense = 0;
    for (final t in provider.transactions) {
      if (t.timestamp.isAfter(weekAgo)) {
        if (t.isIncome) {
          weekIncome += t.amount;
        } else {
          weekExpense += t.amount;
        }
      }
    }
    final balance = provider.financeActions.currentBalance;

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

    // Gather people (active/known)
    final people = provider.chatbotMemory.people;

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

        // ── 3. INTERACTION BRIEF ──
        _SectionLabel(
          title: 'SOCIAL DOSSIER & ENCOUNTERS',
          icon: MdiIcons.accountMultipleOutline,
          color: JweTheme.accentCyan,
        ),
        const SizedBox(height: 12),
        if (people.isEmpty)
          Container(
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
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase.withOpacity(0.4),
              border: Border.all(color: JweTheme.lineSoft),
            ),
            child: Column(
              children: people.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(MdiIcons.accountNetworkOutline, size: 14, color: JweTheme.accentCyan),
                      const SizedBox(width: 10),
                      Text(
                        p.name.toUpperCase(),
                        style: GoogleFonts.saira(
                          color: JweTheme.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withOpacity(0.1),
                          border: Border.all(color: JweTheme.accentCyan.withOpacity(0.3)),
                        ),
                        child: Text(
                          p.relation.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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

