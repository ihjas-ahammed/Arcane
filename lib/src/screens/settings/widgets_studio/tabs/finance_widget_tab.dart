import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_models.dart';
import '../widgets_studio_resolvers.dart';
import '../widgets_studio_sync.dart';

class FinanceWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const FinanceWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<FinanceWidgetTab> createState() => _FinanceWidgetTabState();
}

class _FinanceWidgetTabState extends State<FinanceWidgetTab> {
  bool _overrideFinance = false;
  double _financeBalance = 24500.0;
  double _financeSpentToday = 450.0;
  double _financeMonthSpend = 4200.0;
  int _financeBudgetPct = 42;
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final live = WidgetsStudioResolvers.resolveLiveFinance(widget.provider);
    final balance = _overrideFinance ? _financeBalance : live.balance;
    final todaySpend = _overrideFinance ? _financeSpentToday : live.todaySpend;
    final monthSpend = _overrideFinance ? _financeMonthSpend : live.monthSpend;
    final budgetPct = _overrideFinance ? _financeBudgetPct : live.budgetPct;

    final currentData = FinanceWidgetData(
      balance: balance,
      todaySpend: todaySpend,
      monthSpend: monthSpend,
      budgetPct: budgetPct,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideFinance,
            child: Center(
              child: FinanceHomeWidget(
                balance: balance,
                todaySpend: todaySpend,
                monthSpend: monthSpend,
                budgetPct: budgetPct,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StudioActionButtons(
            syncLabel: "SYNC FINANCE WIDGET",
            isSyncing: _isSyncing,
            onSync: () async {
              setState(() => _isSyncing = true);
              await WidgetsStudioSync.pushFinanceToAndroid(currentData, context: context);
              if (mounted) setState(() => _isSyncing = false);
            },
            onPin: () => WidgetsStudioSync.pinWidget(
              context,
              HomeWidgetService.instance.requestPinFinance,
              "Finance Widget",
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideFinance,
            onToggleOverride: (val) {
              setState(() {
                _overrideFinance = val;
                if (val) {
                  _financeBalance = live.balance;
                  _financeSpentToday = live.todaySpend;
                  _financeMonthSpend = live.monthSpend;
                  _financeBudgetPct = live.budgetPct;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudioTextField(
                  label: "Liquid Balance",
                  initialValue: _financeBalance.toString(),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) setState(() => _financeBalance = parsed);
                  },
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Today Spend",
                  initialValue: _financeSpentToday.toString(),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) setState(() => _financeSpentToday = parsed);
                  },
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Month Spend",
                  initialValue: _financeMonthSpend.toString(),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) setState(() => _financeMonthSpend = parsed);
                  },
                ),
                const SizedBox(height: 12),
                Text("Budget %: $_financeBudgetPct%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _financeBudgetPct.toDouble().clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _financeBudgetPct = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
