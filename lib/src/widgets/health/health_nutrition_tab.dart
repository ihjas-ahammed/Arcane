import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class HealthNutritionTab extends StatefulWidget {
  final AppProvider provider;
  final DailyHealthLog log;
  final String dateStr;
  final Color accent;
  final double bottomPadding;

  const HealthNutritionTab({
    super.key,
    required this.provider,
    required this.log,
    required this.dateStr,
    required this.accent,
    required this.bottomPadding,
  });

  @override
  State<HealthNutritionTab> createState() => _HealthNutritionTabState();
}

class _HealthNutritionTabState extends State<HealthNutritionTab> {
  final _foodNameController = TextEditingController();
  final _foodAmountController = TextEditingController();
  bool _isAnalyzingFood = false;

  @override
  void dispose() {
    _foodNameController.dispose();
    _foodAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleFoodAILog(AppProvider provider, String dateStr) async {
    final food = _foodNameController.text.trim();
    final amount = _foodAmountController.text.trim();

    if (food.isEmpty || amount.isEmpty) return;

    setState(() => _isAnalyzingFood = true);
    try {
      final foodItem = await provider.analyzeFoodWithAI(food, amount);
      provider.addFoodItem(foodItem);

      final mealLog = MealLog(
        id: const Uuid().v4(),
        foodItemId: foodItem.id,
        timestamp: DateTime.now(),
      );
      provider.addMealLog(dateStr, mealLog);

      _foodNameController.clear();
      _foodAmountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged "$food ($amount)" successfully!'),
            backgroundColor: JweTheme.accentTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing food: $e'),
            backgroundColor: JweTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingFood = false);
    }
  }

  Widget _buildMacrosColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.rajdhani(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsWithFood = widget.log.meals.map((meal) {
      final food = widget.provider.foodItems.firstWhereOrNull((f) => f.id == meal.foodItemId);
      return MapEntry(meal, food);
    }).toList();

    final totalCalories = mealsWithFood.fold<int>(0, (sum, entry) => sum + (entry.value?.calories ?? 0));
    final totalProtein = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.protein ?? 0.0));
    final totalCarbs = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.carbs ?? 0.0));
    final totalFat = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.fat ?? 0.0));
    final totalFiber = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.fiber ?? 0.0));
    final totalSugar = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.sugar ?? 0.0));
    final totalSodium = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.sodium ?? 0.0));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Food Form Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentAmber,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LOG MEAL PROTOCOL (AI ASSISTED)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _foodNameController,
                  style: TextStyle(color: JweTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'FOOD CONSUMED (e.g. Grilled Chicken)',
                    labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _foodAmountController,
                  style: TextStyle(color: JweTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'APPROXIMATE PORTION AMOUNT (e.g. 150 grams / 1 cup)',
                    labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JweTheme.accentAmber,
                    foregroundColor: JweTheme.onAccent,
                    shape: const BeveledRectangleBorder(),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: _isAnalyzingFood ? null : () => _handleFoodAILog(widget.provider, widget.dateStr),
                  icon: _isAnalyzingFood
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: JweTheme.onAccent),
                        )
                      : const Icon(MdiIcons.brain, size: 16),
                  label: Text(
                    _isAnalyzingFood ? 'ANALYZING PROFILE...' : 'ENGAGE AI NUTRITION ANALYSIS',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total Summary Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMacrosColumn("CALORIES", "$totalCalories kcal", JweTheme.textWhite)),
                    Expanded(child: _buildMacrosColumn("PROTEIN", "${totalProtein.toStringAsFixed(1)}g", JweTheme.accentTeal)),
                    Expanded(child: _buildMacrosColumn("CARBS", "${totalCarbs.toStringAsFixed(1)}g", JweTheme.accentCyan)),
                    Expanded(child: _buildMacrosColumn("FAT", "${totalFat.toStringAsFixed(1)}g", JweTheme.accentAmber)),
                  ],
                ),
                if (totalFiber > 0 || totalSugar > 0 || totalSodium > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: JweTheme.border.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: _buildMacrosColumn("FIBER", "${totalFiber.toStringAsFixed(1)}g", JweTheme.accentTeal)),
                      Expanded(child: _buildMacrosColumn("SUGAR", "${totalSugar.toStringAsFixed(1)}g", JweTheme.accentAmber)),
                      Expanded(child: _buildMacrosColumn("SODIUM", "${totalSodium.toStringAsFixed(0)}mg", JweTheme.accentCyan)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meal List
          Row(
            children: [
              Container(width: 4, height: 12, color: JweTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                'LOGGED MEAL PROTOCOLS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (mealsWithFood.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'NO MEALS RECORDED FOR THIS PROTOCOL CYCLE.',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              ),
            )
          else
            ...mealsWithFood.map((entry) {
              final meal = entry.key;
              final food = entry.value;

              if (food == null) return const SizedBox.shrink();

              final hasWarnings = food.warnings != null && food.warnings!.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: HudPanel(
                  clip: HudClip.br,
                  accent: hasWarnings ? JweTheme.accentRed : JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: JweTheme.border.withValues(alpha: 0.2))),
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.silverwareForkKnife, color: JweTheme.accentTeal, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                food.name.toUpperCase(),
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (food.amount != null && food.amount!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: JweTheme.panel2,
                                  border: Border.all(color: JweTheme.border),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  food.amount!,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.accentAmber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              DateFormat('HH:mm').format(meal.timestamp),
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => widget.provider.deleteMealLog(widget.dateStr, meal.id),
                            ),
                          ],
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Warning box if exists
                            if (hasWarnings) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentRed.withValues(alpha: 0.1),
                                  border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(MdiIcons.alertOutline, color: JweTheme.accentRed, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        food.warnings!.join(' • '),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentRed,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Macro Grid
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMacroBadge(
                                    "CALORIES",
                                    "${food.calories}",
                                    "kcal",
                                    JweTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMacroBadge(
                                    "PROTEIN",
                                    "${food.protein}g",
                                    "",
                                    JweTheme.accentTeal,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMacroBadge(
                                    "CARBS",
                                    "${food.carbs}g",
                                    "",
                                    JweTheme.accentCyan,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMacroBadge(
                                    "FAT",
                                    "${food.fat}g",
                                    "",
                                    JweTheme.accentAmber,
                                  ),
                                ),
                              ],
                            ),

                            // Secondary Macros (Fiber, Sugar, Sodium) if present
                            if (food.fiber > 0 || food.sugar > 0 || food.sodium > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (food.fiber > 0) ...[
                                    Expanded(
                                      child: _buildMacroBadge(
                                        "FIBER",
                                        "${food.fiber}g",
                                        "",
                                        JweTheme.accentTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (food.sugar > 0) ...[
                                    Expanded(
                                      child: _buildMacroBadge(
                                        "SUGAR",
                                        "${food.sugar}g",
                                        "",
                                        JweTheme.accentAmber,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (food.sodium > 0) ...[
                                    Expanded(
                                      child: _buildMacroBadge(
                                        "SODIUM",
                                        "${food.sodium}mg",
                                        "",
                                        JweTheme.accentCyan,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            // Micronutrients tag list
                            if (food.micronutrients != null && food.micronutrients!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: food.micronutrients!.map((micro) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: JweTheme.bgCanvas.withValues(alpha: 0.5),
                                      border: Border.all(color: JweTheme.border),
                                    ),
                                    child: Text(
                                      micro,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: JweTheme.bgCanvas.withValues(alpha: 0.4),
        border: Border.all(color: JweTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            "$value$unit",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
