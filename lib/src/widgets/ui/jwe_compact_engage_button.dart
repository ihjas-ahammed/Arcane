import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JweCompactEngageButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const JweCompactEngageButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isRunning ? JweTheme.accentRed : JweTheme.accentCyan;
    final String label = isRunning ? "HALT" : "ENGAGE";
    final IconData icon = isRunning ? MdiIcons.pause : MdiIcons.play;

    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 1.5),
          // JWE Theme uses sharp corners
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            )
          ],
        ),
      ),
    );
  }
}