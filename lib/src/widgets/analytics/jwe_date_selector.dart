import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class JweDateSelector extends StatelessWidget {
  final String dateStr;
  final VoidCallback onTap;

  const JweDateSelector({super.key, required this.dateStr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          border: Border.all(color: JweTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text(
                  "INSPECT DATE", 
                  style: TextStyle(
                    color: JweTheme.textMuted, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr, 
                  style: GoogleFonts.rajdhani(
                    letterSpacing: 1.0, 
                    fontSize: 20,
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: JweTheme.accentCyan, size: 24),
          ],
        ),
      ),
    );
  }
}