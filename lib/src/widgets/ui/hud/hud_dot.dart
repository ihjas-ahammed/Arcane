import 'package:flutter/material.dart';
import 'hud_types.dart';

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
    final c = hudToneFg(widget.tone);
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
