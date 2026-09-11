import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'monthly_common_widgets.dart';

class MonthlyAarSection extends StatelessWidget {
  final List<dynamic> aar;

  const MonthlyAarSection({
    super.key,
    required this.aar,
  });

  @override
  Widget build(BuildContext context) {
    if (aar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'AFTER-ACTION REVIEW', code: 'AAR', accent: HudTone.red),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: aar.map((item) {
              final m = item as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase.withValues(alpha: 0.5),
                  border: Border(
                      left: BorderSide(color: JweTheme.accentRed, width: 3)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonthlyKVRow(label: 'INTENDED', text: m['intended']?.toString() ?? '', color: JweTheme.accentCyan),
                    MonthlyKVRow(label: 'ACTUAL', text: m['actual']?.toString() ?? '', color: JweTheme.accentAmber),
                    MonthlyKVRow(label: 'WHY GAP', text: m['gap_why']?.toString() ?? '', color: JweTheme.accentRed),
                    MonthlyKVRow(label: 'ADJUST', text: m['adjustment']?.toString() ?? '', color: JweTheme.accentTeal),
                  ],
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
