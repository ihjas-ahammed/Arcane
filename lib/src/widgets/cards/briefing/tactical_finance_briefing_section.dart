import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TacticalFinanceBriefingSection extends StatelessWidget {
  final Map<String, dynamic>? financeBriefing;

  const TacticalFinanceBriefingSection({
    super.key,
    required this.financeBriefing,
  });

  @override
  Widget build(BuildContext context) {
    if (financeBriefing == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'DAILY FINANCE BRIEFING',
          accent: HudTone.amber,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.accentAmber.withValues(alpha: 0.05),
            border: Border.all(
              color: JweTheme.accentAmber.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'INFLOW',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${financeBriefing!['income'] ?? 0}',
                        style: GoogleFonts.chakraPetch(
                          color: JweTheme.accentTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: JweTheme.lineSoft),
                  Column(
                    children: [
                      Text(
                        'OUTFLOW',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${financeBriefing!['expense'] ?? 0}',
                        style: GoogleFonts.chakraPetch(
                          color: JweTheme.accentRed,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: JweTheme.lineSoft),
                  Column(
                    children: [
                      Text(
                        'NET',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${financeBriefing!['net'] ?? 0}',
                        style: GoogleFonts.chakraPetch(
                          color: JweTheme.accentAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if ((financeBriefing!['ai_feedback']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: JweTheme.lineSoft, height: 1),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(MdiIcons.finance, size: 13, color: JweTheme.accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        financeBriefing!['ai_feedback'].toString(),
                        style: GoogleFonts.inter(
                          color: JweTheme.textWhite,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}
