import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StartDayContingencySection extends StatelessWidget {
  final String obstacle;
  final String ifThen;
  final String anticipate;

  const StartDayContingencySection({
    super.key,
    required this.obstacle,
    required this.ifThen,
    required this.anticipate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contingency: WOOP obstacle + if-then plan
        if (obstacle.isNotEmpty || ifThen.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentRed),
            const SizedBox(width: 8),
            Text(
              'CONTINGENCY PLAN',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentRed,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: JweTheme.bgDeep.withValues(alpha: 0.65),
              border: Border(left: BorderSide(color: JweTheme.accentRed, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (obstacle.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: JweTheme.accentRed.withValues(alpha: 0.10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(MdiIcons.alertOutline, size: 13, color: JweTheme.accentRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            obstacle,
                            style: GoogleFonts.inter(
                              color: JweTheme.textWhite,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (ifThen.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(MdiIcons.arrowRightBottom, size: 14, color: JweTheme.accentAmber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ifThen,
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Anticipatory savoring: one thing to look forward to
        if (anticipate.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentTeal),
            const SizedBox(width: 8),
            Text(
              'LOOK FORWARD TO',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentTeal,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.accentTeal.withValues(alpha: 0.05),
              border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MdiIcons.weatherSunny, size: 14, color: JweTheme.accentTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    anticipate,
                    style: GoogleFonts.inter(
                      color: JweTheme.textWhite,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
