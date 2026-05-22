import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:missions/theme/valorant_theme.dart';
import 'package:missions/widgets/valorant_container.dart';

class LogbookScreen extends StatelessWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ValorantColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text("LOGBOOK // SYSTEM", style: ValorantTextStyles.header),
              Text("MATCH ANALYTICS & HISTORY",
                  style: ValorantTextStyles.label),
              const Gap(24),

              // Content Scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Top Row: Pie Chart & Stats
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildPieChartSection(),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 3,
                            child: _buildStatCard(
                                "K/D RATIO", "1.42", ValorantColors.teal),
                          ),
                        ],
                      ),
                      const Gap(24),

                      // Middle: Line Chart
                      _buildLineChartSection(),

                      const Gap(24),

                      // Bottom: Recent Entry List (Placeholder)
                      _buildRecentLogs(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    return ValorantContainer(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("AGENT PICK RATE", style: ValorantTextStyles.subHeader),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        color: ValorantColors.red,
                        value: 40,
                        title: '40%',
                        radius: 25,
                        titleStyle: ValorantTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        color: ValorantColors.teal,
                        value: 30,
                        title: '30%',
                        radius: 22,
                        titleStyle: ValorantTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        color: ValorantColors.white.withOpacity(0.2),
                        value: 30,
                        title: '30%',
                        radius: 18,
                        titleStyle: ValorantTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                // Inner label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("MAIN", style: ValorantTextStyles.label),
                    Text("BREACH",
                        style:
                            ValorantTextStyles.header.copyWith(fontSize: 24)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartSection() {
    return ValorantContainer(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("MMR HISTORY", style: ValorantTextStyles.subHeader),
              Text("+24RR LAST MATCH",
                  style: ValorantTextStyles.label
                      .copyWith(color: ValorantColors.teal)),
            ],
          ),
          const Gap(16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: ValorantColors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: ValorantColors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 3),
                      const FlSpot(1, 1),
                      const FlSpot(2, 4),
                      const FlSpot(3, 2),
                      const FlSpot(4, 5),
                      const FlSpot(5, 7),
                    ],
                    isCurved: true,
                    color: ValorantColors.red,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ValorantColors.red.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color accent) {
    return ValorantContainer(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: ValorantTextStyles.label),
          const Gap(8),
          Text(
            value,
            style: ValorantTextStyles.header.copyWith(
              fontSize: 48,
              color: accent,
            ),
          ).animate().fadeIn(duration: 800.ms).moveY(begin: 10, end: 0),
        ],
      ),
    );
  }

  Widget _buildRecentLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("RECENT LOGS", style: ValorantTextStyles.subHeader),
        const Gap(8),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              color: ValorantColors.white.withOpacity(0.03),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    color: i == 0 ? ValorantColors.teal : ValorantColors.red,
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i == 0 ? "VICTORY" : "DEFEAT",
                          style: ValorantTextStyles.subHeader
                              .copyWith(fontSize: 16)),
                      Text("Icebox â€¢ 13-9", style: ValorantTextStyles.label),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios,
                      color: ValorantColors.white, size: 14),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
