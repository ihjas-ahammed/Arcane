import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD panel — cut-corner clip + amber/cyan corner brackets,
/// optional title bar with caption strip.
class JwePanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color accentColor;

  const JwePanel({
    super.key,
    this.title,
    required this.child,
    this.accentColor = JweTheme.accentAmber,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _matchTone(accentColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: HudPanel(
        clip: HudClip.br,
        accent: accentColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.20))),
                ),
                child: Row(children: [
                  Container(width: 4, height: 12, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  HudDot(tone: tone, size: 5),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  HudTone _matchTone(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }
}
