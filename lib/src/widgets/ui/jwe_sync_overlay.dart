import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class JweSyncOverlay extends StatelessWidget {
  const JweSyncOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: JweTheme.bgBase.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: JweTheme.panel,
              border: Border.all(color: JweTheme.accentCyan, width: 2),
              boxShadow: [
                BoxShadow(color: JweTheme.accentCyan.withValues(alpha: 0.15), blurRadius: 30)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(
                    color: JweTheme.accentCyan,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "SYNCHRONIZING DATABANKS",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.accentCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Uplink in progress. Validating local cache and remote server parity.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: JweTheme.textMuted,
                    fontSize: 11,
                    fontFamily: 'RobotoMono',
                    height: 1.4,
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