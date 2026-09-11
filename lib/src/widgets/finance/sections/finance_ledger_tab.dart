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
import 'package:missions/src/widgets/finance/sections/finance_dialogs.dart';
import 'package:missions/src/widgets/finance/sections/finance_widgets_common.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class FinanceLedgerTab extends StatelessWidget {
  final AppProvider provider;
  final String currency;
  final Function(bool isIncome) onAddTransaction;
  final Function({FinanceAccount? existing}) onAddAccount;

  const FinanceLedgerTab({
    super.key,
    required this.provider,
    this.currency = '₹',
    required this.onAddTransaction,
    required this.onAddAccount,
  });

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
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
          final dayIdx =
              today.difference(DateTime(ts.year, ts.month, ts.day)).inDays;
          final i = 29 - dayIdx;
          if (i >= 0 && i < 30) dailyExp[i] += t.amount;
        }
      } else {
        if (!ts.isBefore(thirtyAgo)) income30d += t.amount;
      }
    }

    final avg30d = expense30d / 30.0;

    var monthIncome = 0.0;
    for (var t in provider.transactions) {
      if (t.isIncome && !t.timestamp.isBefore(monthStart)) {
        monthIncome += t.amount;
      }
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
          return FinanceCatRow(c, amt, pct.toDouble());
        })
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding =
        isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding + 130.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Balance hero ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: HudPanel(
              clip: HudClip.both,
              accent: JweTheme.accentAmber,
              allBrackets: true,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: JweTheme.lineAmber,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '// LIQUID BALANCE',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const Spacer(),
                        HudDot(tone: HudTone.amber),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currency${compactMoney(balance)}',
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
                                    color: income30d > expense30d
                                        ? JweTheme.accentTeal
                                        : JweTheme.accentRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: HudStat(
                                label: 'Today',
                                value: '$currency${compactMoney(todaySpend)}',
                                tone: HudTone.cyan,
                                size: 18,
                              ),
                            ),
                            Expanded(
                              child: HudStat(
                                label: 'MTD',
                                value: '$currency${compactMoney(monthSpend)}',
                                tone: HudTone.amber,
                                size: 18,
                              ),
                            ),
                            Expanded(
                              child: HudStat(
                                label: 'AVG/30D',
                                value: '$currency${compactMoney(avg30d * 30)}',
                                tone: HudTone.cyan,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FinanceIncomeExpenseBar(
                          income: income30d,
                          expense: expense30d,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Projected income card ───────────────────
          if (monthIncome > 0 || projectedMonthIncome > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: FinanceProjectedIncomeCard(
                monthIncome: monthIncome,
                projectedIncome: projectedMonthIncome,
                monthExpense: monthSpend,
                daysElapsed: daysElapsed,
                daysInMonth: daysInMonth,
                currency: currency,
              ),
            ),

          // ── Action buttons ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FinanceLedgerActionBtn(
                    label: 'INCOME',
                    icon: MdiIcons.plus,
                    accent: JweTheme.accentTeal,
                    onTap: () => onAddTransaction(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FinanceLedgerActionBtn(
                    label: 'EXPENSE',
                    icon: MdiIcons.minus,
                    accent: JweTheme.accentRed,
                    onTap: () => onAddTransaction(false),
                  ),
                ),
                const SizedBox(width: 8),
                FinanceResetBtn(
                  onTap: () => FinanceDialogs.showConfirmResetDialog(context),
                ),
              ],
            ),
          ),

          // ── Accounts ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: HudSectionHead(
              label: 'ACCOUNTS',
              code: hasAccounts
                  ? '${provider.accounts.length} LINKED'
                  : 'NONE',
              accent: HudTone.cyan,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                ...provider.accounts.map((acc) {
                  final color = Color(int.parse('0xFF${acc.colorHex}'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: HudPanel(
                      clip: HudClip.br,
                      accent: color,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              border: Border.all(
                                color: color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              FinanceHelpers.getIconData(acc.iconName),
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.name.toUpperCase(),
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  acc.type.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 9,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$currency${compactMoney(acc.balance)}',
                                style: GoogleFonts.saira(
                                  color: color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        FinanceDialogs.showChangeBalanceDialog(
                                            context, acc),
                                    child: Text(
                                      'BALANCE',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentAmber,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => onAddAccount(existing: acc),
                                    child: Text(
                                      'EDIT',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => provider.financeActions
                                        .deleteAccount(acc.id),
                                    child: Text(
                                      'DEL',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentRed,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => onAddAccount(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: JweTheme.accentCyan, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'ADD ACCOUNT',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 30-day expenditure ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: HudPanel(
              clip: HudClip.br,
              accent: JweTheme.accentAmber,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '// 30-DAY EXPENDITURE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: JweTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'μ $currency${compactMoney(avg30d)}/d',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: JweTheme.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 70,
                    child: FinanceExpenditureBars(daily: dailyExp),
                  ),
                ],
              ),
            ),
          ),

          // ── Category breakdown ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
            child:
                const HudSectionHead(label: 'CATEGORY BREAKDOWN', code: 'MTD'),
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
                      child: Text(
                        'NO EXPENSES THIS MONTH',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: JweTheme.textMuted,
                          letterSpacing: 1.4,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                    final color = Color(
                                        int.parse('0xFF${r.cat.colorHex}'));
                                    return PieChartSectionData(
                                      color: color,
                                      value: r.amount,
                                      title: '',
                                      radius: 12,
                                      borderSide: const BorderSide(
                                        color: Colors.transparent,
                                        width: 0,
                                      ),
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
                                  '$currency${compactMoney(monthSpend)}',
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
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(cats.length, (i) {
                              final r = cats[i];
                              final color =
                                  Color(int.parse('0xFF${r.cat.colorHex}'));
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < cats.length - 1 ? 10 : 0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                          '$currency${compactMoney(r.amount)} · ${r.pct.round()}%',
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
                  child: Text(
                    'NO TRANSACTIONS RECORDED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: JweTheme.textMuted,
                      letterSpacing: 1.4,
                    ),
                  ),
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
                    final txDate = DateTime(
                      tx.timestamp.year,
                      tx.timestamp.month,
                      tx.timestamp.day,
                    );
                    if (lastDate == null || lastDate != txDate) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                MdiIcons.chevronDoubleRight,
                                size: 10,
                                color: JweTheme.textMuted,
                              ),
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
                                  color: JweTheme.lineSoft
                                      .withValues(alpha: 0.15),
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
                      orElse: () => FinanceCategory(
                        id: '',
                        name: 'Unknown',
                        colorHex: 'FFFFFF',
                        iconName: 'help',
                        isIncomeCategory: tx.isIncome,
                      ),
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
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => provider.financeActions
                            .deleteTransaction(tx.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(
                                12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: JweTheme.panel,
                              border: Border(
                                left: BorderSide(
                                  color: tx.isIncome
                                      ? JweTheme.accentTeal
                                      : JweTheme.accentRed,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.40),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    FinanceHelpers.getIconData(cat.iconName),
                                    color: color,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.name.toUpperCase(),
                                              style: GoogleFonts.saira(
                                                color: JweTheme.textWhite,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) =>
                                                    AddCategoryDialog(
                                                  isIncome:
                                                      cat.isIncomeCategory,
                                                  category: cat,
                                                ),
                                              );
                                            },
                                            child: Icon(
                                              MdiIcons.pencilOutline,
                                              size: 12,
                                              color: JweTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (tx.note.isNotEmpty)
                                        Text(
                                          tx.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: JweTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(tx.timestamp)
                                            .toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textMuted,
                                          fontSize: 9,
                                          letterSpacing: 1.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tx.isIncome ? '+' : '−'}$currency${compactMoney(tx.amount)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: tx.isIncome
                                        ? JweTheme.accentTeal
                                        : JweTheme.accentRed,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return widgets;
                })(),
              ),
            ),
        ],
      ),
    );
  }
}
