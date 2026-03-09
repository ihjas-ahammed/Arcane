import 'package:flutter/material.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AssetInfoDialog extends StatelessWidget {
  final GratitudeItem item;

  const AssetInfoDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PersonInfoTheme.bgPanel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: PersonInfoTheme.spideyCyan, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name.toUpperCase(),
              style: GoogleFonts.rajdhani(
                color: PersonInfoTheme.spideyCyan,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0
              ),
            ),
            Text(
              "TYPE: ${item.type.toUpperCase()}",
              style: GoogleFonts.rajdhani(
                color: PersonInfoTheme.spideyCyanDim,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            if (item.why.isNotEmpty) _buildSection("STRATEGIC VALUE (WHY)", item.why),
            if (item.how.isNotEmpty) _buildSection("USAGE METHOD (HOW)", item.how),
            if (item.what.isNotEmpty) _buildSection("EXPECTED YIELD (WHAT)", item.what),
            
            if (item.why.isEmpty && item.how.isEmpty && item.what.isEmpty)
              const Text("No detailed intelligence available for this asset.", style: TextStyle(color: PersonInfoTheme.textGrey, fontStyle: FontStyle.italic)),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PersonInfoTheme.textGrey,
                  side: const BorderSide(color: Color(0xFF1f2f40)),
                  shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE DATA"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: PersonInfoTheme.spideyRed, width: 2))),
            child: Text(
              title,
              style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
            ),
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}