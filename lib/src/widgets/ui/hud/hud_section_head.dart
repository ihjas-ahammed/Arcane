import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'hud_types.dart';

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
    final c = hudToneFg(accent);
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
