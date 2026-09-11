import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NfsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color neonColor;
  final VoidCallback onPressed;

  const NfsButton({
    super.key,
    required this.label,
    required this.icon,
    required this.neonColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-0.1745), // -10 deg skew
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: neonColor.withValues(alpha: 0.1),
            border: Border.all(color: neonColor, width: 2),
          ),
          child: Transform(
            transform: Matrix4.skewX(0.1745), // Counter skew text
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: neonColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    color: neonColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
