import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

class FoodLoggingDialog extends StatefulWidget {
  final String dateStr;
  const FoodLoggingDialog({super.key, required this.dateStr});

  @override
  State<FoodLoggingDialog> createState() => _FoodLoggingDialogState();
}

class _FoodLoggingDialogState extends State<FoodLoggingDialog> {
  final _promptController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (_promptController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      final items = await provider.aiService.extractFoodInfo(
        prompt: _promptController.text.trim(),
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (i) => provider.setApiKeyIndex(i),
        onLog: (m) {},
      );

      for (var itemData in items) {
        final food = FoodItem(
          id: const Uuid().v4(),
          name: itemData['name'] ?? 'Unknown',
          calories: (itemData['calories'] as num?)?.toInt() ?? 0,
          protein: (itemData['protein'] as num?)?.toDouble() ?? 0,
          carbs: (itemData['carbs'] as num?)?.toDouble() ?? 0,
          fat: (itemData['fat'] as num?)?.toDouble() ?? 0,
        );
        provider.addFoodItem(food);
        provider.addMealLog(widget.dateStr, MealLog(id: const Uuid().v4(), foodItemId: food.id, timestamp: DateTime.now()));
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Text("SMART FOOD SCANNER", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            const Text("Describe the meal. The AI will calculate macros automatically.", style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              maxLines: 3,
              style: const TextStyle(color: JweTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(
                hintText: "e.g. 2 scrambled eggs, a slice of toast, and a coffee",
                hintStyle: TextStyle(color: JweTheme.textMuted),
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 24),
            
            if (provider.foodItems.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text("OR SELECT FROM DATABASE", style: TextStyle(color: JweTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  children: provider.foodItems.map((f) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.name.toUpperCase(), style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text("${f.calories} kcal | ${f.protein}g protein", style: const TextStyle(color: JweTheme.textMuted, fontSize: 11, fontFamily: 'RobotoMono')),
                    trailing: const Icon(Icons.add_circle_outline, color: JweTheme.accentCyan, size: 20),
                    onTap: () {
                       provider.addMealLog(widget.dateStr, MealLog(id: const Uuid().v4(), foodItemId: f.id, timestamp: DateTime.now()));
                       Navigator.pop(context);
                    },
                  )).toList(),
                ),
              )
          ],
        ),
      ),
      actions:[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: Colors.black),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
            : const Text("ANALYZE & LOG", style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}