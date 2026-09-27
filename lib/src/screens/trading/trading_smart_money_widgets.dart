import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/models/trading_psychology_models.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/trading_risk_math.dart' as risk_math;

/// Shared small pieces for the Smart Money Protocol layer: the portfolio
/// stats card + equity sparkline, the per-holding stop row, the journal tab
/// and its review dialog. Kept out of the 1.5k-line screens so those diffs
/// stay surgical.

// ── Portfolio: Smart Money stats card ───────────────────────────────────────

class SmartMoneyStatsCard extends StatelessWidget {
  final PaperTradingProvider provider;
  final Map<String, CryptoPriceTick> ticks;

  const SmartMoneyStatsCard({super.key, required this.provider, required this.ticks});

  @override
  Widget build(BuildContext context) {
    final stats = provider.statsFor(ticks);

    if (stats.closedTrades == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: JweTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, size: 15, color: JweTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Close your first trade to unlock expectancy stats.',
                style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
    }

    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    final expectancyLabel = stats.expectancyR != null
        ? '${inrFormat.format(stats.expectancyINR)}  (${stats.expectancyR! >= 0 ? '+' : ''}${stats.expectancyR!.toStringAsFixed(2)}R)'
        : inrFormat.format(stats.expectancyINR);

    final ratioLabel = stats.avgLossINR > 0 ? '${stats.winLossRatio.toStringAsFixed(1)} : 1' : '—';
    final profitFactorLabel = stats.profitFactor.isInfinite ? '∞' : stats.profitFactor.toStringAsFixed(2);

    final streakLabel = stats.currentStreak == 0
        ? '—'
        : (stats.currentStreak > 0 ? '+${stats.currentStreak}' : '${stats.currentStreak}');
    final streakColor = stats.currentStreak > 0
        ? JweTheme.accentTeal
        : (stats.currentStreak < 0 ? JweTheme.accentRed : JweTheme.textMid);

    final suggested = provider.suggestedRiskPercentFor(ticks);
    final currentValue = provider.totalPortfolioValueINR(ticks);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 13, color: JweTheme.accentCyan),
              const SizedBox(width: 6),
              Text(
                'SMART MONEY STATS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentCyan,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'EXPECTANCY / TRADE',
                  value: expectancyLabel,
                  color: stats.expectancyINR >= 0 ? JweTheme.accentTeal : JweTheme.accentRed,
                ),
              ),
              Expanded(
                child: _StatCell(label: 'AVG WIN : LOSS', value: ratioLabel, color: JweTheme.textWhite),
              ),
              Expanded(
                child: _StatCell(label: 'PROFIT FACTOR', value: profitFactorLabel, color: JweTheme.textWhite),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCell(label: 'STREAK', value: streakLabel, color: streakColor),
              ),
              Expanded(
                child: _StatCell(
                  label: 'DRAWDOWN',
                  value: '${stats.currentDrawdownPercent.toStringAsFixed(1)}%',
                  color: stats.currentDrawdownPercent > 0.5 ? JweTheme.accentAmber : JweTheme.textWhite,
                  caption: 'risk dial: ${suggested.toStringAsFixed(2)}%',
                ),
              ),
              Expanded(
                child: _StatCell(
                  label: 'WIN RATE',
                  value: '${stats.winRate.toStringAsFixed(0)}%',
                  color: JweTheme.textMuted,
                  small: true,
                  caption: 'counts less than the size of your wins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: EquitySparkline(snapshots: provider.equitySnapshots, currentValue: currentValue),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? caption;
  final bool small;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 7.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: small ? 11 : 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 1),
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 7.2, height: 1.1),
          ),
        ],
      ],
    );
  }
}

// ── Equity curve sparkline ───────────────────────────────────────────────

class EquitySparkline extends StatelessWidget {
  final List<EquitySnapshot> snapshots;
  final double currentValue;

  const EquitySparkline({super.key, required this.snapshots, required this.currentValue});

  @override
  Widget build(BuildContext context) {
    final values = <double>[...snapshots.map((s) => s.valueINR), currentValue];
    if (values.length < 2) values.insert(0, currentValue);
    final isUp = values.last >= values.first;
    final color = isUp ? JweTheme.accentTeal : JweTheme.accentRed;

    return CustomPaint(
      size: Size.infinite,
      painter: _EquitySparklinePainter(values: values, color: color),
    );
  }
}

class _EquitySparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _EquitySparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EquitySparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

// ── Tiny reusable chip (GATE x/5, mood label, STOP badge, …) ───────────────

