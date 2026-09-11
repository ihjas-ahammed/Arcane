import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class RunningTaskActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final Color accent;
  final double? width;
  final VoidCallback? onPressed;

  const RunningTaskActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.accent,
    this.width,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? accent : accent.withValues(alpha: JweTheme.isLight ? 0.08 : 0.12);
    final fg = primary ? JweTheme.onAccent : accent;
    final border = Border.all(color: accent, width: 1.2);

    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
