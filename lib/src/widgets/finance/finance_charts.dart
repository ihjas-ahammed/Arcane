import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/models/finance_models.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';

class FinanceCharts extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final List<FinanceCategory> categories;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const FinanceCharts({
    super.key,
    required this.transactions,
    required this.categories,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Daily Expense Pie
        JwePanel(
          title: "DAILY EXPENSES",
          accentColor: JweTheme.textMuted,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: JweTheme.accentCyan,
                            onPrimary: Colors.black,
                            surface: JweTheme.bgBase,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) onDateChanged(picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: JweTheme.border)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('MMM dd').format(selectedDate).toUpperCase(), style: const TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_drop_down, color: JweTheme.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 180, child: _buildPieChart()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 7 Day Line Chart
        JwePanel(
          title: "7-DAY TREND",
          accentColor: JweTheme.textMuted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(width: 8, height: 8, color: JweTheme.accentCyan), const SizedBox(width: 4), const Text("IN", style: TextStyle(color: JweTheme.textMuted, fontSize: 10)),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, color: JweTheme.accentRed), const SizedBox(width: 4), const Text("OUT", style: TextStyle(color: JweTheme.textMuted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(height: 180, child: _buildLineChart()),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPieChart() {
    Map<String, double> categoryTotals = {};
    for (var tx in transactions) {
      if (!tx.isIncome && 
          tx.timestamp.year == selectedDate.year && 
          tx.timestamp.month == selectedDate.month && 
          tx.timestamp.day == selectedDate.day) {
        categoryTotals[tx.categoryId] = (categoryTotals[tx.categoryId] ?? 0) + tx.amount;
      }
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text("NO EXPENSES TODAY", style: TextStyle(color: JweTheme.textMuted)));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: categoryTotals.entries.map((e) {
          final cat = categories.firstWhere((c) => c.id == e.key, orElse: () => FinanceCategory(id: '', name: 'Unknown', colorHex: 'FFFFFF', iconName: '', isIncomeCategory: false));
          return PieChartSectionData(
            color: Color(int.parse("0xFF${cat.colorHex}")),
            value: e.value,
            title: '₹${e.value.toInt()}',
            radius: 20,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      )
    );
  }

  Widget _buildLineChart() {
    final now = DateTime.now();
    final List<FlSpot> incSpots = [];
    final List<FlSpot> expSpots = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      double inc = 0, exp = 0;
      for (var tx in transactions) {
        if (tx.timestamp.year == date.year && tx.timestamp.month == date.month && tx.timestamp.day == date.day) {
          if (tx.isIncome) {
            inc += tx.amount;
          } else {
            exp += tx.amount;
          }
        }
      }
      incSpots.add(FlSpot((6 - i).toDouble(), inc));
      expSpots.add(FlSpot((6 - i).toDouble(), exp));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(color: JweTheme.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // Enforce 1 day intervals
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink(); // Safety check
                final date = now.subtract(Duration(days: 6 - value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('E').format(date).toUpperCase(), style: const TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                );
              }
            )
          )
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: incSpots, color: JweTheme.accentCyan, isCurved: true, dotData: const FlDotData(show: false), barWidth: 2, belowBarData: BarAreaData(show: true, color: JweTheme.accentCyan.withOpacity(0.1))
          ),
          LineChartBarData(
            spots: expSpots, color: JweTheme.accentRed, isCurved: true, dotData: const FlDotData(show: false), barWidth: 2, dashArray: [5, 5], belowBarData: BarAreaData(show: true, color: JweTheme.accentRed.withOpacity(0.1))
          )
        ]
      )
    );
  }
}