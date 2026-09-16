import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/screens/trading/trading_guide_sheet.dart';
import 'package:missions/src/screens/trading/trading_order_sheet.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TradingAssetDetailScreen extends StatelessWidget {
  final CryptoSymbol symbol;
  final PaperTradingProvider provider;

  const TradingAssetDetailScreen({
    super.key,
    required this.symbol,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([provider, provider.marketService]),
      builder: (context, _) {
        final tick = provider.marketService.getTick(symbol.rawSymbol);
        final history = provider.marketService.getHistory(symbol.rawSymbol);
        final holding = provider.getHolding(symbol.rawSymbol);
        final pendingForCoin = provider.pendingOrders
            .where((o) => o.symbol.toUpperCase() == symbol.rawSymbol.toUpperCase())
            .toList();

        final currentPriceUSDT = tick?.price ?? holding?.avgBuyPriceUSDT ?? 0.0;
        final priceChangePercent = tick?.changePercent24h ?? 0.0;
        final isPositive = priceChangePercent >= 0;
        final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

        final priceInINR = currentPriceUSDT * provider.usdtToInrRate;

        return Scaffold(
          backgroundColor: JweTheme.bgCanvas,
          appBar: AppBar(
            backgroundColor: JweTheme.bgCanvas,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: JweTheme.textWhite, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(symbol.icon, color: symbol.brandColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  symbol.pairLabel,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              _ConnectionStatusDot(status: provider.marketService.status),
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: JweTheme.accentCyan, size: 20),
                onPressed: () => TradingGuideSheet.show(context),
                tooltip: 'Market Mechanics Guide',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Big Centered Live Price
                      Center(
                        child: Column(
                          children: [
                            Text(
                              symbol.name.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\$${currentPriceUSDT.toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textWhite,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '~ ${inrFormat.format(priceInINR)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMid,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isPositive ? JweTheme.accentTeal : JweTheme.accentRed)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: (isPositive ? JweTheme.accentTeal : JweTheme.accentRed)
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                        color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                        size: 16,
                                      ),
                                      Text(
                                        '${priceChangePercent.abs().toStringAsFixed(2)}%',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 24h Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: JweTheme.panel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              label: '24H HIGH',
                              value: '\$${(tick?.high24h ?? 0).toStringAsFixed(2)}',
                            ),
                            _StatItem(
                              label: '24H LOW',
                              value: '\$${(tick?.low24h ?? 0).toStringAsFixed(2)}',
                            ),
                            _StatItem(
                              label: '24H VOL',
                              value: NumberFormat.compact().format(tick?.volume24h ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Price Movement Line Chart
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: JweTheme.panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '// REALTIME TICK MOVEMENT',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE STREAM',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: _PriceLineChart(
                                history: history,
                                isPositive: isPositive,
                                currentPrice: currentPriceUSDT,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // User's Position Card
                      if (holding != null) ...[
                        Text(
                          'YOUR ACTIVE POSITION',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: JweTheme.panel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('HOLDING', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 10.5)),
                                      Text(
                                        '${holding.quantity.toStringAsFixed(symbol.decimals)} ${symbol.baseAsset}',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textWhite,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('CURRENT VALUE', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 10.5)),
                                      Text(
                                        inrFormat.format(holding.currentValueINR(currentPriceUSDT, provider.usdtToInrRate)),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textWhite,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'AVG BUY: \$${holding.avgBuyPriceUSDT.toStringAsFixed(2)}',
                                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                                  ),
                                  Text(
                                    'P&L: ${holding.pnlINR(currentPriceUSDT, provider.usdtToInrRate) >= 0 ? '+' : ''}${inrFormat.format(holding.pnlINR(currentPriceUSDT, provider.usdtToInrRate))} (${holding.pnlPercent(currentPriceUSDT, provider.usdtToInrRate).toStringAsFixed(2)}%)',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: holding.pnlINR(currentPriceUSDT, provider.usdtToInrRate) >= 0
                                          ? JweTheme.accentTeal
                                          : JweTheme.accentRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Pending Limit Orders for this Coin
                      if (pendingForCoin.isNotEmpty) ...[
                        Text(
                          'PENDING LIMIT ORDERS (${pendingForCoin.length})',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingForCoin.map((order) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: JweTheme.panel2,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: JweTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (order.isBuy ? JweTheme.accentTeal : JweTheme.accentRed)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.side.name.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: order.isBuy ? JweTheme.accentTeal : JweTheme.accentRed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${order.quantity.toStringAsFixed(symbol.decimals)} ${symbol.baseAsset} @ \$${order.targetPriceUSDT.toStringAsFixed(2)}',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textWhite,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Est. ${inrFormat.format(order.totalINR)}',
                                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => provider.cancelOrder(order.id),
                                  child: Text(
                                    'CANCEL',
                                    style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 9.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Thumb-Friendly BUY & SELL Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  border: Border(top: BorderSide(color: JweTheme.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JweTheme.accentTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          TradingOrderSheet.show(
                            context: context,
                            symbol: symbol,
                            provider: provider,
                            initialSide: OrderSide.buy,
                          );
                        },
                        child: Text(
                          'BUY',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JweTheme.accentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          TradingOrderSheet.show(
                            context: context,
                            symbol: symbol,
                            provider: provider,
                            initialSide: OrderSide.sell,
                          );
                        },
                        child: Text(
                          'SELL',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PriceLineChart extends StatelessWidget {
  final List<double> history;
  final bool isPositive;
  final double currentPrice;

  const _PriceLineChart({
    required this.history,
    required this.isPositive,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = [];
    if (history.length >= 2) {
      for (int i = 0; i < history.length; i++) {
        spots.add(FlSpot(i.toDouble(), history[i]));
      }
    } else {
      spots = [
        FlSpot(0, currentPrice),
        FlSpot(1, currentPrice),
      ];
    }

    final chartColor = isPositive ? JweTheme.accentTeal : JweTheme.accentRed;

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final delta = (maxY - minY).abs();
    final padding = delta > 0 ? delta * 0.15 : (minY * 0.01).clamp(0.1, 100.0);

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: JweTheme.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(value < 100 ? 1 : 0)}',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => JweTheme.panel2,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(2)}',
                  GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: chartColor,
            barWidth: 2.2,
            isCurved: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  chartColor.withValues(alpha: 0.25),
                  chartColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusDot extends StatelessWidget {
  final MarketConnectionStatus status;

  const _ConnectionStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case MarketConnectionStatus.connected:
        color = JweTheme.accentTeal;
        label = 'LIVE';
        break;
      case MarketConnectionStatus.connecting:
        color = JweTheme.accentCyan;
        label = 'CONNECTING';
        break;
      case MarketConnectionStatus.reconnecting:
        color = JweTheme.accentAmber;
        label = 'RECONNECTING';
        break;
      case MarketConnectionStatus.disconnected:
        color = JweTheme.accentRed;
        label = 'OFFLINE';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
