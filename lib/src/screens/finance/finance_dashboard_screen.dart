import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/finance/finance_tracker_view.dart';
import 'package:arcane/src/widgets/finance/savings_goals_view.dart';

class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.fhBgDeepDark,
        appBar: AppBar(
          backgroundColor: AppTheme.fhBgDeepDark,
          title: const Text("FINANCE COMMAND", style: TextStyle(fontFamily: AppTheme.fontDisplay, letterSpacing: 2.0)),
          centerTitle: true,
          bottom: const TabBar(
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
        body: const TabBarView(
          children: [
            FinanceTrackerView(),
            SavingsGoalsView(),
          ],
        ),
      ),
    );
  }
}