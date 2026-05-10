import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Operator HUD primitives — clip-corner panels, hairline brackets,
/// segmented bars, rings, sparklines, telemetry chips.
///
/// Use these in place of generic Material containers anywhere we want
/// the tactical HUD identity.

// ─────────────────────────────────────────────────────────────
// Typography helpers (use GoogleFonts so HUD identity is consistent
// regardless of bundled assets).
// ─────────────────────────────────────────────────────────────
class HudType {
  static TextStyle display({double size = 16, FontWeight weight = FontWeight.w700, Color color = JweTheme.textWhite, double letter = 0.4}) =>
      GoogleFonts.saira(fontSize: size, fontWeight: weight, color: color, letterSpacing: letter, height: 1.15);

  static TextStyle body({double size = 13, FontWeight weight = FontWeight.w400, Color color = JweTheme.textWhite, double letter = 0.05}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: letter, height: 1.4);

  static TextStyle mono({double size = 11, FontWeight weight = FontWeight.w500, Color color = JweTheme.textMid, double letter = 1.2}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: letter);

  static TextStyle cap({Color color = JweTheme.textMuted, double size = 10}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: FontWeight.w600, color: color, letterSpacing: 1.8);
}

// ─────────────────────────────────────────────────────────────
// Clip shape for cut-corner panels (Operator HUD signature).
// ─────────────────────────────────────────────────────────────
enum HudClip { none, br, tr, both }

class HudCutClipper extends CustomClipper<Path> {
  final HudClip clip;
  final double cut;
  HudCutClipper({this.clip = HudClip.br, this.cut = 12});

  @override
  Path getClip(Size s) {
    final p = Path();
    final c = math.min(cut, math.min(s.width, s.height) / 2);
    switch (clip) {
      case HudClip.none:
        p.addRect(Rect.fromLTWH(0, 0, s.width, s.height));
        break;
      case HudClip.br:
        p..moveTo(0, 0)
         ..lineTo(s.width, 0)
         ..lineTo(s.width, s.height - c)
         ..lineTo(s.width - c, s.height)
         ..lineTo(0, s.height)
         ..close();
        break;
      case HudClip.tr:
        p..moveTo(0, 0)
         ..lineTo(s.width - c, 0)
         ..lineTo(s.width, c)
         ..lineTo(s.width, s.height)
         ..lineTo(0, s.height)
         ..close();
        break;
      case HudClip.both:
        p..moveTo(0, 0)
         ..lineTo(s.width - c, 0)
         ..lineTo(s.width, c)
         ..lineTo(s.width, s.height - c)
         ..lineTo(s.width - c, s.height)
         ..lineTo(c, s.height)
         ..lineTo(0, s.height - c)
         ..close();
        break;
    }
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => true;
}

// ─────────────────────────────────────────────────────────────
// HudBrackets — corner brackets overlay
// ─────────────────────────────────────────────────────────────
class HudBrackets extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  final bool all;

