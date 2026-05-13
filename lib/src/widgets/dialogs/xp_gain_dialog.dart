import 'dart:ui';
import 'dart:math' as math;

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

/// "INSIGHT ACQUIRED" dialog shown after a reflection's AI analysis completes.
/// Renders over a blurred snapshot of whatever screen is behind it so the
/// home-screen context stays visible underneath.
class XpGainDialog extends StatefulWidget {
  final Map<String, int> xpGained;
  final String? insightText;

  const XpGainDialog({super.key, required this.xpGained, this.insightText});

  @override
  State<XpGainDialog> createState() => _XpGainDialogState();
}

class _XpGainDialogState extends State<XpGainDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _entry.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.xpGained.entries.where((e) => e.value > 0).toList();
    final totalXp = entries.fold<int>(0, (a, b) => a + b.value);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Animated blur backdrop over the home screen behind us.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (_, __) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18 * _entry.value,
                  sigmaY: 18 * _entry.value,
                ),
                child: Container(color: JweTheme.bgDeep.withOpacity(0.55 * _entry.value)),
              ),
            ),
          ),

          // Dismiss tap layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
          ),

          // Scanline sweep
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _scan,
                builder: (ctx, __) {
                  final h = MediaQuery.of(ctx).size.height;
                  return CustomPaint(
                    painter: _ScanlinePainter(progress: _scan.value, height: h),
                  );
                },
              ),
            ),
          ),

          // Main panel
          Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
                    child: FadeTransition(
                      opacity: _entry,
                      child: _InsightPanel(
                        entries: entries,
                        totalXp: totalXp,
                        insightText: widget.insightText,
                        onClose: () => Navigator.of(context).maybePop(),
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

class _InsightPanel extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int totalXp;
  final String? insightText;
  final VoidCallback onClose;

  const _InsightPanel({
    required this.entries,
    required this.totalXp,
    required this.insightText,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return HudPanel(
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
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entries.isNotEmpty) ...[
                    _SkillsBlock(entries: entries),
                    const SizedBox(height: 18),
                  ],
                  if (insightText != null && insightText!.isNotEmpty)
                    _TransmissionBlock(text: insightText!),
                ],
              ),
            ),
          ),
          _Footer(onClose: onClose),
        ],
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
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JweTheme.lineSoft)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFB547), Colors.transparent],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  '// SIGNAL DECODED',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 3),
                Text(
                  'INSIGHT ACQUIRED',
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
          _XpBadge(total: totalXp).animate(delay: 220.ms).fadeIn().scale(begin: const Offset(0.6, 0.6)),
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
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final n = (total * t).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  fontSize: 20,
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

class _SkillsBlock extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _SkillsBlock({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Row(
            children: [
              Container(width: 3, height: 11, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('ALLOCATIONS',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6,
                  )),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 1, color: JweTheme.line)),
              const SizedBox(width: 6),
              Text('${entries.length} CH',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9, letterSpacing: 1.2)),
            ],
          ),
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
                .animate(delay: (80 * i).ms)
                .fadeIn(duration: 320.ms)
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
                dayXp += (log.xpGained[skill.name] ?? 0).toDouble();
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
                  color: color, fontWeight: FontWeight.w800, fontSize: 13, height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'XP',
                style: GoogleFonts.jetBrainsMono(
                  color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1.2,
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              children: [
                Container(width: 3, height: 11, color: JweTheme.accentAmber),
                const SizedBox(width: 8),
                Text('TRANSMISSION',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6,
                    )),
                const SizedBox(width: 6),
                Expanded(child: Container(height: 1, color: JweTheme.lineAmber)),
                const SizedBox(width: 6),
                const HudDot(tone: HudTone.amber, size: 6),
              ],
            ),
          ),
          ClipPath(
            clipper: HudCutClipper(clip: HudClip.both, cut: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: JweTheme.bgBase.withOpacity(0.85),
                border: const Border(
                  left: BorderSide(color: JweTheme.accentAmber, width: 2),
                ),
              ),
              child: _Typewriter(
                text: text,
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
      ).animate(delay: 280.ms).fadeIn(duration: 420.ms),
    );
  }
}

class _Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _Typewriter({required this.text, required this.style});

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<int> _chars;

  @override
  void initState() {
    super.initState();
    final dur = (widget.text.length * 9).clamp(600, 3000);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: dur))..forward();
    _chars = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _chars,
      builder: (_, __) => Text(
        widget.text.substring(0, _chars.value),
        style: widget.style,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onClose;
  const _Footer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: JweTheme.lineSoft)),
      ),
      child: InkWell(
        onTap: onClose,
        child: ClipPath(
          clipper: HudCutClipper(clip: HudClip.br, cut: 10),
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
                Icon(MdiIcons.checkCircleOutline, size: 14, color: JweTheme.accentAmber),
                const SizedBox(width: 8),
                Text(
                  'ACKNOWLEDGE',
                  style: GoogleFonts.saira(
                    color: JweTheme.accentAmber,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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

class _ScanlinePainter extends CustomPainter {
  final double progress;
  final double height;
  _ScanlinePainter({required this.progress, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final y = (math.sin(progress * 2 * math.pi) * 0.5 + 0.5) * size.height;
    final rect = Rect.fromLTWH(0, y - 1, size.width, 2);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          JweTheme.accentAmber.withOpacity(0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => old.progress != progress;
}