class SmartMoneyTinyChip extends StatelessWidget {
  final String label;
  final Color color;

  const SmartMoneyTinyChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Holding stop row (portfolio card + asset detail screen) ───────────────

class HoldingStopRow extends StatelessWidget {
  final PaperTradingProvider provider;
  final CryptoHolding holding;
  final double currentPrice;
  final bool isIndianAsset;

  const HoldingStopRow({
    super.key,
    required this.provider,
    required this.holding,
    required this.currentPrice,
    required this.isIndianAsset,
  });

  @override
  Widget build(BuildContext context) {
    final currencySymbol = isIndianAsset ? '₹' : '\$';
    final stop = holding.stopPrice;
    final hasStop = stop != null && stop > 0;
    final suggestBreakeven = provider.shouldSuggestBreakeven(holding, currentPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasStop)
          Builder(builder: (context) {
            final belowPct = currentPrice > 0 ? (currentPrice - stop) / currentPrice * 100 : 0.0;
            final riskLeft = risk_math.riskAmountINR(
              entryPrice: currentPrice,
              stopPrice: stop,
              quantity: holding.quantity,
              inrPerUnit: isIndianAsset ? 1.0 : provider.usdtToInrRate,
            );
            return Text(
              'STOP $currencySymbol${stop.toStringAsFixed(2)} (−${belowPct.toStringAsFixed(1)}% below live) · risk left ₹${riskLeft.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 9.5, fontWeight: FontWeight.w600),
            );
          })
        else
          Text(
            'NO STOP — DEFENSE OFF',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _StopActionChip(
                label: 'B/E',
                highlighted: suggestBreakeven,
                onTap: () => _runStopAction(context, () => provider.raiseStopToBreakeven(holding.symbol)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StopActionChip(
                label: 'TRAIL 7%',
                onTap: () => _runStopAction(context, () => provider.trailStop(holding.symbol, 7)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StopActionChip(
                label: 'EDIT',
                onTap: () => showEditStopDialog(context, provider, holding.symbol, stop, currencySymbol),
              ),
            ),
          ],
        ),
        if (holding.plan != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              SmartMoneyTinyChip(
                label: 'GATE ${holding.plan!.checklistScore}/${holding.plan!.checklistTotal}',
                color: JweTheme.accentCyan,
              ),
              if (holding.plan!.mood != null)
                SmartMoneyTinyChip(label: holding.plan!.mood!.label, color: JweTheme.textMuted),
            ],
          ),
        ],
      ],
    );
  }

  void _runStopAction(BuildContext context, TradeExecutionResult Function() action) {
    final result = action();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? JweTheme.accentTeal : JweTheme.accentRed,
      ),
    );
  }
}

class _StopActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _StopActionChip({required this.label, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? JweTheme.accentAmber : JweTheme.textMid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: highlighted ? JweTheme.accentAmber.withValues(alpha: 0.12) : JweTheme.panel2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: highlighted ? JweTheme.accentAmber : JweTheme.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(color: color, fontSize: 8.8, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// Shared "edit protective stop" dialog, used by the holding row, the asset
/// detail screen, and the order sheet's SELL position box.
Future<void> showEditStopDialog(
  BuildContext context,
  PaperTradingProvider provider,
  String symbol,
  double? currentStop,
  String currencySymbol,
) async {
  final controller = TextEditingController(
    text: currentStop != null && currentStop > 0 ? currentStop.toStringAsFixed(2) : '',
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.6), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text(
        'EDIT PROTECTIVE STOP',
        style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Stops only move up. Enter a new stop price for $symbol.',
            style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
            decoration: InputDecoration(
              prefixText: '$currencySymbol ',
              prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 14),
              filled: true,
              fillColor: JweTheme.panel2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: JweTheme.border),
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentAmber, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('SET STOP', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final value = double.tryParse(controller.text);
  if (value == null || value <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid stop price.')),
      );
    }
    return;
  }

  final result = provider.setProtectiveStop(symbol, value);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? JweTheme.accentTeal : JweTheme.accentRed,
      ),
    );
  }
}

// ── Journal tab ─────────────────────────────────────────────────────────

class JournalTab extends StatelessWidget {
  final PaperTradingProvider provider;

  const JournalTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final records = provider.tradeRecords;

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, color: JweTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                'NO CLOSED TRADES YET',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Every exit — manual, limit or stop — lands here with its R-multiple.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: records.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'Judge the decision, not the outcome.',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          );
        }
        return _JournalRecordTile(provider: provider, record: records[index - 1]);
      },
    );
  }
}

