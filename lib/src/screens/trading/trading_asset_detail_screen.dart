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

class TradingAssetDetailScreen extends StatefulWidget {
  final TradingAsset asset;
  final PaperTradingProvider provider;

  TradingAssetDetailScreen({
    super.key,
    TradingAsset? asset,
    CryptoSymbol? symbol,
    required this.provider,
  }) : asset = asset ??
            (symbol != null
                ? TradingAsset.fromCryptoSymbol(symbol)
                : TradingAsset.fromCryptoSymbol(CryptoSymbol.btc));

  @override
  State<TradingAssetDetailScreen> createState() => _TradingAssetDetailScreenState();
}

class _TradingAssetDetailScreenState extends State<TradingAssetDetailScreen> {
  TradingTimeframe _selectedTimeframe = TradingTimeframe.oneDay;
  HistoricalPriceSummary? _historySummary;
  bool _isLoadingHistory = false;
  String? _historyError;

  ShadowGraphType _selectedShadow = ShadowGraphType.none;
  ShadowComparisonSeries? _shadowSeries;
  bool _isLoadingShadow = false;

  @override
  void initState() {
    super.initState();
    widget.provider.marketService.addPinnedSymbol(widget.asset.symbol);
    _loadHistoricalData();
  }

  @override
  void dispose() {
    widget.provider.marketService.removePinnedSymbol(widget.asset.symbol);
    super.dispose();
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final summary = await widget.provider.marketService.fetchHistoricalData(
        widget.asset.symbol,
        _selectedTimeframe.apiValue,
      );
      if (mounted) {
        setState(() {
          _historySummary = summary;
          _isLoadingHistory = false;
        });
        if (_selectedShadow != ShadowGraphType.none) {
          _loadShadowData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Could not load historical data: $e';
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadShadowData() async {
    if (_selectedShadow == ShadowGraphType.none) {
      if (mounted) {
        setState(() {
          _shadowSeries = null;
          _isLoadingShadow = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingShadow = true;
    });

    try {
      final series = await widget.provider.marketService.fetchShadowData(
        symbol: widget.asset.symbol,
        timeframe: _selectedTimeframe,
        type: _selectedShadow,
        baseSummary: _historySummary,
      );
      if (mounted) {
        setState(() {
          _shadowSeries = series;
          _isLoadingShadow = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingShadow = false;
        });
      }
    }
  }

  void _onTimeframeSelected(TradingTimeframe tf) {
    if (_selectedTimeframe == tf) return;
    setState(() {
      _selectedTimeframe = tf;
    });
    _loadHistoricalData();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.provider, widget.provider.marketService]),
      builder: (context, _) {
        final tick = widget.provider.marketService.getTick(widget.asset.symbol);
        final liveHistory = widget.provider.marketService.getHistory(widget.asset.symbol);
        final holding = widget.provider.getHolding(widget.asset.symbol);
        final pendingForAsset = widget.provider.pendingOrders
            .where((o) => o.symbol.toUpperCase() == widget.asset.symbol.toUpperCase())
            .toList();

        final currentPrice = tick?.price ?? holding?.avgBuyPriceUSDT ?? 0.0;
        final priceChangePercent = tick?.changePercent24h ??
            _historySummary?.periodReturnPercent ??
            0.0;
        final isPositive = priceChangePercent >= 0;
        final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

        final priceInINR = widget.asset.isIndianAsset
            ? currentPrice
            : currentPrice * widget.provider.usdtToInrRate;

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
                Icon(widget.asset.icon, color: widget.asset.brandColor, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.asset.displaySymbol,
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: JweTheme.panel2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: JweTheme.border),
                          ),
                          child: Text(
                            widget.asset.exchange,
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.asset.name,
                      style: GoogleFonts.inter(
                        color: JweTheme.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              _ConnectionStatusDot(
                status: widget.asset.isIndianAsset
                    ? (widget.provider.marketService.isIndianMarketOpen
                        ? MarketConnectionStatus.connected
                        : MarketConnectionStatus.disconnected)
                    : widget.provider.marketService.status,
                labelOverride: widget.asset.isIndianAsset
                    ? (widget.provider.marketService.isIndianMarketOpen ? 'NSE LIVE' : 'NSE CLOSED')
                    : null,
              ),
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
                              widget.asset.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.asset.isIndianAsset
                                  ? inrFormat.format(currentPrice)
                                  : '\$${currentPrice.toStringAsFixed(2)}',
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
                                if (!widget.asset.isIndianAsset) ...[
                                  Text(
                                    '~ ${inrFormat.format(priceInINR)}',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMid,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
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

                      // Timeframe Selector Chips
                      Row(
                        children: TradingTimeframe.values.map((tf) {
                          final isSelected = _selectedTimeframe == tf;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => _onTimeframeSelected(tf),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? JweTheme.accentCyan.withValues(alpha: 0.2)
                                        : JweTheme.panel,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected ? JweTheme.accentCyan : JweTheme.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      tf.label,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: isSelected ? JweTheme.accentCyan : JweTheme.textMuted,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Shadow Comparison Selector Chips
                      Row(
                        children: [
                          Icon(Icons.layers_outlined, color: JweTheme.accentAmber, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            'SHADOW:',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentAmber,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: ShadowGraphType.values.map((st) {
                                  final isSelected = _selectedShadow == st;
                                  final label = st.getContextLabel(_selectedTimeframe);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedShadow = st;
                                        });
                                        _loadShadowData();
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? JweTheme.accentAmber.withValues(alpha: 0.2)
                                              : JweTheme.panel,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isSelected
                                                ? JweTheme.accentAmber
                                                : JweTheme.border,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: GoogleFonts.jetBrainsMono(
                                            color: isSelected ? JweTheme.accentAmber : JweTheme.textMuted,
                                            fontSize: 9.0,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Price Chart Container
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '// ${_selectedTimeframe.title.toUpperCase()}',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (_historySummary != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: (_historySummary!.isPositive
                                                      ? JweTheme.accentTeal
                                                      : JweTheme.accentRed)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              '${_historySummary!.isPositive ? '+' : ''}${_historySummary!.periodReturnPercent.toStringAsFixed(2)}%',
                                              style: GoogleFonts.jetBrainsMono(
                                                color: _historySummary!.isPositive
                                                    ? JweTheme.accentTeal
                                                    : JweTheme.accentRed,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
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
                                          _isLoadingHistory ? 'SYNCING...' : 'LIVE',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_shadowSeries != null && _selectedShadow != ShadowGraphType.none) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 10,
                                            height: 2,
                                            color: JweTheme.accentAmber,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SHADOW',
                                            style: GoogleFonts.jetBrainsMono(
                                              color: JweTheme.accentAmber,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                if ((_shadowSeries != null && _selectedShadow != ShadowGraphType.none) || _isLoadingShadow) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (_shadowSeries != null && _selectedShadow != ShadowGraphType.none)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: JweTheme.accentAmber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.35)),
                                          ),
                                          child: Text(
                                            '${_shadowSeries!.label}: ${_shadowSeries!.isPositive ? '+' : ''}${_shadowSeries!.periodReturnPercent.toStringAsFixed(2)}%',
                                            style: GoogleFonts.jetBrainsMono(
                                              color: JweTheme.accentAmber,
                                              fontSize: 9.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (_isLoadingShadow) ...[
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: JweTheme.accentAmber,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: _buildChartContent(liveHistory, currentPrice, isPositive),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Historical & Market Key Metrics Grid
                      _buildKeyMetricsGrid(tick, currentPrice, inrFormat),
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
                                        '${holding.quantity.toStringAsFixed(widget.asset.decimals)} ${widget.asset.baseAsset}',
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
                                        inrFormat.format(holding.currentValueINR(currentPrice, widget.provider.usdtToInrRate)),
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('AVG BUY PRICE', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 10.5)),
                                      Text(
                                        widget.asset.isIndianAsset
                                            ? inrFormat.format(holding.avgBuyPriceUSDT)
                                            : '\$${holding.avgBuyPriceUSDT.toStringAsFixed(2)}',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textMid,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('UNREALIZED P&L', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 10.5)),
                                      Builder(builder: (_) {
                                        final pnlINR = holding.pnlINR(currentPrice, widget.provider.usdtToInrRate);
                                        final pnlPct = holding.pnlPercent(currentPrice, widget.provider.usdtToInrRate);
                                        final isHoldingPos = pnlINR >= 0;
                                        return Text(
                                          '${isHoldingPos ? '+' : ''}${inrFormat.format(pnlINR)} (${pnlPct.toStringAsFixed(2)}%)',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: isHoldingPos ? JweTheme.accentTeal : JweTheme.accentRed,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Pending Limit Orders for this Asset
                      if (pendingForAsset.isNotEmpty) ...[
                        Text(
                          'PENDING ORDERS (${pendingForAsset.length})',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingForAsset.map((ord) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: JweTheme.panel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: JweTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (ord.isBuy ? JweTheme.accentTeal : JweTheme.accentRed)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            ord.side.name.toUpperCase(),
                                            style: GoogleFonts.jetBrainsMono(
                                              color: ord.isBuy ? JweTheme.accentTeal : JweTheme.accentRed,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${ord.quantity.toStringAsFixed(widget.asset.decimals)} ${widget.asset.baseAsset}',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textWhite,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Target: ${widget.asset.isIndianAsset ? inrFormat.format(ord.targetPriceUSDT) : '\$${ord.targetPriceUSDT.toStringAsFixed(2)}'}',
                                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                                    ),
                                  ],
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: const Size(0, 28),
                                    side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.5)),
                                  ),
                                  onPressed: () {
                                    widget.provider.cancelOrder(ord.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Order cancelled successfully.')),
                                    );
                                  },
                                  child: Text(
                                    'CANCEL',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.accentRed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Trade Actions
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  border: Border(top: BorderSide(color: JweTheme.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: widget.asset.isTradable
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: JweTheme.accentTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  TradingOrderSheet.show(
                                    context: context,
                                    asset: widget.asset,
                                    provider: widget.provider,
                                    initialSide: OrderSide.buy,
                                  );
                                },
                                child: Text(
                                  'BUY ${widget.asset.baseAsset}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                                ),
                                onPressed: () {
                                  TradingOrderSheet.show(
                                    context: context,
                                    asset: widget.asset,
                                    provider: widget.provider,
                                    initialSide: OrderSide.sell,
                                  );
                                },
                                child: Text(
                                  'SELL ${widget.asset.baseAsset}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: JweTheme.panel2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: JweTheme.border),
                          ),
                          child: Center(
                            child: Text(
                              'BENCHMARK INDEX · VIEW ONLY (TRADE CONSTITUENTS)',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartContent(List<double> liveHistory, double currentPrice, bool isPositive) {
    if (_isLoadingHistory && _historySummary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: JweTheme.accentCyan),
            ),
            const SizedBox(height: 12),
            Text(
              'FETCHING REAL HISTORICAL DATA...',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (_historySummary != null && _historySummary!.points.isNotEmpty) {
      return _HistoricalLineChart(
        summary: _historySummary!,
        shadowSeries: _shadowSeries,
        isIndianAsset: widget.asset.isIndianAsset,
      );
    }

    if (_historyError != null && (_historySummary == null || _historySummary!.points.isEmpty)) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: JweTheme.accentAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: JweTheme.accentAmber, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'History stream unavailable. Showing live ticks.',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 9.5),
                  ),
                ),
                InkWell(
                  onTap: _loadHistoricalData,
                  child: Text(
                    'RETRY',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _PriceLineChart(
              history: liveHistory,
              isPositive: isPositive,
              currentPrice: currentPrice,
              isIndianAsset: widget.asset.isIndianAsset,
            ),
          ),
        ],
      );
    }

    // Fallback to live intraday tick movement
    return _PriceLineChart(
      history: liveHistory,
      isPositive: isPositive,
      currentPrice: currentPrice,
      isIndianAsset: widget.asset.isIndianAsset,
    );
  }

  Widget _buildKeyMetricsGrid(CryptoPriceTick? tick, double currentPrice, NumberFormat inrFormat) {
    final summary = _historySummary;
    final high52w = summary?.high52w ?? tick?.high24h ?? currentPrice;
    final low52w = summary?.low52w ?? tick?.low24h ?? currentPrice;
    final highPeriod = summary?.highPeriod ?? tick?.high24h ?? currentPrice;
    final lowPeriod = summary?.lowPeriod ?? tick?.low24h ?? currentPrice;
    final prevClose = summary?.previousClose ?? (tick?.price != null ? tick!.price * 0.99 : currentPrice);
    final volume = tick?.volume24h ?? summary?.volumePeriod ?? 0;

    String formatPrice(double val) {
      if (widget.asset.isIndianAsset) {
        return inrFormat.format(val);
      }
      return '\$${val.toStringAsFixed(2)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY MARKET METRICS & REAL DATA',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatMetricItem(
                  label: '52W HIGH',
                  value: formatPrice(high52w),
                  color: JweTheme.accentTeal,
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: '52W LOW',
                  value: formatPrice(low52w),
                  color: JweTheme.accentRed,
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: 'PERIOD HIGH',
                  value: formatPrice(highPeriod),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatMetricItem(
                  label: 'PERIOD LOW',
                  value: formatPrice(lowPeriod),
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: 'PREV CLOSE',
                  value: formatPrice(prevClose),
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: 'VOLUME',
                  value: NumberFormat.compact().format(volume),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatMetricItem(
                  label: 'EXCHANGE',
                  value: widget.asset.exchange,
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: 'CATEGORY',
                  value: widget.asset.category.label,
                ),
              ),
              Expanded(
                child: _StatMetricItem(
                  label: 'STATUS',
                  value: widget.asset.isIndianAsset
                      ? (widget.provider.marketService.isIndianMarketOpen ? 'LIVE' : 'CLOSED')
                      : '24/7 OPEN',
                  color: widget.asset.isIndianAsset
                      ? (widget.provider.marketService.isIndianMarketOpen ? JweTheme.accentTeal : JweTheme.accentAmber)
                      : JweTheme.accentTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatMetricItem({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: color ?? JweTheme.textWhite,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Interactive Real Historical Line Chart ───────────────────────────────────

class _HistoricalLineChart extends StatelessWidget {
  final HistoricalPriceSummary summary;
  final ShadowComparisonSeries? shadowSeries;
  final bool isIndianAsset;

  const _HistoricalLineChart({
    required this.summary,
    this.shadowSeries,
    required this.isIndianAsset,
  });

  @override
  Widget build(BuildContext context) {
    final points = summary.points;
    if (points.isEmpty) {
      return Center(
        child: Text(
          'NO HISTORICAL DATA AVAILABLE',
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
        ),
      );
    }

    final isPositive = summary.isPositive;
    final chartColor = isPositive ? JweTheme.accentTeal : JweTheme.accentRed;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].close));
    }

    final shadowSpots = <FlSpot>[];
    if (shadowSeries != null && shadowSeries!.isNotEmpty) {
      final alignedPrices = shadowSeries!.getAlignedPrices(
        targetLength: points.length,
        baseStartPrice: points.first.close,
        normalized: true,
      );
      for (int i = 0; i < alignedPrices.length; i++) {
        shadowSpots.add(FlSpot(i.toDouble(), alignedPrices[i]));
      }
    }

    final allY = [
      ...spots.map((s) => s.y),
      ...shadowSpots.map((s) => s.y),
    ];
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final delta = (maxY - minY).abs();
    final padding = delta > 0 ? delta * 0.12 : (minY * 0.01).clamp(0.1, 100.0);

    final currencySymbol = isIndianAsset ? '₹' : '\$';
    final firstPrice = points.first.close;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: JweTheme.border.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (points.length / 4).clamp(1.0, 100.0),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final dt = points[idx].timestamp;
                final text = summary.timeframe == '1D'
                    ? DateFormat('HH:mm').format(dt)
                    : DateFormat('dd MMM').format(dt);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    text,
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 8.5,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isIndianAsset ? 55 : 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '$currencySymbol${NumberFormat.compact().format(value)}',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
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
              if (touchedSpots.isEmpty) return [];

              final touchX = touchedSpots.first.x.toInt().clamp(0, points.length - 1);
              final pt = points[touchX];
              final dateStr = DateFormat('dd MMM, HH:mm').format(pt.timestamp);

              final mainSpot = touchedSpots.firstWhere(
                (s) => shadowSpots.isNotEmpty ? s.barIndex == 1 : s.barIndex == 0,
                orElse: () => touchedSpots.first,
              );

              final diffPct = firstPrice > 0 ? ((mainSpot.y - firstPrice) / firstPrice) * 100 : 0.0;
              final isSpotPos = diffPct >= 0;

              String shadowText = '';
              if (shadowSpots.isNotEmpty && touchX < shadowSpots.length) {
                final shadowAlignedY = shadowSpots[touchX].y;
                final shadowReturn = firstPrice > 0 ? ((shadowAlignedY - firstPrice) / firstPrice) * 100 : 0.0;
                final isShadowPos = shadowReturn >= 0;
                shadowText = '\n┄ ${shadowSeries!.label}: ${isShadowPos ? '+' : ''}${shadowReturn.toStringAsFixed(2)}%';
              }

              return touchedSpots.map((spot) {
                if (shadowSpots.isNotEmpty && spot.barIndex == 0) {
                  return null;
                }

                return LineTooltipItem(
                  '$currencySymbol${spot.y.toStringAsFixed(spot.y < 10 ? 2 : 1)}\n',
                  GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '$dateStr · ${isSpotPos ? '+' : ''}${diffPct.toStringAsFixed(2)}%',
                      style: GoogleFonts.jetBrainsMono(
                        color: isSpotPos ? JweTheme.accentTeal : JweTheme.accentRed,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (shadowText.isNotEmpty)
                      TextSpan(
                        text: shadowText,
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          if (shadowSpots.isNotEmpty)
            LineChartBarData(
              spots: shadowSpots,
              color: JweTheme.accentAmber.withValues(alpha: 0.85),
              barWidth: 1.8,
              isCurved: true,
              dashArray: [5, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
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
                  chartColor.withValues(alpha: 0.22),
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

// ── Live Sparkline Fallback Chart ────────────────────────────────────────────

class _PriceLineChart extends StatelessWidget {
  final List<double> history;
  final bool isPositive;
  final double currentPrice;
  final bool isIndianAsset;

  const _PriceLineChart({
    required this.history,
    required this.isPositive,
    required this.currentPrice,
    required this.isIndianAsset,
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
    final currencySymbol = isIndianAsset ? '₹' : '\$';

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
          getDrawingHorizontalLine: (_) => FlLine(
            color: JweTheme.border.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                return Text(
                  '$currencySymbol${value.toStringAsFixed(value < 100 ? 1 : 0)}',
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
                  '$currencySymbol${spot.y.toStringAsFixed(2)}',
                  GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
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
  final String? labelOverride;

  const _ConnectionStatusDot({
    required this.status,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label = labelOverride ?? '';

    switch (status) {
      case MarketConnectionStatus.connected:
        color = JweTheme.accentTeal;
        if (label.isEmpty) label = 'LIVE';
        break;
      case MarketConnectionStatus.connecting:
        color = JweTheme.accentCyan;
        if (label.isEmpty) label = 'CONNECTING';
        break;
      case MarketConnectionStatus.reconnecting:
        color = JweTheme.accentAmber;
        if (label.isEmpty) label = 'RECONNECTING';
        break;
      case MarketConnectionStatus.disconnected:
        color = JweTheme.accentRed;
        if (label.isEmpty) label = 'OFFLINE';
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
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
