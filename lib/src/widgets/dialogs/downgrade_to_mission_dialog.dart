import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DowngradeToMissionDialog extends StatelessWidget {
  final String projectName;

  const DowngradeToMissionDialog({super.key, required this.projectName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: const BeveledRectangleBorder(side: BorderSide(color: Color(0xFF8A2BE2), width: 2)), // Purple
      title: Row(
        children: [
          Icon(MdiIcons.arrowCollapseDown, color: const Color(0xFF8A2BE2)),
          const SizedBox(width: 12),
          Text(
            "INITIATE DOWNGRADE", 
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0)
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You are about to transform Project '$projectName' back into a single Mission Protocol.",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(MdiIcons.history, "Total invested time will be consolidated into a single session log."),
          _buildFeatureItem(MdiIcons.fileTree, "Project steps will be converted to nested checkpoints."),
          _buildFeatureItem(MdiIcons.linkOff, "Existing step-links to other missions will be severed."),
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
          child: const Text("EXECUTE DOWNGRADE", style: TextStyle(fontWeight: FontWeight.bold)),
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