  const HudBrackets({
    super.key,
    this.color = JweTheme.accentAmber,
    this.size = 10,
    this.thickness = 1,
    this.all = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        _corner(top: 0, left: 0, top1: true, left1: true),
        _corner(top: 0, right: 0, top1: true, right1: true, opacity: all ? 1.0 : 0.0),
        _corner(bottom: 0, left: 0, bottom1: true, left1: true, opacity: all ? 1.0 : 0.0),
        _corner(bottom: 0, right: 0, bottom1: true, right1: true),
      ]),
    );
  }

  Widget _corner({double? top, double? bottom, double? left, double? right,
      bool top1 = false, bool bottom1 = false, bool left1 = false, bool right1 = false,
      double opacity = 1.0}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(painter: _BracketPainter(
            color: color, thickness: thickness,
            top: top1, bottom: bottom1, left: left1, right: right1,
          )),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top, bottom, left, right;

  _BracketPainter({required this.color, required this.thickness,
      required this.top, required this.bottom, required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    if (top)    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
    if (bottom) canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
    if (left)   canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
    if (right)  canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// HudPanel — sharp cut-corner panel with optional brackets
// ─────────────────────────────────────────────────────────────
class HudPanel extends StatelessWidget {
  final Widget child;
  final HudClip clip;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool brackets;
  final bool allBrackets;
  final Color? background;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const HudPanel({
    super.key,
    required this.child,
    this.clip = HudClip.br,
    this.accent = JweTheme.accentAmber,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.brackets = true,
    this.allBrackets = false,
    this.background,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipPath(
      clipper: HudCutClipper(clip: clip),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        color: background ?? JweTheme.panel,
        padding: padding,
        child: child,
      ),
    );

    if (brackets) {
      content = Stack(children: [
        content,
        Positioned.fill(child: HudBrackets(color: accent, all: allBrackets)),
      ]);
    }

    final wrapped = Container(margin: margin, child: content);

    if (onTap == null) return wrapped;
    return InkWell(
      onTap: onTap,
      child: wrapped,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudChip — small caps pill with toned background
// ─────────────────────────────────────────────────────────────
enum HudTone { neutral, amber, cyan, teal, red }

Color _toneFg(HudTone t) {
  switch (t) {
    case HudTone.amber: return JweTheme.accentAmber;
    case HudTone.cyan: return JweTheme.accentCyan;
    case HudTone.teal: return JweTheme.accentTeal;
    case HudTone.red: return JweTheme.accentRed;
    case HudTone.neutral: return JweTheme.textMid;
  }
}

Color _toneBg(HudTone t) {
  switch (t) {
    case HudTone.amber: return JweTheme.amberSoft;
    case HudTone.cyan: return JweTheme.cyanSoft;
    case HudTone.teal: return const Color(0x1A4AF3C2);
    case HudTone.red: return const Color(0x1AFF5470);
    case HudTone.neutral: return const Color(0x1AA8B3C7);
  }
}

class HudChip extends StatelessWidget {
  final String label;
  final HudTone tone;
  final bool large;
  final IconData? icon;

  const HudChip({super.key, required this.label, this.tone = HudTone.neutral, this.large = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = _toneFg(tone);
    final bg = _toneBg(tone);
    return ClipPath(
      clipper: HudCutClipper(clip: HudClip.br, cut: 4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 9 : 7, vertical: large ? 5 : 3),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: fg.withOpacity(0.30), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: large ? 12 : 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: fg,
                fontSize: large ? 11 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudDot — pulsing status dot
// ─────────────────────────────────────────────────────────────
class HudDot extends StatefulWidget {
  final HudTone tone;
  final double size;
  final bool pulse;
  const HudDot({super.key, this.tone = HudTone.amber, this.size = 6, this.pulse = true});

  @override
  State<HudDot> createState() => _HudDotState();
}

class _HudDotState extends State<HudDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(widget.tone);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c, blurRadius: 8)],
      ),
    );
    if (!widget.pulse) return dot;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(opacity: 0.35 + 0.65 * (1 - _c.value), child: child),
      child: dot,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudBar — continuous bar with glow
// ─────────────────────────────────────────────────────────────
class HudBar extends StatelessWidget {
  final double value;
  final double max;
  final HudTone tone;
  final double height;

  const HudBar({super.key, required this.value, this.max = 100, this.tone = HudTone.amber, this.height = 4});

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(tone);
    final pct = (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      color: const Color(0x1AA8B3C7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            decoration: BoxDecoration(
              color: c,
              boxShadow: [BoxShadow(color: c.withOpacity(0.55), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudProgressBar — segmented HUD bar
// ─────────────────────────────────────────────────────────────
class HudProgressBar extends StatelessWidget {
  final double value; // 0-100
  final HudTone tone;
  final int segments;
  final double height;
  final bool showLabel;

  const HudProgressBar({
    super.key,
    required this.value,
    this.tone = HudTone.amber,
    this.segments = 24,
    this.height = 6,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(tone);
    final filled = (value / 100 * segments).round().clamp(0, segments);
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(segments, (i) {
              final on = i < filled;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                  decoration: BoxDecoration(
                    color: on ? c : const Color(0x1AA8B3C7),
                    boxShadow: on ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 3)] : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      if (showLabel) ...[
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text('${value.round()}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// HudRing — radial progress with optional center label
// ─────────────────────────────────────────────────────────────
class HudRing extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final double stroke;
  final HudTone tone;
  final String? label;
  final String? sub;

  const HudRing({
    super.key,
    required this.value,
    this.max = 100,
    this.size = 64,
    this.stroke = 5,
    this.tone = HudTone.amber,
    this.label,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(tone);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(size, size), painter: _RingPainter(value: value / max, color: c, stroke: stroke)),
        if (label != null || sub != null)
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (label != null)
              Text(label!,
                  style: GoogleFonts.saira(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w700,
                    color: c,
                    height: 1,
                  )),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, color: JweTheme.textMuted, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
            ],
          ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;

  _RingPainter({required this.value, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final track = Paint()..color = const Color(0x1AA8B3C7)..style = PaintingStyle.stroke..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(c, r, track);
    final sweep = (value.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

// ─────────────────────────────────────────────────────────────
// HudReticle — small target reticle decoration
// ─────────────────────────────────────────────────────────────
class HudReticle extends StatelessWidget {
  final double size;
  final Color color;
  const HudReticle({super.key, this.size = 20, this.color = JweTheme.accentAmber});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _ReticlePainter(color: color));
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3;
    final ring = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1;
    final dot = Paint()..color = color..style = PaintingStyle.fill;
    final tick = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), r, ring);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.1, dot);
    final t = size.width * 0.15;
    canvas.drawLine(Offset(cx, 0), Offset(cx, t), tick);
    canvas.drawLine(Offset(cx, size.height - t), Offset(cx, size.height), tick);
    canvas.drawLine(Offset(0, cy), Offset(t, cy), tick);
    canvas.drawLine(Offset(size.width - t, cy), Offset(size.width, cy), tick);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// HudSparkline
// ─────────────────────────────────────────────────────────────
class HudSparkline extends StatelessWidget {
  final List<double> data;
  final double width;
  final double height;
  final HudTone tone;

  const HudSparkline({super.key, required this.data, this.width = 72, this.height = 24, this.tone = HudTone.amber});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SparkPainter(data: data, color: _toneFg(tone)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round;
    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / range) * (size.height - 2) - 1;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// HudSectionHead — caption row with accent slab
// ─────────────────────────────────────────────────────────────
class HudSectionHead extends StatelessWidget {
  final String label;
  final String? code;
  final HudTone accent;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const HudSectionHead({
    super.key,
    required this.label,
    this.code,
    this.accent = HudTone.amber,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(accent);
    return Padding(
      padding: padding,
      child: Row(children: [
        Container(width: 4, height: 12, color: c),
        const SizedBox(width: 10),
        Text(label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: c, fontWeight: FontWeight.w600, letterSpacing: 1.8,
            )),
        const Spacer(),
        if (code != null)
          Text(code!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w500, letterSpacing: 1.4,
              )),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudHexTag — hex outline with tiny code inside
// ─────────────────────────────────────────────────────────────
class HudHexTag extends StatelessWidget {
  final String code;
  final HudTone tone;
  const HudHexTag({super.key, required this.code, this.tone = HudTone.amber});

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(tone);
    return SizedBox(
      width: 28, height: 32,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(28, 32), painter: _HexPainter(color: c)),
        Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 1)
      ..lineTo(w - 1, h * 0.25)
      ..lineTo(w - 1, h * 0.75)
      ..lineTo(w / 2, h - 1)
      ..lineTo(1, h * 0.75)
      ..lineTo(1, h * 0.25)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
// HudStat — label + big number + sub
// ─────────────────────────────────────────────────────────────
class HudStat extends StatelessWidget {
  final String? label;
  final String value;
  final String? unit;
  final String? sub;
  final HudTone tone;
  final double size;

  const HudStat({
    super.key,
    this.label,
    required this.value,
    this.unit,
    this.sub,
    this.tone = HudTone.amber,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final c = _toneFg(tone);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null)
        Text(label!.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.8)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: GoogleFonts.saira(fontSize: size, fontWeight: FontWeight.w700, color: c, height: 1)),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(unit!, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: JweTheme.textMuted)),
        ],
      ]),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.0)),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// HudDataRow — label / value row
// ─────────────────────────────────────────────────────────────
class HudDataRow extends StatelessWidget {
  final String label;
  final String value;
  final HudTone? tone;
  final bool accent;

  const HudDataRow({super.key, required this.label, required this.value, this.tone, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final c = accent ? JweTheme.accentAmber : (tone == null ? JweTheme.textWhite : _toneFg(tone!));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.8))),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: c, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HudDottedDivider
// ─────────────────────────────────────────────────────────────
class HudDottedDivider extends StatelessWidget {
  final Color color;
  final double height;
  const HudDottedDivider({super.key, this.color = JweTheme.lineAmber, this.height = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _DottedPainter(color: color), size: Size.fromHeight(height)),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 3, size.height / 2), p);
      x += 6;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
