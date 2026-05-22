import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/widgets/health/spidey_panel.dart';
import 'package:missions/src/widgets/health/health_combined_chart.dart';
import 'package:missions/src/widgets/health/sleep_panel.dart';
import 'package:missions/src/widgets/health/activity_panel.dart';
import 'package:missions/src/widgets/health/energy_panel.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class HealthDashboardView extends StatefulWidget {
  const HealthDashboardView({super.key});

  @override
  State<HealthDashboardView> createState() => _HealthDashboardViewState();
}

class _HealthDashboardViewState extends State<HealthDashboardView> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final log = provider.getDailyHealthLog(dateStr);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date Selector
          Container(
            decoration: BoxDecoration(
              color: SpideyTheme.bgPanel,
              border: Border.all(color: SpideyTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 4, height: 32, color: SpideyTheme.spideyRed),
                IconButton(
                    icon: const Icon(Icons.chevron_left, color: SpideyTheme.spideyCyan),
                    onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)))),
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate).toUpperCase(),
                  style: GoogleFonts.rajdhani(
                      color: SpideyTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.8),
                ),
                IconButton(
                    icon: const Icon(Icons.chevron_right, color: SpideyTheme.spideyCyan),
                    onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)))),
                Container(width: 4, height: 32, color: SpideyTheme.spideyRed),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7-day Trend
          SpideyPanel(
            title: "TREND ANALYSIS (7-DAY)",
            accentColor: SpideyTheme.spideyCyan,
            child: SizedBox(
              height: 200,
              child: HealthCombinedChart(provider: provider),
            ),
          ),

          // Energy 24h
          EnergyPanel(dateStr: dateStr),

          // Hydration
          SpideyPanel(
            title: "HYDRATION",
            accentColor: SpideyTheme.spideyCyan,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.remove, color: SpideyTheme.textGrey),
                        onPressed: () => provider.updateWater(dateStr, (log.waterGlasses - 1).clamp(0, 99))),
                    Text("${log.waterGlasses}",
                        style: GoogleFonts.rajdhani(
                            fontSize: 32, fontWeight: FontWeight.bold, color: SpideyTheme.textWhite)),
                    IconButton(
                        icon: const Icon(Icons.add, color: SpideyTheme.spideyCyan),
                        onPressed: () => provider.updateWater(dateStr, log.waterGlasses + 1)),
                  ],
                ),
                const Text("GLASSES",
                    style: TextStyle(
                        fontSize: 10,
                        color: SpideyTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ],
            ),
          ),

          // Sleep
          SleepPanel(dateStr: dateStr),

          // Activity
          ActivityPanel(dateStr: dateStr),
        ],
      ),
    );
  }
}
