import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/widgets/dialogs/wellbeing_detail_dialog.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// "INSIGHT ACQUIRED" alert shown after a reflection's AI analysis completes.
/// Rendered as a compact modal floating over the underlying screen, styled to
/// match the logbook screen's HUD panels.
class XpGainDialog extends StatelessWidget {
  final Map<String, int> xpGained;
  final String? insightText;

  const XpGainDialog({super.key, required this.xpGained, this.insightText});

  @override
  Widget build(BuildContext context) {
    final entries = xpGained.entries.where((e) => e.value > 0).toList();
    final totalXp = entries.fold<int>(0, (a, b) => a + b.value);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: HudPanel(
          clip: HudClip.both,
          accent: JweTheme.accentAmber,
          allBrackets: true,
          background: JweTheme.panel,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(totalXp: totalXp),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entries.isNotEmpty) ...[
                        _SkillsBlock(entries: entries),
                        const SizedBox(height: 14),
                      ],
                      if (insightText != null && insightText!.isNotEmpty)
                        _TransmissionBlock(text: insightText!),
                    ],
                  ),
                ),
              ),
              _Footer(onClose: () => Navigator.of(context).maybePop()),
            ],
          ),
        ).animate().fadeIn(duration: 180.ms).scale(
              begin: const Offset(0.94, 0.94),
              end: const Offset(1, 1),
              duration: 240.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int totalXp;
  const _Header({required this.totalXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JweTheme.lineSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HudReticle(size: 22, color: JweTheme.accentAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '// SIGNAL DECODED',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'INSIGHT ACQUIRED',
                  style: GoogleFonts.saira(
                    color: JweTheme.textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          _XpBadge(total: totalXp),
        ],
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final int total;
  const _XpBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final n = (total * t).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: JweTheme.amberSoft,
            border: Border.all(color: JweTheme.accentAmber.withOpacity(0.55)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL XP',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                '+$n',
                style: GoogleFonts.saira(
                  color: JweTheme.accentAmber,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final String? trailing;
  const _SectionLabel({required this.label, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        children: [
          Container(width: 3, height: 11, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: color.withOpacity(0.20))),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(
              trailing!,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillsBlock extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _SkillsBlock({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          label: 'ALLOCATIONS',
          color: JweTheme.accentCyan,
          trailing: '${entries.length} CH',
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          childAspectRatio: 1.1,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            return _SkillChip(name: e.key, xp: e.value)
                .animate(delay: (60 * i).ms)
                .fadeIn(duration: 260.ms)
                .slideY(begin: 0.2, end: 0);
          }),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String name;
  final int xp;
  const _SkillChip({required this.name, required this.xp});

  @override
  Widget build(BuildContext context) {
    final color = WellbeingTheme.getColor(name);
    return InkWell(
      onTap: () {
        final provider = Provider.of<AppProvider>(context, listen: false);
        try {
          final skill = provider.skills.firstWhere((s) => s.name == name);
          final xpToday = provider.get7DayWellbeingMomentum(skill.name) ~/ 7;
          final Map<int, double> weeklyXp = {};
          for (int i = 6; i >= 0; i--) {
            final date = DateTime.now().subtract(Duration(days: i));
            double dayXp = 0;
            for (var log in provider.reflectionLogs) {
              if (log.timestamp.year == date.year &&
                  log.timestamp.month == date.month &&
                  log.timestamp.day == date.day) {
                log.xpGained.forEach((k, v) {
                  if (WellbeingTheme.normalizeSkillName(k) == skill.name) {
                    dayXp += v.toDouble();
                  }
                });
              }
            }
            weeklyXp[6 - i] = dayXp;
          }
          showDialog(
            context: context,
            builder: (_) => WellbeingDetailDialog(
              skill: skill,
              xpGainedToday: xpToday,
              weeklyXp: weeklyXp,
            ),
          );
        } catch (_) {}
      },
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(WellbeingTheme.getIcon(name), color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                '+$xp',
                style: GoogleFonts.saira(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'XP',
                style: GoogleFonts.jetBrainsMono(
                  color: color.withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransmissionBlock extends StatelessWidget {
  final String text;
  const _TransmissionBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'TRANSMISSION', color: JweTheme.accentAmber),
        ClipPath(
          clipper: HudCutClipper(clip: HudClip.both, cut: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase.withOpacity(0.85),
              border:  Border(
                left: BorderSide(color: JweTheme.accentAmber, width: 2),
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: JweTheme.textWhite,
                fontSize: 13,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ],
    ).animate(delay: 160.ms).fadeIn(duration: 320.ms);
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onClose;
  const _Footer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: JweTheme.lineSoft)),
      ),
      child: InkWell(
        onTap: onClose,
        child: ClipPath(
          clipper: HudCutClipper(clip: HudClip.br, cut: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: JweTheme.amberSoft,
              border: Border.all(color: JweTheme.accentAmber.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.checkCircleOutline, size: 14, color: JweTheme.accentAmber),
                const SizedBox(width: 8),
                Text(
                  'ACKNOWLEDGE',
                  style: GoogleFonts.saira(
                    color: JweTheme.accentAmber,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
