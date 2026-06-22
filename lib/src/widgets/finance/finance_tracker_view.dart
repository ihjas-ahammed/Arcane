import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/finance_helpers.dart';
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
      padding: EdgeInsets.only(bottom: bottomPadding),
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
                : Column(children: List.generate(cats.length, (i) {
                    final r = cats[i];
                    final color = Color(int.parse('0xFF${r.cat.colorHex}'));
                    final tone = _toneFor(color);
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < cats.length - 1 ? 12 : 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(r.cat.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12, color: JweTheme.textWhite, fontWeight: FontWeight.w500,
                                )),
                          ),
                          Text('$_currency${_compactMoney(r.amount)} · ${r.pct.round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.6,
                              )),
                        ]),
                        const SizedBox(height: 4),
                        HudBar(value: r.pct.clamp(0, 100), max: 40, tone: tone, height: 3),
                      ]),
                    );
                  })),
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
            child: Column(children: provider.transactions.take(40).map((tx) {
              final cat = provider.categories.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => FinanceCategory(id: '', name: 'Unknown', colorHex: 'FFFFFF', iconName: 'help', isIncomeCategory: tx.isIncome),
              );
              final color = Color(int.parse('0xFF${cat.colorHex}'));
              return Dismissible(
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
                          Text(cat.name.toUpperCase(),
                              style: GoogleFonts.saira(
                                color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4,
                              )),
                          if (tx.note.isNotEmpty)
                            Text(tx.note,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: JweTheme.textMuted, fontSize: 11,
                                )),
                          Text(DateFormat('dd MMM · HH:mm').format(tx.timestamp).toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted, fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w500,
                              )),
                        ]),
                      ),
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
              );
            }).toList()),
          ),
      ]),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _compactMoney(double v) {
    if (v >= 100000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }
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
