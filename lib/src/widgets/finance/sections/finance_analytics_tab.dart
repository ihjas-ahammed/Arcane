import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/finance/sections/linear_regression.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class FinanceAnalyticsTab extends StatelessWidget {
  final AppProvider provider;
  final Color accent;
  final String currency;

  const FinanceAnalyticsTab({
    super.key,
    required this.provider,
    required this.accent,
    this.currency = '₹',
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyAgo = today.subtract(const Duration(days: 29));
    final dailyInc = List<double>.filled(30, 0);
    final dailyExp = List<double>.filled(30, 0);

    for (var t in provider.transactions) {
      final ts = t.timestamp;
      if (ts.isBefore(thirtyAgo)) continue;
      final dayIdx =
          today.difference(DateTime(ts.year, ts.month, ts.day)).inDays;
      final i = 29 - dayIdx;
      if (i >= 0 && i < 30) {
        if (t.isIncome) {
          dailyInc[i] += t.amount;
        } else {
          dailyExp[i] += t.amount;
        }
      }
    }

    final regIncome = LinearRegression.calculate(dailyInc);
    final regExpense = LinearRegression.calculate(dailyExp);

    double maxVal = 100.0;
    for (int i = 0; i < 30; i++) {
      if (dailyInc[i] > maxVal) maxVal = dailyInc[i];
      if (dailyExp[i] > maxVal) maxVal = dailyExp[i];
    }
    for (int i = 29; i <= 36; i++) {
      final pi = regIncome.predict(i.toDouble());
      final pe = regExpense.predict(i.toDouble());
      if (pi > maxVal) maxVal = pi;
      if (pe > maxVal) maxVal = pe;
    }
    final maxYVal = maxVal * 1.15;

    final tomorrowIncome = regIncome.predict(30).clamp(0.0, double.infinity);
    final tomorrowExpense =
        regExpense.predict(30).clamp(0.0, double.infinity);

    // MTD category spend
    final monthStart = DateTime(now.year, now.month, 1);
    final catMTDSpend = <String, double>{};
    for (var t in provider.transactions) {
      if (t.isIncome) continue;
      if (t.timestamp.isBefore(monthStart)) continue;
      catMTDSpend[t.categoryId] = (catMTDSpend[t.categoryId] ?? 0) + t.amount;
    }
    final expenseCategories =
        provider.categories.where((c) => !c.isIncomeCategory).toList();
    double maxSpend = 100.0;
    for (final cat in expenseCategories) {
      final s = catMTDSpend[cat.id] ?? 0.0;
      if (s > maxSpend) maxSpend = s;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding =
        isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomPadding + 130.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'PREDICTIVE TREND ANALYSIS',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HudPanel(
            clip: HudClip.br,
            accent: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(width: 8, height: 8, color: JweTheme.accentCyan),
                    const SizedBox(width: 4),
                    Text(
                      'INCOME',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, color: JweTheme.accentRed),
                    const SizedBox(width: 4),
                    Text(
                      'EXPENSE',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 36,
                      minY: 0,
                      maxY: maxYVal,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: JweTheme.lineSoft.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: JweTheme.lineSoft.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) {
                                return Text(
                                  '30D AGO',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              if (value == 29) {
                                return Text(
                                  'TODAY',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              if (value == 36) {
                                return Text(
                                  '+7D PROJ',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.accentAmber,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            30,
                            (idx) => FlSpot(idx.toDouble(), dailyInc[idx]),
                          ),
                          color: JweTheme.accentCyan,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          barWidth: 2,
                        ),
                        LineChartBarData(
                          spots: List.generate(
                            8,
                            (idx) => FlSpot(
                              (29 + idx).toDouble(),
                              regIncome.predict((29 + idx).toDouble()),
                            ),
                          ),
                          color: JweTheme.accentCyan,
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                          barWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                        LineChartBarData(
                          spots: List.generate(
                            30,
                            (idx) => FlSpot(idx.toDouble(), dailyExp[idx]),
                          ),
                          color: JweTheme.accentRed,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          barWidth: 2,
                        ),
                        LineChartBarData(
                          spots: List.generate(
                            8,
                            (idx) => FlSpot(
                              (29 + idx).toDouble(),
                              regExpense.predict((29 + idx).toDouble()),
                            ),
                          ),
                          color: JweTheme.accentRed,
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                          barWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: JweTheme.lineSoft.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOMORROW EXPECTED INC',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 8,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$currency${tomorrowIncome.toStringAsFixed(2)}',
                            style: GoogleFonts.saira(
                              color: JweTheme.accentTeal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            regIncome.slope >= 0
                                ? 'TRENDING UP (+₹${regIncome.slope.toStringAsFixed(1)}/d)'
                                : 'TRENDING DOWN (-₹${regIncome.slope.abs().toStringAsFixed(1)}/d)',
                            style: GoogleFonts.jetBrainsMono(
                              color: regIncome.slope >= 0
                                  ? JweTheme.accentTeal
                                  : JweTheme.accentRed,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOMORROW EXPECTED EXP',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 8,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$currency${tomorrowExpense.toStringAsFixed(2)}',
                            style: GoogleFonts.saira(
                              color: JweTheme.accentRed,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            regExpense.slope >= 0
                                ? 'TRENDING UP (+₹${regExpense.slope.toStringAsFixed(1)}/d)'
                                : 'TRENDING DOWN (-₹${regExpense.slope.abs().toStringAsFixed(1)}/d)',
                            style: GoogleFonts.jetBrainsMono(
                              color: regExpense.slope >= 0
                                  ? JweTheme.accentRed
                                  : JweTheme.accentTeal,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'CATEGORY EXPENDITURE BREAKDOWN',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HudPanel(
            clip: HudClip.br,
            accent: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (expenseCategories.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'NO MTD EXPENSE DATA FOUND',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxSpend * 1.15,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final idx = value.toInt();
                                if (idx >= 0 &&
                                    idx < expenseCategories.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      expenseCategories[idx]
                                          .name
                                          .substring(
                                              0,
                                              math.min(
                                                  4,
                                                  expenseCategories[idx]
                                                      .name
                                                      .length))
                                          .toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 8,
                                        color: JweTheme.textMuted,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups:
                            List.generate(expenseCategories.length, (index) {
                          final cat = expenseCategories[index];
                          final spent = catMTDSpend[cat.id] ?? 0.0;
                          final color = Color(int.parse('0xFF${cat.colorHex}'));
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: spent,
                                color: color,
                                width: 16,
                                borderRadius: BorderRadius.zero,
                                backDrawRodData:
                                    BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxSpend * 1.15,
                                  color: JweTheme.bgBase,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...expenseCategories.map((cat) {
                    final spent = catMTDSpend[cat.id] ?? 0.0;
                    final color = Color(int.parse('0xFF${cat.colorHex}'));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, color: color),
                          const SizedBox(width: 8),
                          Text(
                            cat.name.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$currency${spent.toStringAsFixed(2)}',
                            style: GoogleFonts.jetBrainsMono(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
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
