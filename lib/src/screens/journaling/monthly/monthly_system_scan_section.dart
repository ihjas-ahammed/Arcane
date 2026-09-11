import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlySystemScanSection extends StatelessWidget {
  final List<dynamic> wellbeingDeltas;
  final List<dynamic> lifeDomains;

  const MonthlySystemScanSection({
    super.key,
    required this.wellbeingDeltas,
    required this.lifeDomains,
  });

  @override
  Widget build(BuildContext context) {
    if (wellbeingDeltas.isEmpty && lifeDomains.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'SYSTEM SCAN', code: 'SCN', accent: HudTone.cyan),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wellbeingDeltas.isNotEmpty) ...[
                  ...wellbeingDeltas.map((d) {
                    final m = d as Map<String, dynamic>;
                    final direction = (m['direction']?.toString() ?? 'flat').toLowerCase();
                    final isUp = direction == 'up';
                    final isDown = direction == 'down';
                    final color = isUp
                        ? JweTheme.accentTeal
                        : (isDown ? JweTheme.accentRed : JweTheme.textMuted);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isUp
                                ? MdiIcons.arrowUpBold
                                : (isDown
                                    ? MdiIcons.arrowDownBold
                                    : MdiIcons.minus),
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['area'] ?? ''}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextSpan(
                                  text: m['hypothesis']?.toString() ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 12.5,
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
                if (lifeDomains.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(MdiIcons.chartDonut, size: 14, color: JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text(
                      'LIFE DOMAIN BALANCE',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...lifeDomains.map((d) {
                    final m = d as Map<String, dynamic>;
                    final rating = (m['rating'] as num?)?.toInt() ?? 0;
                    final low = rating <= 4;
                    final barColor = low
                        ? JweTheme.accentRed
                        : (rating >= 7
                            ? JweTheme.accentTeal
                            : JweTheme.accentAmber);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                (m['domain']?.toString() ?? '').toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textWhite,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                '$rating/10',
                                style: GoogleFonts.chakraPetch(
                                  color: barColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (rating.clamp(0, 10)) / 10.0,
                              minHeight: 4,
                              backgroundColor:
                                  JweTheme.bgDeep.withValues(alpha: 0.6),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                          if ((m['evidence']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              m['evidence']?.toString() ?? '',
                              style: TextStyle(
                                  color: JweTheme.textMuted,
                                  fontSize: 10.5,
                                  height: 1.35),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
