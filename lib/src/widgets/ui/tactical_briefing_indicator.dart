import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

enum BriefingType {
  daily,
  startup,
  weekly,
  monthly,
}

extension BriefingTypeExt on BriefingType {
  String get label {
    switch (this) {
      case BriefingType.daily:
        return 'TACTICAL BRIEFING PROTOCOL';
      case BriefingType.startup:
        return 'SYSTEM STARTUP SEQUENCE';
      case BriefingType.weekly:
        return '7-DAY PERFORMANCE REVIEW';
      case BriefingType.monthly:
        return 'MONTHLY INTEL BRIEFING';
    }
  }

  String get code {
    switch (this) {
      case BriefingType.daily:
        return 'AI-DAILY';
      case BriefingType.startup:
        return 'STARTUP';
      case BriefingType.weekly:
        return '7-DAY';
      case BriefingType.monthly:
        return 'MONTHLY';
    }
  }

  Duration get proTimeout {
    switch (this) {
      case BriefingType.daily:
      case BriefingType.startup:
        return const Duration(seconds: 30);
      case BriefingType.weekly:
        return const Duration(minutes: 1);
      case BriefingType.monthly:
        return const Duration(minutes: 2);
    }
  }

  Color get accent {
    switch (this) {
      case BriefingType.daily:
        return JweTheme.accentAmber;
      case BriefingType.startup:
        return JweTheme.accentCyan;
      case BriefingType.weekly:
        return JweTheme.accentAmber;
      case BriefingType.monthly:
        return JweTheme.accentTeal;
    }
  }
}

/// Advanced Cyber-Tactical Loading & Telemetry Indicator for AI Briefings & Reviews.
class TacticalBriefingIndicator extends StatefulWidget {
  final BriefingType type;
  final String? statusMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final bool compact;

  const TacticalBriefingIndicator({
    super.key,
    required this.type,
    this.statusMessage,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
    this.compact = false,
  });

  @override
  State<TacticalBriefingIndicator> createState() => _TacticalBriefingIndicatorState();
}

class _TacticalBriefingIndicatorState extends State<TacticalBriefingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  Timer? _timer;
  int _elapsedMilliseconds = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (mounted && widget.errorMessage == null) {
        setState(() {
          _elapsedMilliseconds += 100;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed(int ms) {
    final s = ms ~/ 1000;
    final frac = (ms % 1000) ~/ 100;
    return '${s.toString().padLeft(2, '0')}.${frac}s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.errorMessage != null ? JweTheme.accentRed : widget.type.accent;
    final totalTimeoutSec = widget.type.proTimeout.inSeconds;
    final isLiteFallback = widget.statusMessage != null &&
        (widget.statusMessage!.contains('LITE MODEL') ||
            widget.statusMessage!.contains('TIMEOUT') ||
            widget.statusMessage!.contains('RETRYING'));

    final progressRatio = (_elapsedMilliseconds / (widget.type.proTimeout.inMilliseconds * 1.5))
        .clamp(0.05, 0.95);

    return ClipPath(
      clipper: HudCutClipper(clip: HudClip.br, cut: widget.compact ? 8 : 12),
      child: Container(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          border: Border.all(
            color: accent.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: HudBrackets(all: true, size: 8),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Protocol Header
                Row(
                  children: [
                    Container(width: 4, height: 14, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.type.label,
                        style: GoogleFonts.jetBrainsMono(
                          color: accent,
                          fontSize: widget.compact ? 10 : 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    if (widget.errorMessage == null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Text(
                          '${_formatElapsed(_elapsedMilliseconds)} / ${totalTimeoutSec}s',
                          style: GoogleFonts.jetBrainsMono(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Error View or Active Synthesis View
                if (widget.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withValues(alpha: 0.10),
                      border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(MdiIcons.alertDecagramOutline, size: 16, color: JweTheme.accentRed),
                            const SizedBox(width: 8),
                            Text(
                              'TELEMETRY SYNTHESIS ERROR',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.errorMessage!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.onRetry != null)
                    InkWell(
                      onTap: widget.onRetry,
                      child: ClipPath(
                        clipper: HudCutClipper(clip: HudClip.br, cut: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: JweTheme.accentRed.withValues(alpha: 0.18),
                            border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(MdiIcons.refresh, size: 14, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'RETRY GENERATION PROTOCOL',
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ] else ...[
                  // Radar & Live Telemetry Feed
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Rotating Tactical Radar Reticle
                      AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (ctx, child) {
                          return Transform.rotate(
                            angle: _animCtrl.value * 2 * math.pi,
                            child: SizedBox(
                              width: widget.compact ? 36 : 46,
                              height: widget.compact ? 36 : 46,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: Size(widget.compact ? 36 : 46, widget.compact ? 36 : 46),
                                    painter: _TacticalRadarPainter(
                                      color: isLiteFallback ? JweTheme.accentAmber : accent,
                                    ),
                                  ),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isLiteFallback ? JweTheme.accentAmber : accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),

                      // Status Details & Engine Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Engine Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isLiteFallback ? JweTheme.accentAmber : accent)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (isLiteFallback ? JweTheme.accentAmber : accent)
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLiteFallback ? MdiIcons.lightningBolt : MdiIcons.chip,
                                    size: 11,
                                    color: isLiteFallback ? JweTheme.accentAmber : accent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isLiteFallback
                                        ? 'LITE MODEL FALLBACK ACTIVE'
                                        : 'PRO-TIER ENGINE (MAX INTEL)',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: isLiteFallback ? JweTheme.accentAmber : accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Dynamic Status Message
                            Text(
                              widget.statusMessage ??
                                  (isLiteFallback
                                      ? 'Pro model timed out. Synthesizing with Lite model...'
                                      : 'Aggregating reflections, sessions & metrics...'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                color: isLiteFallback ? Colors.amber.shade200 : JweTheme.textWhite,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Segmented Scanning Progress Bar
                  AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (ctx, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(
                              height: 4,
                              color: accent.withValues(alpha: 0.15),
                            ),
                            FractionallySizedBox(
                              widthFactor: progressRatio,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      (isLiteFallback ? JweTheme.accentAmber : accent)
                                          .withValues(alpha: 0.3),
                                      isLiteFallback ? JweTheme.accentAmber : accent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TacticalRadarPainter extends CustomPainter {
  final Color color;

  _TacticalRadarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer & inner ring
    canvas.drawCircle(center, radius - 2, ringPaint);
    canvas.drawCircle(center, radius * 0.5, ringPaint);

    // Crosshairs
    canvas.drawLine(Offset(center.dx, 2), Offset(center.dx, size.height - 2), crossPaint);
    canvas.drawLine(Offset(2, center.dy), Offset(size.width - 2, center.dy), crossPaint);

    // Sweep cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.35),
        ],
        stops: const [0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 2, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalRadarPainter oldDelegate) =>
      oldDelegate.color != color;
}
