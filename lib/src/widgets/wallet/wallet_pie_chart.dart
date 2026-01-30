import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/models/wallet_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class WalletPieChart extends StatefulWidget {
  final List<WalletTransaction> transactions;
  final bool showIncome;

  const WalletPieChart({super.key, required this.transactions, this.showIncome = false});

  @override
  State<WalletPieChart> createState() => _WalletPieChartState();
}

class _WalletPieChartState extends State<WalletPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final type = widget.showIncome ? TransactionType.income : TransactionType.expense;
    final filtered = widget.transactions.where((t) => t.type == type && !t.isFuture).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text("NO DATA", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay)),
      );
    }

    final Map<String, double> categoryTotals = {};
    for (var t in filtered) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final double total = categoryTotals.values.fold(0, (a, b) => a + b);
    final sortedEntries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Colors palette
    final List<Color> colors = [
      AppTheme.fhAccentTeal,
      AppTheme.fhAccentPurple,
      AppTheme.fhAccentOrange,
      AppTheme.fhAccentGold,
      AppTheme.fhAccentRed,
      Colors.blueAccent,
      Colors.pinkAccent,
    ];

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(sortedEntries.length, (i) {
                final isTouched = i == touchedIndex;
                final fontSize = isTouched ? 14.0 : 10.0;
                final radius = isTouched ? 50.0 : 40.0;
                final entry = sortedEntries[i];
                final percent = (entry.value / total * 100).toStringAsFixed(0);

                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: entry.value,
                  title: '$percent%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sortedEntries.length, (i) {
              if (i > 4) return const SizedBox.shrink(); // Limit legend
              final entry = sortedEntries[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: colors[i % colors.length]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        )
      ],
    );
  }
}