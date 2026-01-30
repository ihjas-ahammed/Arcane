import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FinancePredictionCard extends StatelessWidget {
  const FinancePredictionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final prediction = provider.financePrediction;
    final isLoading = provider.loadingTaskName == "Analyzing Finances...";

    if (prediction == null && !isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(MdiIcons.crystalBall, size: 48, color: AppTheme.fhAccentPurple.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              "AI FINANCE FORECAST",
              style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontFamily: AppTheme.fontDisplay,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.5
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Generate insights on spending habits and predict future expenses.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: "INITIALIZE PREDICTION",
                onPressed: () => provider.generateFinancePrediction(),
                color: AppTheme.fhAccentPurple,
                isPrimary: true,
              ),
            )
          ],
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.fhAccentPurple));
    }

    final message = prediction!['message'] as String? ?? "No data.";
    final predictions = (prediction['predictions'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppTheme.fhAccentPurple, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.fhAccentPurple.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.robotHappyOutline, color: AppTheme.fhAccentPurple),
              const SizedBox(width: 8),
              const Text("FINANCIAL ADVISOR", style: TextStyle(color: AppTheme.fhAccentPurple, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppTheme.fhTextPrimary, fontStyle: FontStyle.italic, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (predictions.isNotEmpty) ...[
            const Text("PREDICTED EXPENSES (NEXT 7 DAYS)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: predictions.length,
                separatorBuilder: (c, i) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final p = predictions[index];
                  return Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDeepDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          (p['category'] ?? 'Misc').toString().toUpperCase(),
                          style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "\$${p['amount']}",
                          style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['reason'] ?? '',
                          style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontSize: 10),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ]
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}