import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/theme/app_theme.dart';

class FinanceHomeWidget extends StatelessWidget {
  final double balance;
  final double todaySpend;
  final double monthSpend;
  final int budgetPct;

  const FinanceHomeWidget({
    super.key,
    required this.balance,
    required this.todaySpend,
    required this.monthSpend,
    required this.budgetPct,
  });

  String _fmtMoney(double val) {
    final abs = val.abs();
    final sign = val < 0 ? "-" : "";
    if (abs >= 10000000) {
      return "$sign₹${(abs / 10000000).toStringAsFixed(2)}Cr";
    } else if (abs >= 100000) {
      return "$sign₹${(abs / 100000).toStringAsFixed(2)}L";
    } else if (abs >= 1000) {
      return "$sign₹${(abs / 1000).toStringAsFixed(1)}K";
    } else {
      return "$sign₹${abs.toStringAsFixed(0)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedPct = budgetPct.clamp(0, 100);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentGold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentGold,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "// WALLET",
                      style: TextStyle(
                        color: AppTheme.fhAccentGold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()), // last updated time
                  style: TextStyle(
                    color: AppTheme.fhTextDisabled,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Balance
            Text(
              _fmtMoney(balance),
              style: TextStyle(
                color: AppTheme.fhAccentGold,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Today / MTD / Budget Columns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCol("TODAY", _fmtMoney(todaySpend), AppTheme.fhAccentTeal),
                _buildCol("MTD", _fmtMoney(monthSpend), AppTheme.fhAccentGold),
                _buildCol("BUDGET", "$budgetPct%", AppTheme.fhAccentTeal),
              ],
            ),
            const SizedBox(height: 6),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPct / 100.0,
                minHeight: 6,
                backgroundColor: AppTheme.fhBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fhAccentGold),
              ),
            ),
            const SizedBox(height: 8),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "+ INCOME",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "− EXPENSE",
                      style: TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCol(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.fhTextDisabled,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontFamily: AppTheme.fontDisplay,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
