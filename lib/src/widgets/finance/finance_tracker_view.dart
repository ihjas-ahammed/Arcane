import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/finance/finance_charts.dart';
import 'package:arcane/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:arcane/src/utils/finance_helpers.dart';
import 'package:arcane/src/models/finance_models.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FinanceTrackerView extends StatefulWidget {
  const FinanceTrackerView({super.key});

  @override
  State<FinanceTrackerView> createState() => _FinanceTrackerViewState();
}

class _FinanceTrackerViewState extends State<FinanceTrackerView> {
  DateTime _selectedDate = DateTime.now();

  void _showAddTransactionDialog(BuildContext context, bool isIncome) {
    showDialog(
      context: context,
      builder: (ctx) => AddTransactionDialog(isIncome: isIncome),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final balance = provider.financeActions.currentBalance;
    
    // Calculate 30d totals
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    double income30d = 0;
    double expense30d = 0;
    for (var t in provider.transactions) {
      if (t.timestamp.isAfter(thirtyDaysAgo)) {
        if (t.isIncome) income30d += t.amount;
        else expense30d += t.amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.fhBgDark, AppTheme.fhBgDeepDark],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text("TOTAL BALANCE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(
                  "₹${balance.toStringAsFixed(2)}",
                  style: const TextStyle(color: AppTheme.fhAccentTeal, fontFamily: AppTheme.fontDisplay, fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol("INCOME (30D)", income30d, AppTheme.fhAccentTeal),
                    Container(width: 1, height: 30, color: AppTheme.fhBorderColor),
                    _buildStatCol("EXPENSE (30D)", expense30d, AppTheme.fhAccentRed),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("INCOME"),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal, foregroundColor: Colors.black),
                  onPressed: () => _showAddTransactionDialog(context, true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text("EXPENSE"),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed, foregroundColor: Colors.white),
                  onPressed: () => _showAddTransactionDialog(context, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Charts
          FinanceCharts(
            transactions: provider.transactions,
            categories: provider.categories,
            selectedDate: _selectedDate,
            onDateChanged: (d) => setState(() => _selectedDate = d),
          ),

          const SizedBox(height: 32),
          const Text("TRANSACTION HISTORY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          if (provider.transactions.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No transactions recorded.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic))))
          else
            ...provider.transactions.map((tx) {
              // Note: Use 'FFFFFF' (6 chars) to prevent FormatException when parsed
              final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => FinanceCategory(id: '', name: 'Unknown', colorHex: 'FFFFFF', iconName: 'help', isIncomeCategory: tx.isIncome));
              final color = Color(int.parse("0xFF${cat.colorHex}"));
              return Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppTheme.fhAccentRed,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => provider.financeActions.deleteTransaction(tx.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withOpacity(0.6),
                    border: Border(left: BorderSide(color: tx.isIncome ? AppTheme.fhAccentTeal : AppTheme.fhAccentRed, width: 3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(FinanceHelpers.getIconData(cat.iconName), color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name.toUpperCase(), style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold)),
                            if (tx.note.isNotEmpty) Text(tx.note, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11)),
                            Text(DateFormat('MMM dd, HH:mm').format(tx.timestamp), style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text(
                        "${tx.isIncome ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}",
                        style: TextStyle(color: tx.isIncome ? AppTheme.fhAccentTeal : AppTheme.fhAccentRed, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono', fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("₹${value.toStringAsFixed(0)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono', fontSize: 18)),
      ],
    );
  }
}