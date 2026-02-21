import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/screens/finance/savings_detail_screen.dart';
import 'package:arcane/src/widgets/dialogs/add_savings_goal_dialog.dart';
import 'package:arcane/src/utils/finance_helpers.dart';
import 'package:provider/provider.dart';

class SavingsGoalsView extends StatelessWidget {
  const SavingsGoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final goals = provider.savingsGoals;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("INITIALIZE SAVINGS GOAL"),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhBgDark, foregroundColor: AppTheme.fhAccentTeal, side: BorderSide(color: AppTheme.fhAccentTeal.withOpacity(0.5))),
            onPressed: () {
              showDialog(context: context, builder: (ctx) => const AddSavingsGoalDialog());
            },
          ),
          const SizedBox(height: 24),
          if (goals.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No active savings goals.", style: TextStyle(color: AppTheme.fhTextDisabled))))
          else
            ...goals.map((g) {
              final progress = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsDetailScreen(goalId: g.id))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(FinanceHelpers.getIconData(g.iconName), color: AppTheme.fhAccentPurple, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(g.name.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
                          ),
                          Text("₹${g.currentAmount.toStringAsFixed(0)} / ₹${g.targetAmount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.fhBgDeepDark,
                          color: AppTheme.fhAccentPurple,
                        ),
                      )
                    ],
                  ),
                ),
              );
            })
        ],
      ),
    );
  }
}