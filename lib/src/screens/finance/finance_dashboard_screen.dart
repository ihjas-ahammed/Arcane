import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/finance/finance_tracker_view.dart';
import 'package:arcane/src/widgets/finance/savings_goals_view.dart';
import 'package:google_fonts/google_fonts.dart';

class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: JweTheme.panel,
              border: Border(bottom: BorderSide(color: JweTheme.border)),
            ),
            child: TabBar(
              indicatorColor: JweTheme.accentCyan,
              labelColor: JweTheme.accentCyan,
              unselectedLabelColor: JweTheme.textMuted,
              labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14),
              tabs: const [
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