import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
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

  IconData _iconForAssetType(String type) {
    switch (type.toLowerCase()) {
      case 'skill':    return MdiIcons.lightningBolt;
      case 'person':   return MdiIcons.accountHeart;
      case 'object':   return MdiIcons.cubeOutline;
      case 'resource': return MdiIcons.bookOpenVariant;
      default:         return MdiIcons.starFourPoints;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary      = briefingData['summary']        as String?       ?? "No intel available.";
    final improvements = briefingData['improvements']   as List<dynamic>? ?? [];
    final gratefulPeople  = briefingData['grateful_people']  as List<dynamic>? ?? [];
    final gratefulAssets  = briefingData['grateful_assets']  as List<dynamic>? ?? [];

    return HudPanel(
      clip: HudClip.both,
      accent: JweTheme.accentAmber,
      allBrackets: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Panel header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: JweTheme.accentAmber.withValues(alpha: 0.22))),
            ),
            child: Row(children: [
              Container(width: 4, height: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 10),
              Expanded(
                child: Text('TACTICAL BRIEFING',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    )),
              ),
              if (!isSaved && onSave != null)
                InkWell(
                  onTap: onSave,
                  child: ClipPath(
                    clipper: HudCutClipper(clip: HudClip.br, cut: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: JweTheme.accentCyan.withValues(alpha: 0.10),
                        border: Border.all(
                            color: JweTheme.accentCyan.withValues(alpha: 0.45)),
                      ),
                      child: Text('SAVE TO LOG',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          )),
                    ),
                  ),
                )
              else if (isSaved)
                Icon(MdiIcons.checkBold, color: JweTheme.accentCyan, size: 16),
              const SizedBox(width: 6),
              HudDot(tone: HudTone.amber, size: 5),
            ]),
          ),

          // ── Content ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intel summary
                HudSectionHead(
                  label: 'INTEL SUMMARY',
                  accent: HudTone.amber,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                  ),
                ).animate().fadeIn(duration: 500.ms),

                // Ability improvements
                if (improvements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'ABILITY IMPROVEMENTS',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...improvements.map((imp) {
                    final m = imp as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.arrowUpBold,
                              size: 13, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['ability']}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: JweTheme.textWhite,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: m['insight'] ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Allies
                if (gratefulPeople.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'ALLIES DETECTED',
                    accent: HudTone.cyan,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...gratefulPeople.map((person) {
                    final p = person as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase,
                        border: Border(
                            left: BorderSide(
                                color: JweTheme.accentCyan, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name']?.toUpperCase() ?? 'UNKNOWN',
                            style: GoogleFonts.chakraPetch(
                                fontWeight: FontWeight.bold,
                                color: JweTheme.accentCyan,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(p['reason'] ?? '',
                              style: GoogleFonts.inter(
                                  color: JweTheme.textMid,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ).animate().slideX(begin: 0.08, end: 0).fadeIn();
                  }),
                ],

                // Assets
                if (gratefulAssets.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'ASSETS IDENTIFIED',
                    accent: HudTone.red,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...gratefulAssets.map((asset) {
                    final a = asset as Map<String, dynamic>;
                    final type = a['type']?.toString() ?? 'resource';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase,
                        border: Border(
                            left: BorderSide(
                                color: JweTheme.accentRed, width: 3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_iconForAssetType(type),
                              size: 15, color: JweTheme.accentRed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['name']?.toUpperCase() ?? 'UNKNOWN',
                                  style: GoogleFonts.chakraPetch(
                                      fontWeight: FontWeight.bold,
                                      color: JweTheme.accentRed,
                                      fontSize: 12),
                                ),
                                if ((a['why'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('WHY: ${a['why']}',
                                      style: GoogleFonts.inter(
                                          color: JweTheme.textMid,
                                          fontSize: 11,
                                          height: 1.4)),
                                ],
                                if ((a['what'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('WHAT: ${a['what']}',
                                      style: GoogleFonts.inter(
                                          color: JweTheme.textMid,
                                          fontSize: 11,
                                          height: 1.4)),
                                ],
                                if ((a['reason'] ?? '').toString().isNotEmpty &&
                                    (a['why'] ?? '').toString().isEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(a['reason'] ?? '',
                                      style: GoogleFonts.inter(
                                          color: JweTheme.textMid,
                                          fontSize: 12,
                                          height: 1.4)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideX(begin: 0.08, end: 0).fadeIn();
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
