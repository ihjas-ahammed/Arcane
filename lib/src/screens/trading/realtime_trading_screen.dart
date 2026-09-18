import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/screens/trading/trading_asset_detail_screen.dart';
import 'package:missions/src/screens/trading/trading_guide_sheet.dart';
import 'package:missions/src/screens/trading/trading_settings_dialog.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class RealtimeTradingScreen extends StatefulWidget {
  const RealtimeTradingScreen({super.key});

  @override
  State<RealtimeTradingScreen> createState() => _RealtimeTradingScreenState();
}

class _RealtimeTradingScreenState extends State<RealtimeTradingScreen>
    with SingleTickerProviderStateMixin {
  static PaperTradingProvider? _sharedProvider;
  late final PaperTradingProvider _provider;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_sharedProvider == null) {
      final marketService = BinanceMarketService();
      _sharedProvider = PaperTradingProvider(marketService: marketService);
    }
    _provider = _sharedProvider!;
    _provider.marketService.start();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_provider, _provider.marketService]),
      builder: (context, _) {
        final ticks = _provider.marketService.ticks;
        final totalPortfolioINR = _provider.totalPortfolioValueINR(ticks);
        final totalHoldingsINR = _provider.totalHoldingsValueINR(ticks);
        final totalPnlINR = _provider.totalUnrealizedPnlINR(ticks);
        final totalPnlPercent = _provider.totalUnrealizedPnlPercent(ticks);
        final isPnlPositive = totalPnlINR >= 0;

        final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

        return Scaffold(
          backgroundColor: JweTheme.bgCanvas,
          appBar: AppBar(
            backgroundColor: JweTheme.bgCanvas,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: JweTheme.textWhite, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'REALTIME TRADING',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(status: _provider.marketService.status),
                  ],
                ),
                Text(
                  'India & Global Paper Markets · Real Live Quotes',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: JweTheme.accentCyan, size: 20),
                tooltip: 'Market Mechanics Guide',
                onPressed: () => TradingGuideSheet.show(context),
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: JweTheme.textMid, size: 20),
                tooltip: 'Simulation Settings',
                onPressed: () => TradingSettingsDialog.show(context, _provider),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: JweTheme.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: JweTheme.accentCyan,
                  indicatorWeight: 2.5,
                  labelColor: JweTheme.accentCyan,
                  unselectedLabelColor: JweTheme.textMuted,
                  labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  tabs: [
                    const Tab(text: 'MARKETS'),
                    Tab(text: 'PORTFOLIO (${_provider.holdings.length})'),
                    Tab(text: 'ORDERS (${_provider.orders.length})'),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Top Tactical Portfolio Summary Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: JweTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL PORTFOLIO VALUE',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inrFormat.format(totalPortfolioINR),
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPnlPositive ? JweTheme.accentTeal : JweTheme.accentRed)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isPnlPositive ? JweTheme.accentTeal : JweTheme.accentRed)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${isPnlPositive ? '+' : ''}${inrFormat.format(totalPnlINR)} (${totalPnlPercent.toStringAsFixed(2)}%)',
                            style: GoogleFonts.jetBrainsMono(
                              color: isPnlPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: JweTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MetricMini(
                            label: 'CASH',
                            value: inrFormat.format(_provider.cashBalance),
                            color: JweTheme.textWhite,
                          ),
                          _MetricMini(
                            label: 'HOLDINGS',
                            value: inrFormat.format(totalHoldingsINR),
                            color: JweTheme.accentCyan,
                          ),
                          _MetricMini(
                            label: 'USD/INR',
                            value: '₹${_provider.usdtToInrRate.toStringAsFixed(1)}',
                            color: JweTheme.textMid,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _WatchlistTab(
                      provider: _provider,
                      searchController: _searchController,
                    ),
                    _PortfolioTab(provider: _provider),
                    _OrdersTab(provider: _provider),
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

// ── Tab 1: Unified Markets Watchlist ────────────────────────────────────────

class _WatchlistTab extends StatefulWidget {
  final PaperTradingProvider provider;
  final TextEditingController searchController;

  const _WatchlistTab({
    required this.provider,
    required this.searchController,
  });

  @override
  State<_WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends State<_WatchlistTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_reportVisibleAssets);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibleAssets());
  }

  @override
  void didUpdateWidget(covariant _WatchlistTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibleAssets());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reportVisibleAssets() {
    if (!mounted) return;
    final assets = widget.provider.filteredAssets;
    if (assets.isEmpty) {
      widget.provider.marketService.setVisibleSymbols(const []);
      return;
    }

    // If specific list is compact (<= 25 items, e.g. NSE Stocks, Indices, Commodities, or search results),
    // keep ALL items in that list updated in real-time!
    if (assets.length <= 25) {
      widget.provider.marketService.setVisibleSymbols(assets.map((a) => a.symbol));
      return;
    }

    // For large lists (e.g. ALL, full CRYPTO universe), calculate the visible window with safety buffer
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    const itemHeight = 78.0;
    final viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : 500.0;
    final firstIndex = (offset / itemHeight).floor().clamp(0, assets.length - 1);
    final visibleCount = (viewportHeight / itemHeight).ceil() + 6;
    final lastIndex = (firstIndex + visibleCount).clamp(0, assets.length);

    final visibleSlice = assets.sublist(firstIndex, lastIndex).map((a) => a.symbol);
    widget.provider.marketService.setVisibleSymbols(visibleSlice);
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.provider.filteredAssets;
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);
    final inrCompact = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    final isIndianOpen = widget.provider.marketService.isIndianMarketOpen;

    return Column(
      children: [
        // Indian Market Status Header Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: JweTheme.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: JweTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isIndianOpen ? JweTheme.accentTeal : JweTheme.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.provider.marketService.indianMarketStatusText,
                    style: GoogleFonts.jetBrainsMono(
                      color: isIndianOpen ? JweTheme.accentTeal : JweTheme.accentAmber,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '09:15 - 15:30 IST · Mon-Fri',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: widget.searchController,
            onChanged: (val) {
              widget.provider.setSearchQuery(val);
              WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibleAssets());
            },
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search 700+ assets (Reliance, Nifty, BTC, Gold...)',
              hintStyle: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: JweTheme.textMuted, size: 18),
              suffixIcon: widget.provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: JweTheme.textMuted, size: 16),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.provider.setSearchQuery('');
                        WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibleAssets());
                      },
                    )
                  : null,
              filled: true,
              fillColor: JweTheme.panel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: JweTheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Category Filter Chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: TradingAssetCategory.values.map((cat) {
              final isSelected = widget.provider.selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    widget.provider.setCategory(cat);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibleAssets());
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? JweTheme.accentCyan.withValues(alpha: 0.18)
                          : JweTheme.panel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? JweTheme.accentCyan : JweTheme.border,
                        width: isSelected ? 1.2 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat.label,
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? JweTheme.accentCyan : JweTheme.textMuted,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Asset List
        Expanded(
          child: assets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, color: JweTheme.textMuted, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'NO MATCHING ASSETS FOUND',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching for another ticker symbol or company name.',
                          style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    widget.provider.marketService.registerRenderedSymbol(asset.symbol);
                    final tick = widget.provider.marketService.getTick(asset.symbol);
                    final history = widget.provider.marketService.getHistory(asset.symbol);

                    final price = tick?.price ?? 0.0;
                    final changePercent = tick?.changePercent24h ?? 0.0;
                    final isPositive = changePercent >= 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: JweTheme.panel,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: JweTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TradingAssetDetailScreen(
                                asset: asset,
                                provider: widget.provider,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Asset Icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: asset.brandColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(asset.icon, color: asset.brandColor, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name & Symbol
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          asset.displaySymbol,
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textWhite,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: JweTheme.panel2,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            asset.exchange,
                                            style: GoogleFonts.jetBrainsMono(
                                              color: JweTheme.textMuted,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      asset.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: JweTheme.textMuted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Mini Sparkline Preview
                              if (history.length >= 2) ...[
                                SizedBox(
                                  width: 44,
                                  height: 20,
                                  child: HudSparkline(
                                    data: history,
                                    width: 44,
                                    height: 20,
                                    tone: isPositive ? HudTone.teal : HudTone.red,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],

                              // Price & % Change
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    asset.isIndianAsset
                                        ? inrFormat.format(price)
                                        : '\$${price.toStringAsFixed(price < 100 ? 2 : 2)}',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!asset.isIndianAsset) ...[
                                        Text(
                                          inrCompact.format(price * widget.provider.usdtToInrRate),
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textMuted,
                                            fontSize: 9.5,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: (isPositive ? JweTheme.accentTeal : JweTheme.accentRed)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: isPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Tab 2: Portfolio ────────────────────────────────────────────────────────

class _PortfolioTab extends StatelessWidget {
  final PaperTradingProvider provider;

  const _PortfolioTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final holdings = provider.holdings.values.toList();
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);
    final inrDecimalFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

    if (holdings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: JweTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                'NO ACTIVE POSITIONS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You hold 100% in virtual cash (${inrFormat.format(provider.cashBalance)}).\nSelect an Indian stock or crypto pair from the Markets tab to execute your first paper trade.',
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
      itemCount: holdings.length,
      itemBuilder: (context, index) {
        final holding = holdings[index];
        final asset = holding.assetInfo;
        final tick = provider.marketService.getTick(holding.symbol);
        final currentPrice = tick?.price ?? holding.avgBuyPriceUSDT;

        final curValINR = holding.currentValueINR(currentPrice, provider.usdtToInrRate);
        final pnlINR = holding.pnlINR(currentPrice, provider.usdtToInrRate);
        final pnlPct = holding.pnlPercent(currentPrice, provider.usdtToInrRate);
        final isPnlPositive = pnlINR >= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: JweTheme.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(asset.icon, color: asset.brandColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          asset.displaySymbol,
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: JweTheme.panel2,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            asset.exchange,
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TradingAssetDetailScreen(
                              asset: asset,
                              provider: provider,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'TRADE',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HOLDING QUANTITY', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.0), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${holding.quantity.toStringAsFixed(asset.decimals)} ${asset.baseAsset}',
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('AVG / LIVE', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.0), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            asset.isIndianAsset
                                ? '${inrDecimalFormat.format(holding.avgBuyPriceUSDT)} / ${inrDecimalFormat.format(currentPrice)}'
                                : '\$${holding.avgBuyPriceUSDT.toStringAsFixed(1)} / \$${currentPrice.toStringAsFixed(1)}',
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('CURRENT VALUE', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.0), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            inrFormat.format(curValINR),
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UNREALIZED P&L', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5)),
                    Text(
                      '${isPnlPositive ? '+' : ''}${inrFormat.format(pnlINR)} (${pnlPct.toStringAsFixed(2)}%)',
                      style: GoogleFonts.jetBrainsMono(
                        color: isPnlPositive ? JweTheme.accentTeal : JweTheme.accentRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tab 3: Orders History ───────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final PaperTradingProvider provider;

  const _OrdersTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final orders = provider.orders;
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, color: JweTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                'NO ORDER HISTORY',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Executed and pending orders across Indian stocks & crypto will appear here.',
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
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final asset = order.assetInfo;
        final isBuy = order.isBuy;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: JweTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: (isBuy ? JweTheme.accentTeal : JweTheme.accentRed).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.side.name.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: isBuy ? JweTheme.accentTeal : JweTheme.accentRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${order.quantity.toStringAsFixed(asset.decimals)} ${asset.baseAsset}',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: JweTheme.panel2,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            order.orderType.name.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unit: ${asset.isIndianAsset ? '₹' : '\$'}${(order.executedPriceUSDT ?? order.targetPriceUSDT).toStringAsFixed(2)} • ${DateFormat('dd MMM HH:mm').format(order.createdAt)}',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Status & Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inrFormat.format(order.totalINR),
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  if (order.isPending) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => provider.cancelOrder(order.id),
                      child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 9)),
                    ),
                  ] else ...[
                    Text(
                      order.status.name.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: order.isFilled ? JweTheme.accentTeal : JweTheme.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MarketConnectionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case MarketConnectionStatus.connected:
        c = JweTheme.accentTeal;
        label = 'LIVE';
        break;
      case MarketConnectionStatus.connecting:
        c = JweTheme.accentCyan;
        label = 'CONNECTING';
        break;
      case MarketConnectionStatus.reconnecting:
        c = JweTheme.accentAmber;
        label = 'RECONNECTING';
        break;
      case MarketConnectionStatus.disconnected:
        c = JweTheme.accentRed;
        label = 'OFFLINE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(color: c, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
