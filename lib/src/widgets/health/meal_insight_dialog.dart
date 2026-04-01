import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/health_models.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MealInsightDialog extends StatefulWidget {
  final FoodItem foodItem;
  
  const MealInsightDialog({super.key, required this.foodItem});

  @override
  State<MealInsightDialog> createState() => _MealInsightDialogState();
}

class _MealInsightDialogState extends State<MealInsightDialog> {
  Map<String, dynamic>? _insights;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.foodItem.description != null && widget.foodItem.description!.isNotEmpty) {
      // Use existing insights
      _insights = {
        'description': widget.foodItem.description,
        'benefits': widget.foodItem.benefits,
        'warnings': widget.foodItem.warnings,
      };
      _isLoading = false;
    } else {
      _fetchInsights();
    }
  }

  Future<void> _fetchInsights() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    try {
      final res = await provider.aiService.getMealInsights(
        mealName: widget.foodItem.name,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (i) => provider.setApiKeyIndex(i),
        onLog: (_) {},
      );
      
      // Save data back to the FoodItem so we don't have to fetch again
      widget.foodItem.description = res['description'];
      widget.foodItem.benefits = (res['benefits'] as List?)?.map((e) => e.toString()).toList();
      widget.foodItem.warnings = (res['warnings'] as List?)?.map((e) => e.toString()).toList();
      provider.updateFoodItem(widget.foodItem);

      if (mounted) setState(() { _insights = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Text("NUTRITIONAL INSIGHT", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: _isLoading 
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: JweTheme.accentCyan)))
          : _error != null
            ? Text("Error: $_error", style: const TextStyle(color: JweTheme.accentRed))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.foodItem.name.toUpperCase(), style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Text(_insights?['description'] ?? 'No description available.', style: const TextStyle(color: JweTheme.textMuted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  
                  if (_insights?['benefits'] != null) ...[
                    const Text("BENEFITS", style: TextStyle(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(_insights!['benefits'] as List).map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• ", style: TextStyle(color: JweTheme.accentCyan)),
                          Expanded(child: Text(b.toString(), style: const TextStyle(color: JweTheme.textWhite, fontSize: 12))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],

                  if (_insights?['warnings'] != null && (_insights!['warnings'] as List).isNotEmpty) ...[
                    const Text("WARNINGS / ALERTS", style: TextStyle(color: JweTheme.accentRed, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(_insights!['warnings'] as List).map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("! ", style: TextStyle(color: JweTheme.accentRed)),
                          Expanded(child: Text(w.toString(), style: const TextStyle(color: JweTheme.textMuted, fontSize: 12))),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: JweTheme.textMuted))),
      ],
    );
  }
}