import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlyFinanceCard extends StatelessWidget {
  final Map<String, dynamic>? savedFinance;

  const MonthlyFinanceCard({
    super.key,
    required this.savedFinance,
  });

  @override
  Widget build(BuildContext context) {
    final finance = savedFinance;
    if (finance == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'MONTHLY FINANCE BRIEFING', code: 'FIN', accent: HudTone.amber),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('INFLOW', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text('₹${(finance['income'] as num?)?.toStringAsFixed(0) ?? 0}',
                        style: GoogleFonts.chakraPetch(
                            color: JweTheme.accentTeal, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 1, height: 28, color: JweTheme.lineSoft),
                Column(
                  children: [
                    Text('OUTFLOW', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text('₹${(finance['expense'] as num?)?.toStringAsFixed(0) ?? 0}',
                        style: GoogleFonts.chakraPetch(
                            color: JweTheme.accentRed, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 1, height: 28, color: JweTheme.lineSoft),
                Column(
                  children: [
                    Text('NET', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text('₹${(finance['net'] as num?)?.toStringAsFixed(0) ?? 0}',
                        style: GoogleFonts.chakraPetch(
                            color: JweTheme.accentAmber, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),
        ),
      ],
    );
  }
}
