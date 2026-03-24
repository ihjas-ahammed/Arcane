import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
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

    return JwePanel(
      title: "TACTICAL BRIEFING",
      accentColor: JweTheme.accentAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Save Status Header Row inside the panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("INTEL SUMMARY", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              if (!isSaved && onSave != null)
                InkWell(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: JweTheme.accentCyan),
                      color: JweTheme.accentCyan.withOpacity(0.1)
                    ),
                    child: const Text("SAVE TO LOG", style: TextStyle(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (isSaved)
                 Icon(MdiIcons.checkBold, color: JweTheme.accentCyan, size: 18)
            ],
          ),
          const SizedBox(height: 12),
          
          Text(
            summary,
            style: const TextStyle(
              color: JweTheme.textWhite,
              height: 1.5,
              fontSize: 13,
              fontStyle: FontStyle.italic
            ),
          ).animate().fadeIn(duration: 500.ms),

          // Improvements Section
          if (improvements.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("ABILITY IMPROVEMENTS", JweTheme.accentAmber),
            const SizedBox(height: 8),
            ...improvements.map((imp) {
              final map = imp as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(MdiIcons.arrowUpBold, size: 14, color: JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${map['ability']}: ",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: JweTheme.textWhite, fontSize: 12)
                            ),
                            TextSpan(
                              text: map['insight'] ?? '',
                              style: const TextStyle(color: JweTheme.textMuted, fontSize: 12)
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
            _buildSectionHeader("ALLIES DETECTED", JweTheme.accentCyan),
            const SizedBox(height: 8),
            ...gratefulPeople.map((person) {
              final pMap = person as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase,
                  border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pMap['name']?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: JweTheme.accentCyan)),
                    const SizedBox(height: 4),
                    Text(pMap['reason'] ?? '', style: const TextStyle(color: JweTheme.textMuted, fontSize: 12, height: 1.4)),
                  ],
                ),
              ).animate().slideX(begin: 0.1, end: 0).fadeIn();
            }),
          ],

          // Grateful Assets
          if (gratefulAssets.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("ASSETS IDENTIFIED", JweTheme.accentRed),
            const SizedBox(height: 8),
            ...gratefulAssets.map((asset) {
              final aMap = asset as Map<String, dynamic>;
              final type = aMap['type']?.toString() ?? 'resource';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase,
                  border: Border(left: BorderSide(color: JweTheme.accentRed, width: 3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_getIconForAssetType(type), size: 16, color: JweTheme.accentRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(aMap['name']?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: JweTheme.accentRed)),
                          if ((aMap['why'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("WHY: ${aMap['why']}", style: const TextStyle(color: JweTheme.textMuted, fontSize: 11, height: 1.4)),
                          ],
                          if ((aMap['what'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text("WHAT: ${aMap['what']}", style: const TextStyle(color: JweTheme.textMuted, fontSize: 11, height: 1.4)),
                          ],
                          if ((aMap['reason'] ?? '').toString().isNotEmpty && (aMap['why'] ?? '').toString().isEmpty) ...[
                            const SizedBox(height: 4),
                            Text(aMap['reason'] ?? '', style: const TextStyle(color: JweTheme.textMuted, fontSize: 12, height: 1.4)),
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
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
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