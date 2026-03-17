import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/dialogs/add_savings_log_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class SavingsDetailScreen extends StatelessWidget {
  final String goalId;

  const SavingsDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final goal = provider.savingsGoals.firstWhereOrNull((g) => g.id == goalId);
    
    if (goal == null) {
      return const Scaffold(backgroundColor: AppTheme.fhBgDeepDark, body: SizedBox.shrink());
    }
    
    final actualProgress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
    
    final totalDuration = goal.targetDate.difference(goal.createdAt).inMilliseconds;
    final elapsed = DateTime.now().difference(goal.createdAt).inMilliseconds;
    final expectedProgress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;

    DateTime? predictedDate;
    if (goal.currentAmount > 0 && goal.currentAmount < goal.targetAmount) {
      final daysSinceCreation = max(1, DateTime.now().difference(goal.createdAt).inDays);
      final dailyAvg = goal.currentAmount / daysSinceCreation;
      if (dailyAvg > 0) {
        final amountLeft = goal.targetAmount - goal.currentAmount;
        final daysLeft = (amountLeft / dailyAvg).ceil();
        predictedDate = DateTime.now().add(Duration(days: daysLeft));
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text(goal.name.toUpperCase()),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
            onPressed: () {
              provider.financeActions.deleteSavingsGoal(goal.id);
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ACCUMULATED FUNDS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("₹${goal.currentAmount.toStringAsFixed(2)}", style: const TextStyle(color: AppTheme.fhAccentPurple, fontSize: 32, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("TARGET", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("₹${goal.targetAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            const Text("PROGRESS TRAJECTORY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(color: AppTheme.fhBgDark, borderRadius: BorderRadius.circular(8)),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: expectedProgress,
                    child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8))),
                  ),
                  FractionallySizedBox(
                    widthFactor: actualProgress,
                    child: Container(decoration: BoxDecoration(color: actualProgress >= expectedProgress ? AppTheme.fhAccentGreen : AppTheme.fhAccentPurple, borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Target: ${DateFormat('MMM dd, yyyy').format(goal.targetDate)}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                if (predictedDate != null)
                  Text("Projected: ${DateFormat('MMM dd, yyyy').format(predictedDate)}", style: TextStyle(color: predictedDate.isBefore(goal.targetDate) ? AppTheme.fhAccentGreen : AppTheme.fhAccentOrange, fontSize: 12)),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("ALLOCATE FUNDS"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: AppTheme.fhAccentPurple, foregroundColor: Colors.white),
              onPressed: () => _showAddLogDialog(context, provider, goal.id),
            ),
            
            const SizedBox(height: 32),
            const Text("INVESTMENT LOG", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...goal.logs.map((log) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.arrowRightBottom, color: AppTheme.fhAccentPurple),
                title: Text("₹${log.amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('MMM dd, HH:mm').format(log.timestamp), style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11)),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: AppTheme.fhAccentRed.withOpacity(0.7), size: 20),
                  onPressed: () => provider.financeActions.deleteSavingsLog(goal.id, log.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddLogDialog(BuildContext context, AppProvider provider, String goalId) {
    showDialog(context: context, builder: (ctx) => AddSavingsLogDialog(goalId: goalId));
  }
}