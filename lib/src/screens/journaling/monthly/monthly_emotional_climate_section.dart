import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlyEmotionalClimateSection extends StatelessWidget {
  final List<String> dominantEmotions;
  final String trajectory;
  final List<dynamic> patterns;

  const MonthlyEmotionalClimateSection({
    super.key,
    required this.dominantEmotions,
    required this.trajectory,
    required this.patterns,
  });

  @override
  Widget build(BuildContext context) {
    if (dominantEmotions.isEmpty && trajectory.isEmpty && patterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'EMOTIONAL CLIMATE', code: 'EMO', accent: HudTone.amber),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dominantEmotions.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dominantEmotions
                        .map((e) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: JweTheme.accentAmber.withValues(alpha: 0.10),
                                border: Border.all(
                                    color: JweTheme.accentAmber
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                e.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.accentAmber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                if (trajectory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(MdiIcons.chartTimelineVariant,
                          size: 14, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trajectory,
                          style: TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
                if (patterns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...patterns.map((p) {
                    final m = p as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: JweTheme.bgDeep.withValues(alpha: 0.5),
                        border: Border(
                            left: BorderSide(
                                color: JweTheme.accentAmber, width: 2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['pattern']?.toString() ?? '',
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if ((m['evidence']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              m['evidence']?.toString() ?? '',
                              style: TextStyle(
                                  color: JweTheme.textMid,
                                  fontSize: 11.5,
                                  height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
