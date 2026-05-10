import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/ui/jwe_panel.dart';
import 'package:missions/src/widgets/health/food_logging_dialog.dart';
import 'package:missions/src/widgets/health/meal_insight_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class NutritionPanel extends StatelessWidget {
  final String dateStr;
  const NutritionPanel({super.key, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);

    int totalCalories = 0;
    double totalProtein = 0;
    for (var m in log.meals) {
      final food = provider.foodItems.where((f) => f.id == m.foodItemId).firstOrNull;
      if (food != null) {
        totalCalories += food.calories;
        totalProtein += food.protein;
      }
    }

    return JwePanel(
      title: "NUTRITIONAL INTAKE",
      accentColor: JweTheme.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  const Text("CALORIES", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("$totalCalories KCAL", style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: JweTheme.textWhite)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children:[
                  const Text("PROTEIN", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("${totalProtein.toStringAsFixed(1)} G", style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: JweTheme.accentCyan)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (log.meals.isEmpty)
             const Text("No nutritional data recorded for this cycle.", style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: log.meals.length,
              itemBuilder: (ctx, i) {
                final mLog = log.meals[i];
                final food = provider.foodItems.where((f) => f.id == mLog.foodItemId).firstOrNull;
                if (food == null) return const SizedBox.shrink();

                return InkWell(
                  onTap: () {
                    showDialog(context: context, builder: (_) => MealInsightDialog(foodItem: food));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan.withOpacity(0.05),
                      border: Border.all(color: JweTheme.accentCyan.withOpacity(0.2)),
                    ),
                    child: Row(
                      children:[
                        Icon(MdiIcons.foodAppleOutline, color: JweTheme.accentCyan, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(food.name.toUpperCase(), style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text("${food.calories} kcal | ${food.protein}g protein", style: const TextStyle(color: JweTheme.textMuted, fontSize: 10, fontFamily: 'RobotoMono')),
                            ],
                          ),
                        ),
                        // Log Again
                        IconButton(
                          icon: const Icon(Icons.refresh, color: JweTheme.accentAmber, size: 18),
                          tooltip: "Log Again",
                          onPressed: () => provider.logMealAgain(dateStr, mLog),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        // Delete
                        IconButton(
                          icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 18),
                          onPressed: () => provider.deleteMealLog(dateStr, mLog.id),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      ],
                    ),
                  ),
                );
              }
            ),
          
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text("LOG MEAL", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            style: OutlinedButton.styleFrom(
              foregroundColor: JweTheme.accentCyan,
              side: const BorderSide(color: JweTheme.accentCyan),
              shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
            ),
            onPressed: () => showDialog(context: context, builder: (_) => FoodLoggingDialog(dateStr: dateStr)),
          )
        ],
      ),
    );
  }
}