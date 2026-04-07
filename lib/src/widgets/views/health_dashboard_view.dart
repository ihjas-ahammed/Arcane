import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/widgets/health/health_combined_chart.dart';
import 'package:arcane/src/widgets/health/sleep_panel.dart';
import 'package:arcane/src/widgets/health/activity_panel.dart';
import 'package:arcane/src/widgets/health/nutrition_panel.dart';
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
        children:[
          // Date Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              IconButton(icon: const Icon(Icons.chevron_left, color: JweTheme.textMuted), onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)))),
              Text(DateFormat('MMM dd, yyyy').format(_selectedDate).toUpperCase(), style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.chevron_right, color: JweTheme.textMuted), onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)))),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chart
          JwePanel(
            title: "TREND ANALYSIS (7-DAY)",
            accentColor: JweTheme.accentAmber,
            child: SizedBox(
              height: 200,
              child: HealthCombinedChart(provider: provider),
            ),
          ),

          // Hydration
          JwePanel(
            title: "HYDRATION",
            accentColor: JweTheme.accentCyan,
            child: Column(
              children:[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    IconButton(icon: const Icon(Icons.remove, color: JweTheme.textMuted), onPressed: () => provider.updateWater(dateStr, (log.waterGlasses - 1).clamp(0, 99))),
                    Text("${log.waterGlasses}", style: GoogleFonts.rajdhani(fontSize: 28, fontWeight: FontWeight.bold, color: JweTheme.textWhite)),
                    IconButton(icon: const Icon(Icons.add, color: JweTheme.accentCyan), onPressed: () => provider.updateWater(dateStr, log.waterGlasses + 1)),
                  ],
                ),
                const Text("GLASSES", style: TextStyle(fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Sleep
          SleepPanel(dateStr: dateStr),

          // Activity
          ActivityPanel(dateStr: dateStr),

          // Nutrition
          NutritionPanel(dateStr: dateStr),
        ],
      ),
    );
  }
}