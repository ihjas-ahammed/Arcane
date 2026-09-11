import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class FinanceCatRow {
  final FinanceCategory cat;
  final double amount;
  final double pct;
  FinanceCatRow(this.cat, this.amount, this.pct);
}

String compactMoney(double v) {
  if (v >= 100000) return v.toStringAsFixed(0);
  if (v >= 1000) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String formatAbbreviatedMoney(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

class FinanceExpenditureBars extends StatelessWidget {
  final List<double> daily;
  const FinanceExpenditureBars({super.key, required this.daily});

  @override
  Widget build(BuildContext context) {
    final maxV = daily.isEmpty ? 0.0 : daily.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(daily.length, (i) {
        final isLast = i == daily.length - 1;
        final v = daily[i];
        final pct = maxV > 0 ? v / maxV : 0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == daily.length - 1 ? 0 : 2),
            child: FractionallySizedBox(
              heightFactor: math.max(0.03, pct.toDouble()),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: isLast
                      ? JweTheme.accentAmber
                      : JweTheme.accentAmber.withValues(alpha: 0.40),
                  boxShadow: isLast
                      ? [
                          BoxShadow(
                            color:
                                JweTheme.accentAmber.withValues(alpha: 0.5),
                            blurRadius: 5,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class FinanceLedgerActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const FinanceLedgerActionBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.saira(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  const FinanceResetBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.45)),
        ),
        child: Icon(MdiIcons.refresh, size: 16, color: JweTheme.accentRed),
      ),
    );
  }
}

class FinanceIncomeExpenseBar extends StatelessWidget {
  final double income;
  final double expense;

  const FinanceIncomeExpenseBar({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final total = income + expense;
    final incFrac = total > 0 ? (income / total).clamp(0.0, 1.0) : 0.5;
    final expFrac = 1.0 - incFrac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCOME VS EXPENSE · 30D',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: JweTheme.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 5,
                      width: w * incFrac,
                      color: JweTheme.accentTeal,
                    ),
                    Container(
                      height: 5,
                      width: w * expFrac,
                      color: JweTheme.accentRed.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(width: 8, height: 8, color: JweTheme.accentTeal),
                    const SizedBox(width: 4),
                    Text(
                      'IN ₹${formatAbbreviatedMoney(income)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(width: 8, height: 8, color: JweTheme.accentRed),
                    const SizedBox(width: 4),
                    Text(
                      'OUT ₹${formatAbbreviatedMoney(expense)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      income > expense
                          ? '+₹${formatAbbreviatedMoney(income - expense)}'
                          : '-₹${formatAbbreviatedMoney(expense - income)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: income >= expense
                            ? JweTheme.accentTeal
                            : JweTheme.accentRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class FinanceProjectedIncomeCard extends StatelessWidget {
  final double monthIncome;
  final double projectedIncome;
  final double monthExpense;
  final int daysElapsed;
  final int daysInMonth;
  final String currency;

  const FinanceProjectedIncomeCard({
    super.key,
    required this.monthIncome,
    required this.projectedIncome,
    required this.monthExpense,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final pct = daysElapsed / daysInMonth;
    final surplus = projectedIncome -
        monthExpense * (daysInMonth / daysElapsed.clamp(1, daysInMonth));
    final isPositive = surplus >= 0;

    return HudPanel(
      clip: HudClip.br,
      accent: JweTheme.accentTeal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(MdiIcons.trendingUp, size: 22, color: JweTheme.accentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROJECTED INCOME',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentTeal,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${formatAbbreviatedMoney(projectedIncome)}',
                      style: GoogleFonts.saira(
                        color: JweTheme.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'this month',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Actual so far: $currency${formatAbbreviatedMoney(monthIncome)} · Day $daysElapsed/$daysInMonth',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: GoogleFonts.saira(
                  color: JweTheme.accentTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'month',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isPositive
                    ? '+${formatAbbreviatedMoney(surplus.abs())}'
                    : '-${formatAbbreviatedMoney(surplus.abs())}',
                style: GoogleFonts.jetBrainsMono(
                  color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'net est.',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
