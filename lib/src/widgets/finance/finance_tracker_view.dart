import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/add_edit_account_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:missions/src/widgets/finance/sections/finance_analytics_tab.dart';
import 'package:missions/src/widgets/finance/sections/finance_budget_tab.dart';
import 'package:missions/src/widgets/finance/sections/finance_ledger_tab.dart';
import 'package:provider/provider.dart';

export 'package:missions/src/widgets/finance/sections/finance_analytics_tab.dart';
export 'package:missions/src/widgets/finance/sections/finance_budget_tab.dart';
export 'package:missions/src/widgets/finance/sections/finance_dialogs.dart';
export 'package:missions/src/widgets/finance/sections/finance_ledger_tab.dart';
export 'package:missions/src/widgets/finance/sections/finance_widgets_common.dart';
export 'package:missions/src/widgets/finance/sections/linear_regression.dart';

class FinanceTrackerView extends StatefulWidget {
  const FinanceTrackerView({super.key});

  @override
  State<FinanceTrackerView> createState() => _FinanceTrackerViewState();
}

class _FinanceTrackerViewState extends State<FinanceTrackerView> {
  static const String _currency = '₹';

  void _showAddTransactionDialog(BuildContext context, bool isIncome) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(isIncome: isIncome),
    );
  }

  void _showAddAccountDialog(BuildContext context, {FinanceAccount? existing}) {
    showDialog(
      context: context,
      builder: (_) => AddEditAccountDialog(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Narrow the watch to what the ledger/budget/analytics tabs actually render —
    // a full provider watch rebuilt all three tabs on every unrelated change
    // (task timers, health logs, sync flags, etc).
    final accentColor = context.select<AppProvider, Color>(
        (p) => p.getSelectedTask()?.taskColor ?? JweTheme.accentAmber);
    context.select<AppProvider, (List<FinanceTransaction>, List<FinanceCategory>, List<FinanceAccount>)>(
        (p) => (p.transactions, p.categories, p.accounts));
    final provider = context.read<AppProvider>();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: JweTheme.panel,
            child: TabBar(
              indicatorColor: accentColor,
              labelColor: accentColor,
              dividerColor: accentColor.withValues(alpha: 0.20),
              unselectedLabelColor: JweTheme.textMuted,
              tabs: [
                Tab(icon: Icon(MdiIcons.databaseOutline, size: 20)),
                Tab(icon: Icon(MdiIcons.calculatorVariantOutline, size: 20)),
                Tab(icon: Icon(MdiIcons.chartLine, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                FinanceLedgerTab(
                  provider: provider,
                  currency: _currency,
                  onAddTransaction: (isIncome) =>
                      _showAddTransactionDialog(context, isIncome),
                  onAddAccount: ({existing}) =>
                      _showAddAccountDialog(context, existing: existing),
                ),
                FinanceBudgetTab(
                  provider: provider,
                  accent: accentColor,
                  currency: _currency,
                ),
                FinanceAnalyticsTab(
                  provider: provider,
                  accent: accentColor,
                  currency: _currency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
