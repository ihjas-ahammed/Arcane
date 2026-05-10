import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/finance/finance_tracker_view.dart';
import 'package:missions/src/widgets/finance/savings_goals_view.dart';

/// Operator HUD wallet dashboard. Two surfaces: live cashflow + savings.
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
              color: JweTheme.bgCanvas,
              border: Border(bottom: BorderSide(color: JweTheme.lineSoft, width: 1)),
            ),
            child: TabBar(
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: JweTheme.accentAmber, width: 2),
                insets: EdgeInsets.symmetric(horizontal: 24),
              ),
              labelColor: JweTheme.accentAmber,
              unselectedLabelColor: JweTheme.textMuted,
              labelStyle: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 11,
              ),
              unselectedLabelStyle: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w600, letterSpacing: 1.6, fontSize: 11,
              ),
              tabs: const [
                Tab(text: 'CASHFLOW'),
                Tab(text: 'SAVINGS'),
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
