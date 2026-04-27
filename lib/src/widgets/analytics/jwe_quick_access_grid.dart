import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class JweQuickAccessGrid extends StatelessWidget {
  final VoidCallback onArchive;
  final VoidCallback onNora;
  final VoidCallback onAdvanced;

  const JweQuickAccessGrid({
    super.key,
    required this.onArchive,
    required this.onNora,
    required this.onAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "CLASSIFIED ACCESS",
          style: TextStyle(
            color: JweTheme.textMuted,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            fontSize: 12
          )
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGridButton(
                title: "ARCHIVE",
                icon: MdiIcons.lockOutline,
                color: JweTheme.accentCyan,
                onTap: onArchive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGridButton(
                title: "NORA AI",
                icon: MdiIcons.brain,
                color: const Color(0xFF8A2BE2), // Purple
                onTap: onNora,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGridButton(
                title: "ADVANCED",
                icon: MdiIcons.hexagonMultipleOutline,
                color: const Color(0xFF8A2BE2), // Purple
                onTap: onAdvanced,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.rajdhani(
                color: JweTheme.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}