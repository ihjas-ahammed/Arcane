import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/finance/savings_detail_screen.dart';
import 'package:missions/src/widgets/dialogs/add_savings_goal_dialog.dart';
import 'package:missions/src/utils/finance_helpers.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.panel, 
              foregroundColor: JweTheme.accentAmber, 
              shape: BeveledRectangleBorder(side: BorderSide(color: JweTheme.accentAmber))
            ),
            onPressed: () {
              showDialog(context: context, builder: (ctx) => const AddSavingsGoalDialog());
            },
          ),
          const SizedBox(height: 24),
          if (goals.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No active savings goals.", style: TextStyle(color: JweTheme.textMuted))))
          else
            ...goals.map((g) {
              final progress = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsDetailScreen(goalId: g.id))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: JweTheme.panel,
                    border: Border.all(color: JweTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(FinanceHelpers.getIconData(g.iconName), color: JweTheme.accentAmber, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(g.name.toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: JweTheme.textWhite)),
                          ),
                          Text("â‚¹${g.currentAmount.toStringAsFixed(0)} / â‚¹${g.targetAmount.toStringAsFixed(0)}", style: const TextStyle(color: JweTheme.textMuted, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: JweTheme.bgBase,
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(color: JweTheme.accentAmber),
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