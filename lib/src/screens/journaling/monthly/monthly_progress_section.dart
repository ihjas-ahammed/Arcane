import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlyProgressSection extends StatelessWidget {
  final List<dynamic> progressReview;
  final String identityTrajectory;

  const MonthlyProgressSection({
    super.key,
    required this.progressReview,
    required this.identityTrajectory,
  });

  @override
  Widget build(BuildContext context) {
    if (progressReview.isEmpty && identityTrajectory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'COMPOUNDING PROGRESS', code: 'PRG', accent: HudTone.teal),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...progressReview.map((p) {
                  final m = p as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: JweTheme.accentTeal.withValues(alpha: 0.05),
                      border: Border.all(
                          color: JweTheme.accentTeal.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (m['area']?.toString() ?? '').toUpperCase(),
                          style: GoogleFonts.saira(
                            color: JweTheme.accentTeal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['small_wins']?.toString() ?? '',
                          style: TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 12,
                              height: 1.4),
                        ),
                        if ((m['compound_effect']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(MdiIcons.trendingUp,
                                  size: 12, color: JweTheme.accentTeal),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m['compound_effect']?.toString() ?? '',
                                  style: TextStyle(
                                      color: JweTheme.textMid,
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (identityTrajectory.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(MdiIcons.fingerprint, size: 14, color: JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text(
                      'IDENTITY TRAJECTORY',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withValues(alpha: 0.4),
                      border: Border(
                          left: BorderSide(
                              color: JweTheme.accentCyan, width: 2)),
                    ),
                    child: Text(
                      identityTrajectory,
                      style: TextStyle(
                          color: JweTheme.textWhite,
                          fontSize: 12.5,
                          height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
