import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'monthly_common_widgets.dart';

class MonthlyProtocolSection extends StatelessWidget {
  final String bestPossibleSelf;
  final List<dynamic> woop;
  final String lettingGo;

  const MonthlyProtocolSection({
    super.key,
    required this.bestPossibleSelf,
    required this.woop,
    required this.lettingGo,
  });

  @override
  Widget build(BuildContext context) {
    if (bestPossibleSelf.isEmpty && woop.isEmpty && lettingGo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'NEXT MONTH PROTOCOL', code: 'NXT', accent: HudTone.teal),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bestPossibleSelf.isNotEmpty) ...[
                  Row(children: [
                    Icon(MdiIcons.telescope, size: 14, color: JweTheme.accentTeal),
                    const SizedBox(width: 8),
                    Text(
                      'ONE MONTH FROM NOW',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentTeal,
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
                      color: JweTheme.accentTeal.withValues(alpha: 0.05),
                      border: Border(
                          left: BorderSide(
                              color: JweTheme.accentTeal, width: 2)),
                    ),
                    child: Text(
                      bestPossibleSelf,
                      style: TextStyle(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...woop.map((w) {
                  final m = w as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withValues(alpha: 0.5),
                      border: Border.all(
                          color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonthlyKVRow(label: 'WISH', text: m['wish']?.toString() ?? '', color: JweTheme.accentTeal),
                        MonthlyKVRow(label: 'OUTCOME', text: m['outcome']?.toString() ?? '', color: JweTheme.accentCyan),
                        MonthlyKVRow(label: 'OBSTACLE', text: m['obstacle']?.toString() ?? '', color: JweTheme.accentRed),
                        MonthlyKVRow(label: 'PLAN', text: m['plan']?.toString() ?? '', color: JweTheme.accentAmber),
                      ],
                    ),
                  );
                }),
                if (lettingGo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(MdiIcons.weightLifter, size: 14, color: JweTheme.accentRed),
                    const SizedBox(width: 8),
                    Text(
                      'DROP THE WEIGHT',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentRed,
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
                      color: JweTheme.accentRed.withValues(alpha: 0.05),
                      border: Border(
                          left: BorderSide(
                              color: JweTheme.accentRed, width: 2)),
                    ),
                    child: Text(
                      lettingGo,
                      style: TextStyle(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
