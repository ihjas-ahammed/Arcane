import 'package:flutter/material.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PersonDossierSection extends StatelessWidget {
  final String profile;
  final List<dynamic> interactionHistory;
  final List<dynamic> communicationTips;

  const PersonDossierSection({
    super.key,
    required this.profile,
    required this.interactionHistory,
    required this.communicationTips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Dossier"),
        
        _buildSubHeader("PSYCHOLOGICAL PROFILE"),
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Text(
            profile,
            textAlign: TextAlign.justify,
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.textWhite.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),

        if (interactionHistory.isNotEmpty) ...[
          _buildSubHeader("INTERACTION HISTORY"),
          _buildList(interactionHistory),
          const SizedBox(height: 10),
        ],

        if (communicationTips.isNotEmpty) ...[
          _buildSubHeader("COMMUNICATION TIPS"),
          _buildList(communicationTips),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 15.0),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.spideyCyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [PersonInfoTheme.spideyCyanDim, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 15, bottom: 10), // Adjust top margin slightly from CSS 25px for flutter flow
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: PersonInfoTheme.spideyRed, width: 3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.rajdhani(
          color: PersonInfoTheme.textGrey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          String highlight = item['highlight'] ?? '';
          String text = item['text'] ?? '';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ">",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.spideyCyanDim,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      children: [
                        if (highlight.isNotEmpty)
                          TextSpan(
                            text: "$highlight ",
                            style: const TextStyle(
                              color: PersonInfoTheme.spideyCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}