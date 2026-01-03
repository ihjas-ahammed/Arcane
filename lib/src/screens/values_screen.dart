import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/screens/value_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_value_card.dart';
import 'package:provider/provider.dart';

class ValuesScreen extends StatelessWidget {
  const ValuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final values = provider.lifeValues;

    // Calculate overall alignment
    double totalScore = 0;
    for (var v in values) {
      totalScore += v.score;
    }
    final double averageScore =
        values.isEmpty ? 0 : totalScore / values.length / 100.0;
    final int averagePercent = (averageScore * 100).toInt();

    Color progressColor = AppTheme.fhAccentRed;
    if (averagePercent >= 80) progressColor = AppTheme.fhAccentTeal;
    else if (averagePercent >= 50) progressColor = AppTheme.fhAccentGold;

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header resembling Agent Select
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SELECT PROTOCOL",
                  style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.fhTextPrimary,
                      height: 0.9,
                      letterSpacing: 2.0),
                ),
                const SizedBox(height: 8),
                Text(
                  "DEFINE YOUR CORE DRIVERS // ALIGN YOUR ACTIONS",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Overall Alignment Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("OVERALL ALIGNMENT",
                        style: TextStyle(
                            color: AppTheme.fhTextSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1.0)),
                    Text("$averagePercent%",
                        style: TextStyle(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: averageScore,
                    backgroundColor: AppTheme.fhBgDark,
                    color: progressColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            // Use ReorderableListView for dragging sorting
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: values.length,
              onReorder: (oldIndex, newIndex) {
                provider.reorderValues(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 6,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final value = values[index];
                return Padding(
                  key: ValueKey(value.id),
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: SizedBox(
                    height: 120, // Fixed height for consistency
                    child: ValorantValueCard(
                      value: value,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ValueDetailScreen(valueId: value.id),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
