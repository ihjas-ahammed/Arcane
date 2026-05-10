import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class UpgradeToProjectDialog extends StatelessWidget {
  final String missionName;

  const UpgradeToProjectDialog({super.key, required this.missionName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: const BeveledRectangleBorder(side: BorderSide(color: Color(0xFF8A2BE2), width: 2)), // Purple for projects
      title: Row(
        children: [
          Icon(MdiIcons.rocketLaunch, color: const Color(0xFF8A2BE2)),
          const SizedBox(width: 12),
          Text(
            "INITIATE UPGRADE", 
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0)
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You are about to transform '$missionName' into a long-term Project Protocol.",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(MdiIcons.history, "Legacy time logs will be preserved in project velocity."),
          _buildFeatureItem(MdiIcons.fileTree, "All sub-routines will be converted to recursive project steps."),
          _buildFeatureItem(MdiIcons.deleteSweep, "Original mission entry will be purged after conversion."),
          const SizedBox(height: 16),
          const Text(
            "This operation cannot be reversed.",
            style: TextStyle(color: JweTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("ABORT", style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8A2BE2), 
            foregroundColor: Colors.white,
            shape: const BeveledRectangleBorder()
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("EXECUTE TRANSFORMATION", style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: JweTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: JweTheme.textMuted, fontSize: 12))),
        ],
      ),
    );
  }
}