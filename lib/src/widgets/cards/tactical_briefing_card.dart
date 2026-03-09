import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class TacticalBriefingCard extends StatelessWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onSave;
  final bool isSaved;

  const TacticalBriefingCard({
    super.key,
    required this.briefingData,
    this.onSave,
    this.isSaved = false,
  });

  IconData _getIconForAssetType(String type) {
    switch(type.toLowerCase()) {
      case 'skill': return MdiIcons.lightningBolt;
      case 'person': return MdiIcons.accountHeart;
      case 'object': return MdiIcons.cubeOutline;
      case 'resource': return MdiIcons.bookOpenVariant;
      default: return MdiIcons.starFourPoints;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = briefingData['summary'] as String? ?? "No intel available.";
    final improvements = briefingData['improvements'] as List<dynamic>? ?? [];
    final gratefulPeople = briefingData['grateful_people'] as List<dynamic>? ?? [];
    final gratefulAssets = briefingData['grateful_assets'] as List<dynamic>? ?? [];

    return ValorantCard(
      borderColor: AppTheme.fhAccentGold.withValues(alpha: 0.6),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.fhAccentGold.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: AppTheme.fhAccentGold.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.clipboardTextOutline, color: AppTheme.fhAccentGold, size: 20),
                    const SizedBox(width: 8),
                    const Text("TACTICAL BRIEFING", style: TextStyle(
                      fontFamily: AppTheme.fontDisplay, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 16,
                      color: AppTheme.fhTextPrimary
                    )),
                  ],
                ),
                if (!isSaved && onSave != null)
                  InkWell(
                    onTap: onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.fhAccentTeal),
                        color: AppTheme.fhAccentTeal.withValues(alpha: 0.1)
                      ),
                      child: const Text("SAVE TO LOG", style: TextStyle(color: AppTheme.fhAccentTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                else if (isSaved)
                   Icon(MdiIcons.checkBold, color: AppTheme.fhAccentTeal, size: 18)
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Text
                Text(
                  summary,
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    height: 1.5,
                    fontSize: 13,
                    fontStyle: FontStyle.italic
                  ),
                ).animate().fadeIn(duration: 500.ms),

                // Improvements Section
                if (improvements.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    "ABILITY IMPROVEMENTS",
                    style: TextStyle(
                      color: AppTheme.fhAccentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...improvements.map((imp) {
                    final map = imp as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.arrowUpBold, size: 14, color: AppTheme.fhAccentGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${map['ability']}: ",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary, fontSize: 12)
                                  ),
                                  TextSpan(
                                    text: map['insight'] ?? '',
                                    style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)
                                  )
                                ]
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Grateful People
                if (gratefulPeople.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSpideyHeader("ALLIES DETECTED", const Color(0xFF00f0ff)),
                  const SizedBox(height: 8),
                  ...gratefulPeople.map((person) {
                    final pMap = person as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1623), // Dark spidey panel
                        border: Border(left: BorderSide(color: const Color(0xFF00f0ff), width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pMap['name']?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: const Color(0xFF00f0ff))),
                          const SizedBox(height: 4),
                          Text(pMap['reason'] ?? '', style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ).animate().slideX(begin: 0.1, end: 0).fadeIn();
                  }),
                ],

                // Grateful Assets
                if (gratefulAssets.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSpideyHeader("ASSETS IDENTIFIED", const Color(0xFFd02b3e)),
                  const SizedBox(height: 8),
                  ...gratefulAssets.map((asset) {
                    final aMap = asset as Map<String, dynamic>;
                    final type = aMap['type']?.toString() ?? 'resource';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1623), // Dark spidey panel
                        border: Border(left: BorderSide(color: const Color(0xFFd02b3e), width: 3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_getIconForAssetType(type), size: 16, color: const Color(0xFFd02b3e)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(aMap['name']?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: const Color(0xFFd02b3e))),
                                if ((aMap['why'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text("WHY: ${aMap['why']}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, height: 1.4)),
                                ],
                                if ((aMap['what'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text("WHAT: ${aMap['what']}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, height: 1.4)),
                                ],
                                // Fallback reason if why/what aren't present
                                if ((aMap['reason'] ?? '').toString().isNotEmpty && (aMap['why'] ?? '').toString().isEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(aMap['reason'] ?? '', style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, height: 1.4)),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideX(begin: 0.1, end: 0).fadeIn();
                  }),
                ],

              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSpideyHeader(String title, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.rajdhani(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.5), Colors.transparent],
                begin: Alignment.centerLeft, end: Alignment.centerRight
              )
            ),
          ),
        )
      ],
    );
  }
}