class _JournalRecordTile extends StatelessWidget {
  final PaperTradingProvider provider;
  final TradeRecord record;

  const _JournalRecordTile({required this.provider, required this.record});

  @override
  Widget build(BuildContext context) {
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);
    final isWin = record.realizedPnlINR >= 0;
    final rMultiple = record.rMultiple;
    final rLabel = rMultiple == null ? '—' : '${rMultiple >= 0 ? '+' : ''}${rMultiple.toStringAsFixed(1)}R';
    final rColor = rMultiple == null ? JweTheme.textMuted : (rMultiple >= 0 ? JweTheme.accentTeal : JweTheme.accentRed);

    final period = record.holdingPeriod;
    final periodLabel = period.inDays > 0
        ? '${period.inDays}d ${period.inHours % 24}h'
        : '${period.inHours}h ${period.inMinutes % 60}m';

    final String exitLabel;
    final Color exitColor;
    switch (record.exitReason) {
      case TradeExitReason.manual:
        exitLabel = 'MANUAL';
        exitColor = JweTheme.textMuted;
        break;
      case TradeExitReason.stopHit:
        exitLabel = 'STOP HIT';
        exitColor = JweTheme.accentRed;
        break;
      case TradeExitReason.limitFilled:
        exitLabel = 'LIMIT';
        exitColor = JweTheme.accentAmber;
        break;
    }

    final asset = TradingAsset.fromSymbol(record.symbol);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  asset.displaySymbol,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: JweTheme.panel2, borderRadius: BorderRadius.circular(3)),
                child: Text(
                  asset.exchange,
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: rColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
                child: Text(rLabel, style: GoogleFonts.jetBrainsMono(color: rColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${isWin ? '+' : ''}${inrFormat.format(record.realizedPnlINR)} (${record.realizedPnlPercent.toStringAsFixed(1)}%)',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: isWin ? JweTheme.accentTeal : JweTheme.accentRed,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: exitColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(exitLabel, style: GoogleFonts.jetBrainsMono(color: exitColor, fontSize: 8.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 11, color: JweTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(periodLabel, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5)),
                ],
              ),
              if (record.plan?.mood != null)
                SmartMoneyTinyChip(label: record.plan!.mood!.label, color: JweTheme.textMuted),
              if (record.plan != null)
                SmartMoneyTinyChip(
                  label: 'GATE ${record.plan!.checklistScore}/${record.plan!.checklistTotal}',
                  color: JweTheme.accentCyan,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: record.isReviewed
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: JweTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'GRADE ${record.processGrade ?? '—'}',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.accentTeal, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showTradeReviewDialog(context, provider, record),
                    child: Text('REVIEW', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Post-trade review dialog: judge the decision, not the outcome.
Future<void> showTradeReviewDialog(BuildContext context, PaperTradingProvider provider, TradeRecord record) async {
  bool? followedPlan = record.followedPlan;
  String? grade = record.processGrade;
  final lessonController = TextEditingController(text: record.lesson ?? '');

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.6), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'POST-TRADE REVIEW',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DID I FOLLOW MY PLAN?',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: 'YES',
                        selected: followedPlan == true,
                        onTap: () => setState(() => followedPlan = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegmentButton(
                        label: 'NO',
                        selected: followedPlan == false,
                        onTap: () => setState(() => followedPlan = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'PROCESS GRADE',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Row(
                  children: ['A', 'B', 'C'].map((g) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _SegmentButton(label: g, selected: grade == g, onTap: () => setState(() => grade = g)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'A = followed plan & risk · B = minor drift · C = broke a rule',
                  style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 9.5, height: 1.3),
                ),
                const SizedBox(height: 14),
                Text(
                  'LESSON',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: lessonController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: JweTheme.textWhite, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'What would you tell yourself before the next one?',
                    hintStyle: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11),
                    filled: true,
                    fillColor: JweTheme.panel2,
                    contentPadding: const EdgeInsets.all(10),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentCyan,
                foregroundColor: JweTheme.isLight ? Colors.white : Colors.black,
              ),
              onPressed: () async {
                await provider.reviewTrade(
                  record.id,
                  followedPlan: followedPlan,
                  processGrade: grade,
                  lesson: lessonController.text.trim().isEmpty ? null : lessonController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('SAVE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? JweTheme.accentCyan.withValues(alpha: 0.18) : JweTheme.panel2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? JweTheme.accentCyan : JweTheme.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? JweTheme.accentCyan : JweTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
