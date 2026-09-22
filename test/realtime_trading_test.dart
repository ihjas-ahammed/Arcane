import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/screens/trading/trading_guide_sheet.dart';
import 'package:missions/src/screens/trading/trading_asset_detail_screen.dart';

class MockMarketService extends BinanceMarketService {
  final Map<String, CryptoPriceTick> _mockTicks = {};
  MarketConnectionStatus _mockStatus = MarketConnectionStatus.connected;

  @override
  Map<String, CryptoPriceTick> get ticks => _mockTicks;

  @override
  CryptoPriceTick? getTick(String symbol) => _mockTicks[symbol.toUpperCase()];

  @override
  MarketConnectionStatus get status => _mockStatus;

  void setMockStatus(MarketConnectionStatus s) {
    _mockStatus = s;
    notifyListeners();
  }

  void setMockTick(CryptoPriceTick tick) {
    _mockTicks[tick.symbol.toUpperCase()] = tick;
    notifyListeners();
  }

  @override
  void start() {} // No-op in tests
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Trading Models & Parsing Tests', () {
    test('CryptoSymbol enum metadata', () {
      expect(CryptoSymbol.btc.rawSymbol, 'BTCUSDT');
      expect(CryptoSymbol.btc.baseAsset, 'BTC');
      expect(CryptoSymbol.btc.pairLabel, 'BTC/USDT');

      expect(CryptoSymbol.eth.rawSymbol, 'ETHUSDT');
      expect(CryptoSymbol.sol.rawSymbol, 'SOLUSDT');

      expect(CryptoSymbol.fromRaw('btcusdt'), CryptoSymbol.btc);
      expect(CryptoSymbol.fromRaw('ETHUSDT'), CryptoSymbol.eth);
      expect(CryptoSymbol.fromRaw('UNKNOWN'), isNull);
    });

    test('CryptoPriceTick parses Binance WebSocket payload', () {
      final wsJson = {
        's': 'BTCUSDT',
        'c': '68500.50',
        'P': '3.25',
        'h': '69000.00',
        'l': '66500.00',
        'v': '12500.45',
        'E': 1672515782136,
      };

      final tick = CryptoPriceTick.fromBinanceWs(wsJson);
      expect(tick.symbol, 'BTCUSDT');
      expect(tick.price, 68500.50);
      expect(tick.changePercent24h, 3.25);
      expect(tick.high24h, 69000.00);
      expect(tick.low24h, 66500.00);
      expect(tick.volume24h, 12500.45);
      expect(tick.isPositive, isTrue);
    });

    test('CryptoPriceTick parses Binance REST payload', () {
      final restJson = {
        'symbol': 'ETHUSDT',
        'lastPrice': '3540.20',
        'priceChangePercent': '-1.85',
        'highPrice': '3650.00',
        'lowPrice': '3490.00',
        'volume': '89000.0',
      };

      final tick = CryptoPriceTick.fromBinanceRest(restJson);
      expect(tick.symbol, 'ETHUSDT');
      expect(tick.price, 3540.20);
      expect(tick.changePercent24h, -1.85);
      expect(tick.isPositive, isFalse);
    });

