import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD progress bar — segmented HUD-style with caption.
class JweProgressBar extends StatelessWidget {
  final double progress; // 0.0–1.0
  final Color color;
  final String? label;
  final int segments;
  final double height;

  const JweProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.label,
    this.segments = 22,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label!.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                )),
          ),
        SizedBox(
          height: height,
          child: Row(
            children: List.generate(segments, (i) {
              final on = i < (progress.clamp(0.0, 1.0) * segments).round();
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                  decoration: BoxDecoration(
                    color: on ? color : const Color(0x1AA8B3C7),
                    boxShadow: on ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 3)] : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Allow callers that previously relied on `HudProgressBar` look-alike.
  @visibleForTesting
  static Widget hud({required double value, required Color color}) {
    final tone = color == JweTheme.accentCyan
        ? HudTone.cyan
        : color == JweTheme.accentTeal
            ? HudTone.teal
            : color == JweTheme.accentRed
                ? HudTone.red
                : HudTone.amber;
    return HudProgressBar(value: value, tone: tone);
  }
}
