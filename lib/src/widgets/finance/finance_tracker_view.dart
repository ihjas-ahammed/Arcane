import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/finance_helpers.dart';
import 'package:missions/src/widgets/dialogs/add_category_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_edit_account_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

class FinanceTrackerView extends StatefulWidget {
  const FinanceTrackerView({super.key});

  @override
  State<FinanceTrackerView> createState() => _FinanceTrackerViewState();
}

class _FinanceTrackerViewState extends State<FinanceTrackerView> {
  static const String _currency = '₹';

  void _showAddTransactionDialog(BuildContext context, bool isIncome) {
    showDialog(context: context, builder: (_) => AddTransactionDialog(isIncome: isIncome));
  }

  void _showAddAccountDialog(BuildContext context, {FinanceAccount? existing}) {
    showDialog(
      context: context,
      builder: (_) => AddEditAccountDialog(existing: existing),
    );
  }

  void _showChangeBalanceDialog(BuildContext context, FinanceAccount account) {
    final ctrl = TextEditingController(text: account.balance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'CHANGE BALANCE',
            style: GoogleFonts.saira(
              color: JweTheme.accentAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 22),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: JweTheme.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text);
                if (val != null) {
                  provider.financeActions.changeAccountBalance(account.id, val);
                }
                Navigator.pop(ctx);
              },
              child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: JweTheme.accentRed),
            borderRadius: BorderRadius.zero,
          ),
          title: Text('RESET LEDGER',
              style: GoogleFonts.saira(
                  color: JweTheme.accentRed,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  fontSize: 13)),
          content: Text(
            'This will permanently delete all transaction records. Account balances are not affected.',
            style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentRed,
                foregroundColor: Colors.white,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                provider.financeActions.resetTransactions();
                Navigator.pop(ctx);
              },
              child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final accentColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

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
                _buildLedgerTab(context, provider),
                _buildBudgetTab(context, provider, accentColor),
                _buildAnalyticsTab(context, provider, accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context, AppProvider provider) {
    final balance = provider.financeActions.currentBalance;
    final hasAccounts = provider.accounts.isNotEmpty;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final thirtyAgo = today.subtract(const Duration(days: 29));

    var todaySpend = 0.0;
    var monthSpend = 0.0;
    var income30d = 0.0;
    var expense30d = 0.0;

    final dailyExp = List<double>.filled(30, 0);

    for (var t in provider.transactions) {
      final ts = t.timestamp;
      if (!t.isIncome) {
        if (_sameDay(ts, today)) todaySpend += t.amount;
        if (!ts.isBefore(monthStart)) monthSpend += t.amount;
        if (!ts.isBefore(thirtyAgo)) {
          expense30d += t.amount;
          final dayIdx = today.difference(DateTime(ts.year, ts.month, ts.day)).inDays;
          final i = 29 - dayIdx;
          if (i >= 0 && i < 30) dailyExp[i] += t.amount;
        }
      } else {
        if (!ts.isBefore(thirtyAgo)) income30d += t.amount;
      }
    }

    final avg30d = expense30d / 30.0;

    // Projected income for the month
    var monthIncome = 0.0;
    for (var t in provider.transactions) {
      if (t.isIncome && !t.timestamp.isBefore(monthStart)) monthIncome += t.amount;
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day.clamp(1, daysInMonth);
    final dailyIncomeRate = monthIncome / daysElapsed;
    final projectedMonthIncome = dailyIncomeRate * daysInMonth;

    final catTotals = <String, double>{};
    for (var t in provider.transactions) {
      if (t.isIncome) continue;
      if (t.timestamp.isBefore(monthStart)) continue;
      catTotals[t.categoryId] = (catTotals[t.categoryId] ?? 0) + t.amount;
    }
    final cats = provider.categories
        .where((c) => !c.isIncomeCategory && (catTotals[c.id] ?? 0) > 0)
        .map((c) {
          final amt = catTotals[c.id] ?? 0;
          final pct = monthSpend > 0 ? (amt / monthSpend) * 100 : 0;
          return _CatRow(c, amt, pct.toDouble());
        })
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding + 130.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Balance hero ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: HudPanel(
            clip: HudClip.both,
            accent: JweTheme.accentAmber,
            allBrackets: true,
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration:  BoxDecoration(
                  border: Border(bottom: BorderSide(color: JweTheme.lineAmber, width: 1)),
                ),
                child: Row(children: [
                  Text('// LIQUID BALANCE',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.8,
                      )),
                  const Spacer(),
                  HudDot(tone: HudTone.amber),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      '$_currency${_compactMoney(balance)}',
                      style: GoogleFonts.saira(
                        color: JweTheme.accentAmber,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!hasAccounts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          income30d > expense30d
                              ? '+${(((income30d - expense30d) / math.max(1.0, income30d)) * 100).round()}%'
                              : '−${(((expense30d - income30d) / math.max(1.0, expense30d)) * 100).round()}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: income30d > expense30d ? JweTheme.accentTeal : JweTheme.accentRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: HudStat(
                      label: 'Today',
                      value: '$_currency${_compactMoney(todaySpend)}',
                      tone: HudTone.cyan,
                      size: 18,
                    )),
                    Expanded(child: HudStat(
                      label: 'MTD',
                      value: '$_currency${_compactMoney(monthSpend)}',
                      tone: HudTone.amber,
                      size: 18,
                    )),
                    Expanded(child: HudStat(
                      label: 'AVG/30D',
                      value: '$_currency${_compactMoney(avg30d * 30)}',
                      tone: HudTone.cyan,
                      size: 18,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  _IncomeExpenseBar(income: income30d, expense: expense30d),
                ]),
              ),
            ]),
          ),
        ),

        // ── Projected income card ───────────────────
        if (monthIncome > 0 || projectedMonthIncome > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _ProjectedIncomeCard(
              monthIncome: monthIncome,
              projectedIncome: projectedMonthIncome,
              monthExpense: monthSpend,
              daysElapsed: daysElapsed,
              daysInMonth: daysInMonth,
              currency: _currency,
            ),
          ),

        // ── Action buttons ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: _LedgerActionBtn(
                label: 'INCOME',
                icon: MdiIcons.plus,
                accent: JweTheme.accentTeal,
                onTap: () => _showAddTransactionDialog(context, true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LedgerActionBtn(
                label: 'EXPENSE',
                icon: MdiIcons.minus,
                accent: JweTheme.accentRed,
                onTap: () => _showAddTransactionDialog(context, false),
              ),
            ),
            const SizedBox(width: 8),
            _ResetBtn(onTap: () => _confirmReset(context)),
          ]),
        ),

        // ── Accounts ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
          child: HudSectionHead(
            label: 'ACCOUNTS',
            code: hasAccounts ? '${provider.accounts.length} LINKED' : 'NONE',
            accent: HudTone.cyan,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(children: [
            ...provider.accounts.map((acc) {
              final color = Color(int.parse('0xFF${acc.colorHex}'));
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: HudPanel(
                  clip: HudClip.br,
                  accent: color,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Icon(FinanceHelpers.getIconData(acc.iconName), color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(acc.name.toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4,
                            )),
                        Text(acc.type.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted, fontSize: 9, letterSpacing: 1.2,
                            )),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$_currency${_compactMoney(acc.balance)}',
                          style: GoogleFonts.saira(
                            color: color, fontSize: 18, fontWeight: FontWeight.w700,
                          )),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: () => _showChangeBalanceDialog(context, acc),
                          child: Text('BALANCE',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentAmber, fontSize: 9, letterSpacing: 1.0,
                              )),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showAddAccountDialog(context, existing: acc),
                          child: Text('EDIT',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted, fontSize: 9, letterSpacing: 1.0,
                              )),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => provider.financeActions.deleteAccount(acc.id),
                          child: Text('DEL',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentRed, fontSize: 9, letterSpacing: 1.0,
                              )),
                        ),
                      ]),
                    ]),
                  ]),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _showAddAccountDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: JweTheme.lineSoft),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add, color: JweTheme.accentCyan, size: 14),
                  const SizedBox(width: 6),
                  Text('ADD ACCOUNT',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4,
                      )),
                ]),
              ),
            ),
          ]),
        ),

        // ── 30-day expenditure ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentAmber,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('// 30-DAY EXPENDITURE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.8,
                    )),
                const Spacer(),
                Text('μ $_currency${_compactMoney(avg30d)}/d',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w500, letterSpacing: 1.0,
                    )),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: _ExpenditureBars(daily: dailyExp),
              ),
            ]),
          ),
        ),

        // ── Category breakdown ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
          child: const HudSectionHead(label: 'CATEGORY BREAKDOWN', code: 'MTD'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentAmber,
            padding: const EdgeInsets.all(12),
            child: cats.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('NO EXPENSES THIS MONTH',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.4,
                        )),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pie Chart on the left
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 28,
                                startDegreeOffset: -90,
                                sections: cats.map((r) {
                                  final color = Color(int.parse('0xFF${r.cat.colorHex}'));
                                  return PieChartSectionData(
                                    color: color,
                                    value: r.amount,
                                    title: '',
                                    radius: 12,
                                    borderSide: const BorderSide(color: Colors.transparent, width: 0),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8,
                                  color: JweTheme.textMuted,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$_currency${_compactMoney(monthSpend)}',
                                style: GoogleFonts.saira(
                                  fontSize: 11,
                                  color: JweTheme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // List of categories on the right
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(cats.length, (i) {
                            final r = cats[i];
                            final color = Color(int.parse('0xFF${r.cat.colorHex}'));
                            return Padding(
                              padding: EdgeInsets.only(bottom: i < cats.length - 1 ? 10 : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.cat.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: JweTheme.textWhite,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_currency${_compactMoney(r.amount)} · ${r.pct.round()}%',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  HudBar(
                                    value: r.pct.clamp(0, 100),
                                    max: 100,
                                    color: color,
                                    height: 3,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ── Transaction ledger ─────────────────────
        const HudSectionHead(label: 'TRANSACTION LEDGER', code: 'LIVE'),
        if (provider.transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HudPanel(
              clip: HudClip.br,
              accent: JweTheme.accentAmber,
              brackets: false,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('NO TRANSACTIONS RECORDED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.4,
                    )),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: (() {
                final widgets = <Widget>[];
                DateTime? lastDate;
                for (var tx in provider.transactions.take(40)) {
                  final txDate = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
                  if (lastDate == null || lastDate != txDate) {
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Row(
                          children: [
                            const Icon(MdiIcons.chevronDoubleRight, size: 10, color: JweTheme.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              "${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}-${tx.timestamp.day.toString().padLeft(2, '0')}",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: JweTheme.textMuted,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 0.5,
                                color: JweTheme.lineSoft.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    lastDate = txDate;
                  }

                  final cat = provider.categories.firstWhere(
                    (c) => c.id == tx.categoryId,
                    orElse: () => FinanceCategory(id: '', name: 'Unknown', colorHex: 'FFFFFF', iconName: 'help', isIncomeCategory: tx.isIncome),
                  );
                  final color = Color(int.parse('0xFF${cat.colorHex}'));

                  widgets.add(
                    Dismissible(
                      key: ValueKey(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: JweTheme.accentRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => provider.financeActions.deleteTransaction(tx.id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: JweTheme.panel,
                            border: Border(left: BorderSide(color: tx.isIncome ? JweTheme.accentTeal : JweTheme.accentRed, width: 2)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                border: Border.all(color: color.withValues(alpha: 0.40), width: 1),
                              ),
                              child: Icon(FinanceHelpers.getIconData(cat.iconName), color: color, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(cat.name.toUpperCase(),
                                          style: GoogleFonts.saira(
                                            color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4,
                                          )),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AddCategoryDialog(isIncome: cat.isIncomeCategory, category: cat),
                                        );
                                      },
                                      child: Icon(MdiIcons.pencilOutline, size: 12, color: JweTheme.textMuted),
                                    ),
                                  ],
                                ),
                                if (tx.note.isNotEmpty)
                                  Text(tx.note,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: JweTheme.textMuted, fontSize: 11,
                                      )),
                                Text(DateFormat('HH:mm').format(tx.timestamp).toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted, fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w500,
                                    )),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${tx.isIncome ? '+' : '−'}$_currency${_compactMoney(tx.amount)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: tx.isIncome ? JweTheme.accentTeal : JweTheme.accentRed,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                }
                return widgets;
              })(),
            ),
          ),
      ]),
    );
  }

  static String _compactMoney(double v) {
    if (v >= 100000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  void _showSetBudgetDialog(BuildContext context, FinanceCategory cat) {
    final ctrl = TextEditingController(text: cat.budget > 0 ? cat.budget.toStringAsFixed(2) : '');
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'SET MONTHLY BUDGET: ${cat.name.toUpperCase()}',
            style: GoogleFonts.saira(
              color: JweTheme.accentAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter monthly spending limit for this category.',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 22),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: JweTheme.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text) ?? 0.0;
                provider.financeActions.updateCategoryBudget(cat.id, val);
                Navigator.pop(ctx);
              },
              child: const Text('SAVE BUDGET', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetTab(BuildContext context, AppProvider provider, Color accent) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final catMTDSpend = <String, double>{};
    for (var t in provider.transactions) {
      if (t.isIncome) continue;
      if (t.timestamp.isBefore(monthStart)) continue;
      catMTDSpend[t.categoryId] = (catMTDSpend[t.categoryId] ?? 0) + t.amount;
    }

    final expenseCategories = provider.categories.where((c) => !c.isIncomeCategory).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: bottomPadding + 130.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'MONTHLY BUDGET PLANNER',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expenseCategories.isEmpty)
            Center(
              child: Text(
                'NO EXPENSE CATEGORIES DETECTED',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              ),
            )
          else
            ...expenseCategories.map((cat) {
              final spent = catMTDSpend[cat.id] ?? 0.0;
              final budget = cat.budget;
              final color = Color(int.parse('0xFF${cat.colorHex}'));
              final isOver = budget > 0 && spent > budget;
              final remaining = budget - spent;
              final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HudPanel(
                  clip: HudClip.br,
                  accent: isOver ? JweTheme.accentRed : color,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(FinanceHelpers.getIconData(cat.iconName), color: color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            cat.name.toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AddCategoryDialog(isIncome: false, category: cat),
                              );
                            },
                            child: Icon(MdiIcons.pencilOutline, size: 12, color: JweTheme.textMuted),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: color.withValues(alpha: 0.5)),
                              shape: const BeveledRectangleBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => _showSetBudgetDialog(context, cat),
                            child: Text(
                              budget > 0 ? 'EDIT LIMIT' : 'SET BUDGET',
                              style: GoogleFonts.jetBrainsMono(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SPENT MTD',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, letterSpacing: 0.8),
                              ),
                              Text(
                                '$_currency${spent.toStringAsFixed(2)}',
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                budget > 0 ? 'MONTHLY BUDGET' : 'BUDGET',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, letterSpacing: 0.8),
                              ),
                              Text(
                                budget > 0 ? '$_currency${budget.toStringAsFixed(2)}' : 'NOT SET',
                                style: GoogleFonts.saira(
                                  color: budget > 0 ? color : JweTheme.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (budget > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: HudProgressBar(
                                value: progress * 100,
                                tone: isOver ? HudTone.red : HudTone.cyan,
                                segments: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver ? JweTheme.accentRed : JweTheme.textWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOver ? 'EXCEEDED BY:' : 'REMAINING:',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver ? JweTheme.accentRed : JweTheme.textMuted,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '$_currency${remaining.abs().toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver ? JweTheme.accentRed : JweTheme.accentTeal,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, AppProvider provider, Color accent) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyAgo = today.subtract(const Duration(days: 29));
    final dailyInc = List<double>.filled(30, 0);
    final dailyExp = List<double>.filled(30, 0);

    for (var t in provider.transactions) {
      final ts = t.timestamp;
      if (ts.isBefore(thirtyAgo)) continue;
      final dayIdx = today.difference(DateTime(ts.year, ts.month, ts.day)).inDays;
      final i = 29 - dayIdx;
      if (i >= 0 && i < 30) {
        if (t.isIncome) {
          dailyInc[i] += t.amount;
        } else {
          dailyExp[i] += t.amount;
        }
      }
    }

    final regIncome = LinearRegression.calculate(dailyInc);
    final regExpense = LinearRegression.calculate(dailyExp);

    double maxVal = 100.0;
    for (int i = 0; i < 30; i++) {
      if (dailyInc[i] > maxVal) maxVal = dailyInc[i];
      if (dailyExp[i] > maxVal) maxVal = dailyExp[i];
    }
    for (int i = 29; i <= 36; i++) {
      final pi = regIncome.predict(i.toDouble());
      final pe = regExpense.predict(i.toDouble());
      if (pi > maxVal) maxVal = pi;
      if (pe > maxVal) maxVal = pe;
    }
    final maxYVal = maxVal * 1.15;

    final tomorrowIncome = regIncome.predict(30).clamp(0.0, double.infinity);
    final tomorrowExpense = regExpense.predict(30).clamp(0.0, double.infinity);

    // MTD category spend
    final monthStart = DateTime(now.year, now.month, 1);
    final catMTDSpend = <String, double>{};
    for (var t in provider.transactions) {
      if (t.isIncome) continue;
      if (t.timestamp.isBefore(monthStart)) continue;
      catMTDSpend[t.categoryId] = (catMTDSpend[t.categoryId] ?? 0) + t.amount;
    }
    final expenseCategories = provider.categories.where((c) => !c.isIncomeCategory).toList();
    double maxSpend = 100.0;
    for (final cat in expenseCategories) {
      final s = catMTDSpend[cat.id] ?? 0.0;
      if (s > maxSpend) maxSpend = s;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: bottomPadding + 130.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'PREDICTIVE TREND ANALYSIS',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HudPanel(
            clip: HudClip.br,
            accent: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(width: 8, height: 8, color: JweTheme.accentCyan),
                    const SizedBox(width: 4),
                    Text('INCOME', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, color: JweTheme.accentRed),
                    const SizedBox(width: 4),
                    Text('EXPENSE', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 36,
                      minY: 0,
                      maxY: maxYVal,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(color: JweTheme.lineSoft.withValues(alpha: 0.1), strokeWidth: 1),
                        getDrawingVerticalLine: (value) => FlLine(color: JweTheme.lineSoft.withValues(alpha: 0.1), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return Text('30D AGO', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold));
                              if (value == 29) return Text('TODAY', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold));
                              if (value == 36) return Text('+7D PROJ', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 8, fontWeight: FontWeight.bold));
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(30, (idx) => FlSpot(idx.toDouble(), dailyInc[idx])),
                          color: JweTheme.accentCyan,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          barWidth: 2,
                        ),
                        LineChartBarData(
                          spots: List.generate(8, (idx) => FlSpot((29 + idx).toDouble(), regIncome.predict((29 + idx).toDouble()))),
                          color: JweTheme.accentCyan,
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                          barWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                        LineChartBarData(
                          spots: List.generate(30, (idx) => FlSpot(idx.toDouble(), dailyExp[idx])),
                          color: JweTheme.accentRed,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          barWidth: 2,
                        ),
                        LineChartBarData(
                          spots: List.generate(8, (idx) => FlSpot((29 + idx).toDouble(), regExpense.predict((29 + idx).toDouble()))),
                          color: JweTheme.accentRed,
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                          barWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: JweTheme.lineSoft.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOMORROW EXPECTED INC', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text('$_currency${tomorrowIncome.toStringAsFixed(2)}', style: GoogleFonts.saira(color: JweTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(regIncome.slope >= 0 ? 'TRENDING UP (+₹${regIncome.slope.toStringAsFixed(1)}/d)' : 'TRENDING DOWN (-₹${regIncome.slope.abs().toStringAsFixed(1)}/d)', style: GoogleFonts.jetBrainsMono(color: regIncome.slope >= 0 ? JweTheme.accentTeal : JweTheme.accentRed, fontSize: 7, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOMORROW EXPECTED EXP', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text('$_currency${tomorrowExpense.toStringAsFixed(2)}', style: GoogleFonts.saira(color: JweTheme.accentRed, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(regExpense.slope >= 0 ? 'TRENDING UP (+₹${regExpense.slope.toStringAsFixed(1)}/d)' : 'TRENDING DOWN (-₹${regExpense.slope.abs().toStringAsFixed(1)}/d)', style: GoogleFonts.jetBrainsMono(color: regExpense.slope >= 0 ? JweTheme.accentRed : JweTheme.accentTeal, fontSize: 7, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'CATEGORY EXPENDITURE BREAKDOWN',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HudPanel(
            clip: HudClip.br,
            accent: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (expenseCategories.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('NO MTD EXPENSE DATA FOUND', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10)),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxSpend * 1.15,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < expenseCategories.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      expenseCategories[idx].name.substring(0, math.min(4, expenseCategories[idx].name.length)).toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(fontSize: 8, color: JweTheme.textMuted, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(expenseCategories.length, (index) {
                          final cat = expenseCategories[index];
                          final spent = catMTDSpend[cat.id] ?? 0.0;
                          final color = Color(int.parse('0xFF${cat.colorHex}'));
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: spent,
                                color: color,
                                width: 16,
                                borderRadius: BorderRadius.zero,
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxSpend * 1.15,
                                  color: JweTheme.bgBase,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...expenseCategories.map((cat) {
                    final spent = catMTDSpend[cat.id] ?? 0.0;
                    final color = Color(int.parse('0xFF${cat.colorHex}'));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, color: color),
                          const SizedBox(width: 8),
                          Text(cat.name.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 10, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$_currency${spent.toStringAsFixed(2)}', style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CatRow {
  final FinanceCategory cat;
  final double amount;
  final double pct;
  _CatRow(this.cat, this.amount, this.pct);
}

class _ExpenditureBars extends StatelessWidget {
  final List<double> daily;
  const _ExpenditureBars({required this.daily});

  @override
  Widget build(BuildContext context) {
    final maxV = daily.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(daily.length, (i) {
        final isLast = i == daily.length - 1;
        final v = daily[i];
        final pct = maxV > 0 ? v / maxV : 0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == daily.length - 1 ? 0 : 2),
            child: FractionallySizedBox(
              heightFactor: math.max(0.03, pct.toDouble()),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: isLast ? JweTheme.accentAmber : JweTheme.accentAmber.withValues(alpha: 0.40),
                  boxShadow: isLast ? [BoxShadow(color: JweTheme.accentAmber.withValues(alpha: 0.5), blurRadius: 5)] : null,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LedgerActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _LedgerActionBtn({required this.label, required this.icon, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.saira(
                  color: accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6,
                )),
          ]),
        ),
      ),
    );
  }
}

class _ResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.45)),
        ),
        child: Icon(MdiIcons.refresh, size: 16, color: JweTheme.accentRed),
      ),
    );
  }
}

/// Income vs Expense dual bar replacing the old budget progress bar.
class _IncomeExpenseBar extends StatelessWidget {
  final double income;
  final double expense;

  const _IncomeExpenseBar({required this.income, required this.expense});

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final total = income + expense;
    final incFrac = total > 0 ? (income / total).clamp(0.0, 1.0) : 0.5;
    final expFrac = 1.0 - incFrac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INCOME VS EXPENSE · 30D',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.6,
            )),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 5,
                    width: w * incFrac,
                    color: JweTheme.accentTeal,
                  ),
                  Container(
                    height: 5,
                    width: w * expFrac,
                    color: JweTheme.accentRed.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(children: [
                Container(width: 8, height: 8, color: JweTheme.accentTeal),
                const SizedBox(width: 4),
                Text('IN ₹${_fmt(income)}',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 14),
                Container(width: 8, height: 8, color: JweTheme.accentRed),
                const SizedBox(width: 4),
                Text('OUT ₹${_fmt(expense)}',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentRed, fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                Text(
                  income > expense ? '+₹${_fmt(income - expense)}' : '-₹${_fmt(expense - income)}',
                  style: GoogleFonts.jetBrainsMono(
                    color: income >= expense ? JweTheme.accentTeal : JweTheme.accentRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ],
          );
        }),
      ],
    );
  }
}

/// Projected income for the current month.
class _ProjectedIncomeCard extends StatelessWidget {
  final double monthIncome;
  final double projectedIncome;
  final double monthExpense;
  final int daysElapsed;
  final int daysInMonth;
  final String currency;

  const _ProjectedIncomeCard({
    required this.monthIncome,
    required this.projectedIncome,
    required this.monthExpense,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.currency,
  });

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final pct = daysElapsed / daysInMonth;
    final surplus = projectedIncome - monthExpense * (daysInMonth / daysElapsed.clamp(1, daysInMonth));
    final isPositive = surplus >= 0;

    return HudPanel(
      clip: HudClip.br,
      accent: JweTheme.accentTeal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Icon(MdiIcons.trendingUp, size: 22, color: JweTheme.accentTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PROJECTED INCOME',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentTeal, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.6,
                )),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '$currency${_fmt(projectedIncome)}',
                style: GoogleFonts.saira(
                  color: JweTheme.textWhite, fontSize: 22, fontWeight: FontWeight.w700, height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'this month',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted, fontSize: 9, letterSpacing: 0.8,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text('Actual so far: $currency${_fmt(monthIncome)} · Day $daysElapsed/$daysInMonth',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted, fontSize: 9, letterSpacing: 0.6,
                  )),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${(pct * 100).round()}%',
            style: GoogleFonts.saira(
              color: JweTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.w700,
            ),
          ),
          Text('month',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted, fontSize: 8, letterSpacing: 0.8,
              )),
          const SizedBox(height: 4),
          Text(
            isPositive ? '+${_fmt(surplus.abs())}' : '-${_fmt(surplus.abs())}',
            style: GoogleFonts.jetBrainsMono(
              color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('net est.',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted, fontSize: 8,
              )),
        ]),
      ]),
    );
  }
}

class LinearRegression {
  final double slope;
  final double intercept;

  LinearRegression(this.slope, this.intercept);

  static LinearRegression calculate(List<double> values) {
    final n = values.length;
    if (n == 0) return LinearRegression(0, 0);

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = values[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final num = n * sumXY - sumX * sumY;
    final den = n * sumXX - sumX * sumX;
    if (den == 0) return LinearRegression(0, sumY / n);

    final slope = num / den;
    final intercept = (sumY - slope * sumX) / n;
    return LinearRegression(slope, intercept);
  }

  double predict(double x) => slope * x + intercept;
}