    test('CryptoHolding PnL calculations in INR and %', () {
      // Bought 0.5 BTC at $60,000 when USDT = ₹88
      // Total cost = 0.5 * 60,000 * 88 = ₹26,40,000
      final holding = CryptoHolding(
        symbol: 'BTCUSDT',
        coinName: 'Bitcoin',
        quantity: 0.5,
        avgBuyPriceUSDT: 60000.0,
        totalCostINR: 2640000.0,
      );

      expect(holding.currentValueUSDT(70000.0), 35000.0);
      expect(holding.currentValueINR(70000.0, 88.0), 3080000.0);
      expect(holding.pnlINR(70000.0, 88.0), 440000.0);
      expect(holding.pnlPercent(70000.0, 88.0), closeTo(16.666, 0.01));

      expect(holding.pnlINR(50000.0, 88.0), -440000.0);
      expect(holding.pnlPercent(50000.0, 88.0), closeTo(-16.666, 0.01));
    });
  });

  group('Indian Markets & Unified Asset Universe Tests', () {
    test('Curated assets contain major Indian Bluechips and Indices', () {
      final curated = TradingAsset.curatedAssets;
      final symbols = curated.map((a) => a.symbol).toList();

      expect(symbols, contains('RELIANCE.NS'));
      expect(symbols, contains('TCS.NS'));
      expect(symbols, contains('HDFCBANK.NS'));
      expect(symbols, contains('INFY.NS'));
      expect(symbols, contains('^NSEI'));
      expect(symbols, contains('^BSESN'));
      expect(symbols, contains('GC=F')); // Gold
      expect(symbols, contains('BTCUSDT'));
    });

    test('TradingAsset properties for Indian equities vs Crypto', () {
      final reliance = TradingAsset.fromSymbol('RELIANCE.NS');
      expect(reliance.isIndianAsset, isTrue);
      expect(reliance.isIndianEquity, isTrue);
      expect(reliance.isCrypto, isFalse);
      expect(reliance.currency, 'INR');
      expect(reliance.exchange, 'NSE');
      expect(reliance.decimals, 2); // price decimals
      expect(reliance.isTradable, isTrue);

      final nifty = TradingAsset.fromSymbol('^NSEI');
      expect(nifty.isIndex, isTrue);
      expect(nifty.isTradable, isFalse); // Index view-only
      expect(nifty.currency, 'INR');

      final btc = TradingAsset.fromSymbol('BTCUSDT');
      expect(btc.isCrypto, isTrue);
      expect(btc.isIndianAsset, isFalse);
      expect(btc.currency, 'USD');
      expect(btc.exchange, 'Binance');
    });

    test('TradingAssetCategory definitions', () {
      expect(TradingAssetCategory.all.label, 'ALL');
      expect(TradingAssetCategory.indianEquity.label, 'NSE STOCKS');
      expect(TradingAssetCategory.indianIndex.label, 'INDICES');
      expect(TradingAssetCategory.crypto.label, 'CRYPTO');
      expect(TradingAssetCategory.commodity.label, 'COMMODITIES');
    });
  });

  group('Historical Price Models & Summary Tests', () {
    test('HistoricalPriceSummary calculates metrics and period return', () {
      final now = DateTime.now();
      final points = [
        HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 4)), price: 100.0),
        HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 3)), price: 105.0),
        HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 2)), price: 98.0),
        HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 1)), price: 112.0),
        HistoricalDataPoint(timestamp: now, price: 110.0),
      ];

      final summary = HistoricalPriceSummary(
        symbol: 'RELIANCE.NS',
        timeframe: '1W',
        points: points,
        fiftyTwoWeekHigh: 130.0,
        fiftyTwoWeekLow: 85.0,
        dayHigh: 112.0,
        dayLow: 98.0,
        previousClose: 108.0,
        periodReturnPercent: 10.0,
        minPrice: 98.0,
        maxPrice: 112.0,
      );

      expect(summary.isPositive, isTrue);
      expect(summary.high52w, 130.0);
      expect(summary.low52w, 85.0);
      expect(summary.highPeriod, 112.0);
      expect(summary.lowPeriod, 98.0);
      expect(summary.previousClose, 108.0);
      expect(summary.points.first.close, 100.0);
    });

    test('TradingTimeframe enum values and labels', () {
      expect(TradingTimeframe.oneDay.label, '1D');
      expect(TradingTimeframe.oneWeek.label, '1W');
      expect(TradingTimeframe.oneMonth.label, '1M');
      expect(TradingTimeframe.oneYear.label, '1Y');
      expect(TradingTimeframe.all.label, 'ALL');
      expect(TradingTimeframe.values.length, 5);
    });
  });

  group('Shadow Graphs & Historical Comparison Tests', () {
    test('ShadowGraphType enum contextual labels adapt to timeframes', () {
      // 1D timeframe labels
      expect(ShadowGraphType.none.getContextLabel(TradingTimeframe.oneDay), 'OFF');
      expect(ShadowGraphType.previousPeriod.getContextLabel(TradingTimeframe.oneDay), 'YESTERDAY');
      expect(ShadowGraphType.sameDayLastWeek.getContextLabel(TradingTimeframe.oneDay), 'LAST WEEK DAY');
      expect(ShadowGraphType.sameDayLastMonth.getContextLabel(TradingTimeframe.oneDay), 'LAST MONTH DAY');
      expect(ShadowGraphType.sameDayLastYear.getContextLabel(TradingTimeframe.oneDay), '1 YEAR AGO');

      // 1W timeframe labels
      expect(ShadowGraphType.previousPeriod.getContextLabel(TradingTimeframe.oneWeek), 'LAST WEEK');
      expect(ShadowGraphType.sameDayLastWeek.getContextLabel(TradingTimeframe.oneWeek), 'PRIOR 7D CYCLE');

      // 1M timeframe labels
      expect(ShadowGraphType.previousPeriod.getContextLabel(TradingTimeframe.oneMonth), 'LAST MONTH');
      expect(ShadowGraphType.sameDayLastMonth.getContextLabel(TradingTimeframe.oneMonth), 'PRIOR MONTH');

      // 1Y timeframe labels
      expect(ShadowGraphType.previousPeriod.getContextLabel(TradingTimeframe.oneYear), 'LAST YEAR');
      expect(ShadowGraphType.sameDayLastYear.getContextLabel(TradingTimeframe.oneYear), 'PRIOR YEAR');
    });

    test('ShadowComparisonSeries aligns prices with financial rebased indexing', () {
      final now = DateTime.now();
      // Historical shadow trajectory: 100 -> 110 (+10%) -> 120 (+20%)
      final shadowSeries = ShadowComparisonSeries(
        type: ShadowGraphType.previousPeriod,
        label: 'YESTERDAY',
        points: [
          HistoricalDataPoint(timestamp: now.subtract(const Duration(hours: 2)), price: 100.0),
          HistoricalDataPoint(timestamp: now.subtract(const Duration(hours: 1)), price: 110.0),
          HistoricalDataPoint(timestamp: now, price: 120.0),
        ],
        periodReturnPercent: 20.0,
        minPrice: 100.0,
        maxPrice: 120.0,
        referenceDate: now.subtract(const Duration(hours: 2)),
      );

      expect(shadowSeries.isPositive, isTrue);
      expect(shadowSeries.isNotEmpty, isTrue);
      expect(shadowSeries.isEmpty, isFalse);

      // Active asset is currently starting at ₹2,500
      final aligned = shadowSeries.getAlignedPrices(
        targetLength: 3,
        baseStartPrice: 2500.0,
        normalized: true,
      );

      expect(aligned.length, 3);
      expect(aligned[0], closeTo(2500.0, 0.001)); // Starting point matches active start
      expect(aligned[1], closeTo(2750.0, 0.001)); // +10% applied to 2500 = 2750
      expect(aligned[2], closeTo(3000.0, 0.001)); // +20% applied to 2500 = 3000
    });

    test('ShadowComparisonSeries resamples and interpolates smoothly for different target lengths', () {
      final now = DateTime.now();
      final shadowSeries = ShadowComparisonSeries(
        type: ShadowGraphType.sameDayLastWeek,
        label: 'LAST WEEK DAY',
        points: [
          HistoricalDataPoint(timestamp: now.subtract(const Duration(hours: 2)), price: 50.0),
          HistoricalDataPoint(timestamp: now, price: 100.0), // +100% gain
        ],
        periodReturnPercent: 100.0,
        minPrice: 50.0,
        maxPrice: 100.0,
      );

      // Resample from 2 shadow points to 5 target chart points
      final aligned = shadowSeries.getAlignedPrices(
        targetLength: 5,
        baseStartPrice: 1000.0,
        normalized: true,
      );

      expect(aligned.length, 5);
      expect(aligned[0], closeTo(1000.0, 0.001));
      expect(aligned[2], closeTo(1500.0, 0.001)); // Midpoint (+50%)
      expect(aligned[4], closeTo(2000.0, 0.001)); // Final point (+100%)
    });

    test('ShadowComparisonSeries handles normalized=false by returning raw prices', () {
      final now = DateTime.now();
      final shadowSeries = ShadowComparisonSeries(
        type: ShadowGraphType.sameDayLastYear,
        label: '1 YEAR AGO',
        points: [
          HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 365)), price: 60000.0),
          HistoricalDataPoint(timestamp: now.subtract(const Duration(days: 364)), price: 62000.0),
        ],
        periodReturnPercent: 3.33,
        minPrice: 60000.0,
        maxPrice: 62000.0,
      );

      final raw = shadowSeries.getAlignedPrices(
        targetLength: 2,
        baseStartPrice: 90000.0,
        normalized: false,
      );

      expect(raw.length, 2);
      expect(raw[0], 60000.0);
      expect(raw[1], 62000.0);
    });

    test('BinanceMarketService fetchShadowData fallback and cache mechanism', () async {
      final marketService = BinanceMarketService();
      final now = DateTime.now();
      final baseSummary = HistoricalPriceSummary(
        symbol: 'BTCUSDT',
        timeframe: '1D',
        points: [
          HistoricalDataPoint(timestamp: now.subtract(const Duration(hours: 1)), price: 92000.0),
          HistoricalDataPoint(timestamp: now, price: 93500.0),
        ],
        minPrice: 92000.0,
        maxPrice: 93500.0,
        periodReturnPercent: 1.63,
      );

      // none type returns null
      final noneResult = await marketService.fetchShadowData(
        symbol: 'BTCUSDT',
        timeframe: TradingTimeframe.oneDay,
        type: ShadowGraphType.none,
      );
      expect(noneResult, isNull);

      // Resilient fallback when provided base summary
      final shadow = await marketService.fetchShadowData(
        symbol: 'UNKNOWN_TEST_SYM',
        timeframe: TradingTimeframe.oneDay,
        type: ShadowGraphType.previousPeriod,
        baseSummary: baseSummary,
      );

      expect(shadow, isNotNull);
      expect(shadow!.points.length, baseSummary.points.length);
      expect(shadow.label, 'YESTERDAY');

      // Second call returns cached series
      final cachedShadow = await marketService.fetchShadowData(
        symbol: 'UNKNOWN_TEST_SYM',
        timeframe: TradingTimeframe.oneDay,
        type: ShadowGraphType.previousPeriod,
        baseSummary: baseSummary,
      );
      expect(identical(shadow, cachedShadow), isTrue);

      marketService.dispose();
    });
  });

  group('PaperTradingProvider Multi-Asset & Filtering Tests', () {
    late MockMarketService mockMarketService;
    late PaperTradingProvider provider;

    setUp(() {
      mockMarketService = MockMarketService();
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'RELIANCE.NS',
        price: 2900.0,
        changePercent24h: 1.2,
        high24h: 2950.0,
        low24h: 2880.0,
        volume24h: 150000,
        timestamp: DateTime.now(),
        currency: 'INR',
      ));
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'ETHUSDT',
        price: 3200.0,
        changePercent24h: 2.5,
        high24h: 3250.0,
        low24h: 3150.0,
        volume24h: 5000,
        timestamp: DateTime.now(),
        currency: 'USD',
      ));
      provider = PaperTradingProvider(marketService: mockMarketService);
    });

    test('Initializes with default starting virtual cash ₹1,00,000', () {
      expect(provider.cashBalance, 100000.0);
      expect(provider.usdtToInrRate, 88.0);
      expect(provider.holdings, isEmpty);
      expect(provider.orders, isEmpty);
      expect(provider.availableCash, 100000.0);
    });

    test('Executes Indian stock whole shares BUY order in native INR', () {
      // Buy 10 shares of RELIANCE.NS at ₹2,900. Total cost = ₹29,000
      final result = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10.0,
        currentPriceUSDT: 2900.0, // native INR price
      );

      expect(result.success, isTrue);
      expect(provider.cashBalance, 100000.0 - 29000.0); // ₹71,000
      expect(provider.holdings.containsKey('RELIANCE.NS'), isTrue);

      final holding = provider.getHolding('RELIANCE.NS')!;
      expect(holding.quantity, 10.0);
      expect(holding.avgBuyPriceUSDT, 2900.0);
      expect(holding.totalCostINR, 29000.0);
      expect(holding.currency, 'INR');

      // Check order history
      expect(provider.orders.length, 1);
      final ord = provider.orders.first;
      expect(ord.isFilled, isTrue);
      expect(ord.currency, 'INR');
      expect(ord.totalINR, 29000.0);
    });

    test('Executes Indian stock SELL order and receives INR proceeds', () {
      // First buy 10 shares of RELIANCE.NS at ₹2,900
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10.0,
        currentPriceUSDT: 2900.0,
      );

      // Now sell 5 shares at ₹3,100. Proceeds = 5 * 3,100 = ₹15,500
      final sellResult = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.sell,
        quantity: 5.0,
        currentPriceUSDT: 3100.0,
      );

      expect(sellResult.success, isTrue);
      // Cash = ₹71,000 + ₹15,500 = ₹86,500
      expect(provider.cashBalance, 86500.0);
      final holding = provider.getHolding('RELIANCE.NS')!;
      expect(holding.quantity, 5.0);
      expect(holding.totalCostINR, 14500.0); // 5 * 2,900
    });

    test('Filters assets by category correctly', () {
      provider.setCategory(TradingAssetCategory.indianEquity);
      final nseAssets = provider.filteredAssets;
      expect(nseAssets.every((a) => a.category == TradingAssetCategory.indianEquity), isTrue);
      expect(nseAssets.any((a) => a.symbol == 'RELIANCE.NS'), isTrue);

      provider.setCategory(TradingAssetCategory.crypto);
      final cryptoAssets = provider.filteredAssets;
      expect(cryptoAssets.every((a) => a.category == TradingAssetCategory.crypto), isTrue);
      expect(cryptoAssets.any((a) => a.symbol == 'BTCUSDT'), isTrue);

      provider.setCategory(TradingAssetCategory.all);
      expect(provider.filteredAssets.length, greaterThan(20));
    });

    test('Searches assets by symbol and name', () {
      provider.setSearchQuery('TATA');
      final tataAssets = provider.filteredAssets;
      expect(tataAssets.any((a) => a.name.toUpperCase().contains('TATA')), isTrue);

      provider.setSearchQuery('BTC');
      final btcAssets = provider.filteredAssets;
      expect(btcAssets.any((a) => a.symbol.contains('BTC')), isTrue);

      provider.setSearchQuery('');
      expect(provider.filteredAssets.length, greaterThan(20));
    });

    test('Rejects Market SELL when balance is insufficient', () {
      final result = provider.executeMarketOrder(
        symbol: 'SOLUSDT',
        side: OrderSide.sell,
        quantity: 5.0,
        currentPriceUSDT: 150.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Insufficient balance'));
    });

    test('Cancels pending limit order correctly', () {
      final orderResult = provider.createLimitOrder(
        symbol: 'ETHUSDT',
        side: OrderSide.buy,
        quantity: 0.1,
        targetPriceUSDT: 3000.0,
      );

      expect(provider.pendingOrders.length, 1);
      final orderId = orderResult.order!.id;

      provider.cancelOrder(orderId);
      expect(provider.pendingOrders, isEmpty);
      expect(provider.orders.first.isCancelled, isTrue);
    });

    test('Blocks BUY orders when real-time feed is inactive or offline', () {
      // 1. SOLUSDT has no tick loaded yet in mockMarketService
      final unverifiedBuy = provider.executeMarketOrder(
        symbol: 'SOLUSDT',
        side: OrderSide.buy,
        quantity: 1.0,
        currentPriceUSDT: 145.0,
      );
      expect(unverifiedBuy.success, isFalse);
      expect(unverifiedBuy.message, contains('offline or unverified'));

      final unverifiedLimitBuy = provider.createLimitOrder(
        symbol: 'SOLUSDT',
        side: OrderSide.buy,
        quantity: 1.0,
        targetPriceUSDT: 140.0,
      );
      expect(unverifiedLimitBuy.success, isFalse);
      expect(unverifiedLimitBuy.message, contains('offline or unverified'));

      // 2. When crypto connection status is disconnected
      mockMarketService.setMockStatus(MarketConnectionStatus.disconnected);
      final disconnectedBuy = provider.executeMarketOrder(
        symbol: 'ETHUSDT',
        side: OrderSide.buy,
        quantity: 0.1,
        currentPriceUSDT: 3200.0,
      );
      expect(disconnectedBuy.success, isFalse);
      expect(disconnectedBuy.message, contains('offline or unverified'));

      // Reconnect and verify buy works
      mockMarketService.setMockStatus(MarketConnectionStatus.connected);
      final connectedBuy = provider.executeMarketOrder(
        symbol: 'ETHUSDT',
        side: OrderSide.buy,
        quantity: 0.1,
        currentPriceUSDT: 3200.0,
      );
      expect(connectedBuy.success, isTrue);
      // Pinned symbol should now include ETHUSDT
      expect(mockMarketService.pinnedSymbols, contains('ETHUSDT'));
    });

    test('CryptoHolding trailing peak price tracking, drawdown, and reversal detection', () {
      final holding = CryptoHolding(
        symbol: 'RELIANCE.NS',
        coinName: 'Reliance Industries',
        quantity: 10.0,
        avgBuyPriceUSDT: 2900.0,
        totalCostINR: 29000.0,
        currency: 'INR',
      );

      expect(holding.peakPrice, 2900.0);
      expect(holding.hasReachedHigher, isFalse);
      expect(holding.peakGainPercent, 0.0);

      // Price surges to ₹3,200 (+10.34%)
      final peakHolding = holding.copyWith(
        peakPrice: 3200.0,
        hasReachedHigher: true,
        peakTimestamp: DateTime.now(),
      );
      expect(peakHolding.peakGainPercent, closeTo(10.34, 0.01));
      expect(peakHolding.drawdownFromPeakPercent(3040.0), closeTo(5.0, 0.01));
      expect(peakHolding.isLosingMoneyAfterHigher(3040.0), isFalse); // Still in profit above ₹2,900

      // Price plunges to ₹2,850 (below entry ₹2,900)
      expect(peakHolding.isLosingMoneyAfterHigher(2850.0), isTrue);
    });

    test('PaperTradingProvider triggers trailing loss alert after position reached higher', () {
      // 1. Buy Reliance at ₹2,900
      final buyRes = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10.0,
        currentPriceUSDT: 2900.0,
      );
      expect(buyRes.success, isTrue);

      // 2. Price increases to ₹3,100 -> peak price updates
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'RELIANCE.NS',
        price: 3100.0,
        changePercent24h: 6.8,
        high24h: 3120.0,
        low24h: 2880.0,
        volume24h: 200000,
        timestamp: DateTime.now(),
        currency: 'INR',
      ));

      final updatedHolding = provider.getHolding('RELIANCE.NS')!;
      expect(updatedHolding.peakPrice, 3100.0);
      expect(updatedHolding.hasReachedHigher, isTrue);
      expect(provider.lossAlertsTriggered, isEmpty);

      // 3. Price drops below entry ₹2,900 to ₹2,850 -> triggers loss alert latch
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'RELIANCE.NS',
        price: 2850.0,
        changePercent24h: -1.7,
        high24h: 3120.0,
        low24h: 2840.0,
        volume24h: 250000,
        timestamp: DateTime.now(),
        currency: 'INR',
      ));

      expect(provider.lossAlertsTriggered, contains('RELIANCE.NS'));

      // 4. Subsequent lower tick does not crash or un-latch
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'RELIANCE.NS',
        price: 2830.0,
        changePercent24h: -2.4,
        high24h: 3120.0,
        low24h: 2830.0,
        volume24h: 260000,
        timestamp: DateTime.now(),
        currency: 'INR',
      ));
      expect(provider.lossAlertsTriggered, contains('RELIANCE.NS'));

      // 5. Price recovers back above entry ₹2,900 to ₹3,150 -> latch is reset!
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'RELIANCE.NS',
        price: 3150.0,
        changePercent24h: 8.6,
        high24h: 3150.0,
        low24h: 2830.0,
        volume24h: 300000,
        timestamp: DateTime.now(),
        currency: 'INR',
      ));
      expect(provider.lossAlertsTriggered, isNot(contains('RELIANCE.NS')));
      expect(provider.getHolding('RELIANCE.NS')!.peakPrice, 3150.0);
    });

    test('HourlyMarketTrend calculates aggregate trend and direction', () {
      const upTrend = HourlyMarketTrend(avgChangePercent: 0.45, sampleCount: 5);
      expect(upTrend.isGoingUp, isTrue);
      expect(upTrend.isGoingDown, isFalse);
      expect(upTrend.directionLabel, 'GOING UP');

      const downTrend = HourlyMarketTrend(avgChangePercent: -0.62, sampleCount: 4);
      expect(downTrend.isGoingDown, isTrue);
      expect(downTrend.isGoingUp, isFalse);
      expect(downTrend.directionLabel, 'GOING DOWN');

      const flatTrend = HourlyMarketTrend(avgChangePercent: 0.01, sampleCount: 3);
      expect(flatTrend.isSideways, isTrue);
      expect(flatTrend.directionLabel, 'SIDEWAYS');

      final trend = provider.getHourlyTrend();
      expect(trend.sampleCount, greaterThanOrEqualTo(0));
    });
  });

  group('Educational Guide Cards Verification', () {
    test('All 4 guide cards exist and each card is strictly under 100 words', () {
      final guides = TradingGuideCard.allGuides;
      expect(guides.length, 4);

      for (final card in guides) {
        final words = card.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        expect(
          words,
          lessThan(100),
          reason: 'Card "${card.title}" exceeded 100 words limit ($words words)',
        );
      }
    });

    test('Covers required topics: spread, order types, slippage, NSE flash crash', () {
      final guides = TradingGuideCard.allGuides;

      expect(guides[0].content, contains('Bid'));
      expect(guides[0].content, contains('Ask'));
      expect(guides[0].content, contains('spread'));

      expect(guides[1].content, contains('Market Order'));
      expect(guides[1].content, contains('Limit Order'));

      expect(guides[2].content, contains('Slippage'));

      expect(guides[3].content, contains('October 5, 2012'));
      expect(guides[3].content, contains('National Stock Exchange'));
      expect(guides[3].content, contains('circuit breakers'));
      expect(guides[3].content, contains('900 points'));
    });

    testWidgets('TradingGuideSheet renders all 4 guide cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TradingGuideSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRADING PROTOCOL & MECHANICS'), findsOneWidget);
      expect(find.text("Why the price you see isn't always the price you get"), findsOneWidget);
      expect(find.text('Market order vs Limit order — which to use when'), findsOneWidget);
      expect(find.text('What is slippage'), findsOneWidget);
      expect(find.text('Why prices move — a real example'), findsOneWidget);
    });

    testWidgets('TradingAssetDetailScreen renders shadow chips and toggles shadow selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = MockMarketService();
      final provider = PaperTradingProvider(marketService: mockService);
      final asset = TradingAsset.fromSymbol('BTCUSDT');

      await tester.pumpWidget(
        MaterialApp(
          home: TradingAssetDetailScreen(
            asset: asset,
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHADOW:'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('LAST WEEK DAY'), findsOneWidget);
      expect(find.text('LAST MONTH DAY'), findsOneWidget);
      expect(find.text('1 YEAR AGO'), findsOneWidget);

      // Tap YESTERDAY chip
      await tester.tap(find.text('YESTERDAY'));
      await tester.pumpAndSettle();

      // Switch timeframe to 1W
      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();

      // Verify contextual shadow chips adapt for 1W
      expect(find.text('LAST WEEK'), findsOneWidget);
      expect(find.text('PRIOR 7D CYCLE'), findsOneWidget);
    });

    test('Visible and active symbol tracking with crypto vs non-crypto segregation', () {
      final service = BinanceMarketService();

      expect(service.visibleSymbols, isEmpty);
      expect(service.pinnedSymbols, isEmpty);

      service.setVisibleSymbols(['BTCUSDT', 'RELIANCE.NS', 'ADAUSDT']);
      expect(service.visibleSymbols, containsAll(['BTCUSDT', 'RELIANCE.NS', 'ADAUSDT']));
      expect(service.allActiveSymbols, containsAll(['BTCUSDT', 'RELIANCE.NS', 'ADAUSDT']));

      expect(service.isCryptoSymbol('BTCUSDT'), isTrue);
      expect(service.isCryptoSymbol('ADAUSDT'), isTrue);
      expect(service.isCryptoSymbol('SOLUSDT'), isTrue);
      expect(service.isCryptoSymbol('RELIANCE.NS'), isFalse);
      expect(service.isCryptoSymbol('^NSEI'), isFalse);
      expect(service.isCryptoSymbol('MCX:GOLD'), isFalse);

      service.addPinnedSymbol('TCS.NS');
      expect(service.pinnedSymbols, contains('TCS.NS'));
      expect(service.allActiveSymbols, contains('TCS.NS'));

      service.removePinnedSymbol('TCS.NS');
      expect(service.pinnedSymbols, isNot(contains('TCS.NS')));

      service.registerRenderedSymbol('HDFCBANK.NS');
      expect(service.visibleSymbols, contains('HDFCBANK.NS'));

      service.dispose();
    });
  });
}
