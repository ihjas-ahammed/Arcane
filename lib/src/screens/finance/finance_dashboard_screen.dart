import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/finance/finance_tracker_view.dart';
import 'package:arcane/src/widgets/finance/savings_goals_view.dart';

class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Removed Scaffold/AppBar to integrate into main layout via IndexedStack
    // Use DefaultTabController to manage tabs internally
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Custom Tab Bar embedded in the view
          Container(
            decoration: BoxDecoration(
              color: AppTheme.fhBgDeepDark,
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
            ),
            child: const TabBar(
              indicatorColor: AppTheme.fhAccentTeal,
              labelColor: AppTheme.fhAccentTeal,
              unselectedLabelColor: AppTheme.fhTextSecondary,
              labelStyle: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              tabs: [
                Tab(text: "CASHFLOW"),
                Tab(text: "SAVINGS"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                FinanceTrackerView(),
                SavingsGoalsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}