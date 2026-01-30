import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/wallet_models.dart';
import 'package:arcane/src/widgets/wallet/wallet_balance_card.dart';
import 'package:arcane/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  void _showAddTransactionDialog(BuildContext context, {WalletTransaction? transaction}) {
    showDialog(
      context: context,
      builder: (context) => AddTransactionDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final transactions = provider.walletTransactions;
    final currentBalance = provider.currentWalletBalance;
    final projectedBalance = provider.calculateProjectedBalance(30);

    // Recent History (Non-Future)
    final recentHistory = transactions.where((t) => !t.isFuture).toList();

    // Future/Planned
    final planned = transactions.where((t) => t.isFuture).toList();

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "WALLET",
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.fhTextPrimary
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.plus, color: AppTheme.fhAccentTeal),
                    onPressed: () => _showAddTransactionDialog(context),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    WalletBalanceCard(
                      currentBalance: currentBalance,
                      projectedBalance: projectedBalance,
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ValorantButton(
                            label: "LOG EXPENSE",
                            isPrimary: false,
                            icon: MdiIcons.cashMinus,
                            color: AppTheme.fhAccentRed.withOpacity(0.2),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const AddTransactionDialog(initialType: TransactionType.expense),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValorantButton(
                            label: "LOG INCOME",
                            isPrimary: false,
                            icon: MdiIcons.cashPlus,
                            color: AppTheme.fhAccentGreen.withOpacity(0.2),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const AddTransactionDialog(initialType: TransactionType.income),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Spending Trend Chart (Basic Line Chart of Balances over last 30 days)
                    if (recentHistory.isNotEmpty) ...[
                      const Text("BALANCE TRAJECTORY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.only(right: 16),
                        child: LineChart(
                          _buildBalanceChartData(recentHistory, currentBalance),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Recent Transactions List
                    if (recentHistory.isNotEmpty) ...[
                      const Text("RECENT ACTIVITY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentHistory.take(5).length,
                        itemBuilder: (context, index) {
                          final t = recentHistory[index];
                          return _buildTransactionTile(context, provider, t);
                        },
                      ),
                    ],

                    if (planned.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text("PLANNED / RECURRING", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: planned.length,
                        itemBuilder: (context, index) {
                          final t = planned[index];
                          return _buildTransactionTile(context, provider, t, isFuture: true);
                        },
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, AppProvider provider, WalletTransaction t, {bool isFuture = false}) {
    final isExpense = t.type == TransactionType.expense;
    final color = isExpense ? AppTheme.fhAccentRed : AppTheme.fhAccentGreen;
    
    return Dismissible(
      key: ValueKey(t.id),
      background: Container(color: AppTheme.fhAccentRed, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (dir) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.fhBgDark,
            title: const Text("DELETE TRANSACTION?", style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: AppTheme.fhAccentRed))),
            ],
          )
        );
      },
      onDismissed: (dir) => provider.deleteWalletTransaction(t.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
          ),
          child: Icon(t.categoryIcon, color: t.feelingColor, size: 20),
        ),
        title: Text(t.category.toUpperCase(), style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          "${DateFormat('MMM dd').format(t.date)} • ${t.note.isNotEmpty ? t.note : t.feeling}",
          style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          "${isExpense ? '-' : '+'}${t.amount.toStringAsFixed(2)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono', fontSize: 14),
        ),
        onTap: () => _showAddTransactionDialog(context, transaction: t),
      ),
    );
  }

  LineChartData _buildBalanceChartData(List<WalletTransaction> transactions, double currentBalance) {
    // Reverse list to calculate history backwards
    // Current Balance is at Now.
    // Previous balance = Current - Income + Expense
    
    List<FlSpot> spots = [];
    double runningBalance = currentBalance;
    DateTime now = DateTime.now();
    
    // Add current point
    spots.add(FlSpot(0, runningBalance));

    // Sort descending (newest first) to backtrack
    final sorted = List<WalletTransaction>.from(transactions)..sort((a,b) => b.date.compareTo(a.date));
    
    // Limit to 30 days
    final limitDate = now.subtract(const Duration(days: 30));
    
    for (var t in sorted) {
      if (t.date.isBefore(limitDate)) break;
      
      // Calculate balance BEFORE this transaction
      if (t.type == TransactionType.income) {
        runningBalance -= t.amount;
      } else {
        runningBalance += t.amount;
      }
      
      final daysAgo = now.difference(t.date).inDays.toDouble();
      spots.add(FlSpot(daysAgo, runningBalance));
    }

    // Since x axis is "days ago", 0 is right. We want graph left-to-right.
    // So we flip X: x = 30 - daysAgo (approx) or just negate and format titles.
    // Let's use negative X for "days ago".
    final finalSpots = spots.map((s) => FlSpot(-s.x, s.y)).toList();

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: finalSpots,
          isCurved: true,
          color: AppTheme.fhAccentTeal,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppTheme.fhAccentTeal.withOpacity(0.1)),
        ),
      ],
    );
  }
}