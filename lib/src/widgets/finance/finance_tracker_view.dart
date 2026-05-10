import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/finance_helpers.dart';
import 'package:missions/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Operator HUD wallet — balance hero, 30-day expenditure sparkline,
/// category breakdown, transaction ledger.
class FinanceTrackerView extends StatefulWidget {
  const FinanceTrackerView({super.key});

  @override
  State<FinanceTrackerView> createState() => _FinanceTrackerViewState();
}

class _FinanceTrackerViewState extends State<FinanceTrackerView> {
  static const String _currency = '₹'; // ₹

  void _showAddTransactionDialog(BuildContext context, bool isIncome) {
    showDialog(context: context, builder: (_) => AddTransactionDialog(isIncome: isIncome));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final balance = provider.financeActions.currentBalance;

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
    final monthBudget = avg30d * 30; // soft "cap" = 30d trailing avg
    final monthPct = monthBudget > 0 ? (monthSpend / monthBudget) * 100 : 0.0;

    // Category MTD breakdown (expenses only)
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

    // Savings goal pick (first non-empty target)
    final goals = provider.savingsGoals;
    final hasGoal = goals.isNotEmpty;
    final goal = hasGoal ? goals.first : null;
    double savePct = 0;
    int monthsToTarget = 0;
    double velocity = 0;
    if (goal != null && goal.targetAmount > 0) {
      savePct = (goal.currentAmount / goal.targetAmount) * 100;
      // velocity from logs over total elapsed months
      final months = math.max(1, now.difference(goal.createdAt).inDays / 30.0);
      velocity = goal.currentAmount / months;
      final remaining = math.max(0.0, goal.targetAmount - goal.currentAmount);
      monthsToTarget = velocity > 0 ? (remaining / velocity).ceil() : 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
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
                decoration: const BoxDecoration(
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
                  Text('BUDGET TRAJECTORY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.6,
                      )),
                  const SizedBox(height: 6),
                  HudProgressBar(
                    value: monthPct.clamp(0, 100).toDouble(),
                    tone: monthPct > 80 ? HudTone.red : HudTone.amber,
                    segments: 28,
                    height: 5,
                    showLabel: true,
                  ),
                ]),
              ),
            ]),
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

        // ── Savings protocol ───────────────────────
        if (hasGoal) ...[
          const HudSectionHead(label: 'SAVINGS PROTOCOL', code: 'LONG-RANGE', accent: HudTone.cyan),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: HudPanel(
              clip: HudClip.both,
              accent: JweTheme.accentCyan,
              allBrackets: true,
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                HudRing(
                  value: savePct.clamp(0, 100),
                  size: 78,
                  stroke: 6,
                  tone: HudTone.cyan,
                  label: '${savePct.round()}',
                  sub: '%',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(goal!.name.toUpperCase(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.saira(
                          color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 4),
                    HudDataRow(
                      label: 'Current',
                      value: '$_currency${_compactMoney(goal.currentAmount)}',
                      tone: HudTone.cyan,
                    ),
                    HudDataRow(
                      label: 'Target',
                      value: '$_currency${_compactMoney(goal.targetAmount)}',
                    ),
                    HudDataRow(
                      label: 'Velocity',
                      value: '$_currency${_compactMoney(velocity)}/m',
                      accent: true,
                    ),
                    HudDataRow(
                      label: 'ETA',
                      value: monthsToTarget > 0 ? '+$monthsToTarget MO' : '—',
                      tone: HudTone.cyan,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ],

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
