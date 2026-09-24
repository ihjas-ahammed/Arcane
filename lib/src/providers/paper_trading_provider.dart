import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/services/notification_service.dart';

class TradeExecutionResult {
  final bool success;
  final String message;
  final TradingOrder? order;

  TradeExecutionResult({
    required this.success,
    required this.message,
    this.order,
  });
}

class PaperTradingProvider extends ChangeNotifier {
  static const String _prefKey = 'arcane_paper_trading_state_v1';
  static const double defaultStartingBalance = 100000.0; // ₹1,00,000
  static const double defaultInrRate = 88.0; // ₹88 / USDT

  static PaperTradingProvider? _instance;
  static PaperTradingProvider get instance =>
      _instance ??= PaperTradingProvider(marketService: BinanceMarketService.instance);

  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  final BinanceMarketService marketService;

  VoidCallback? onStateChanged;

  int _lastModified = 0;
  int get lastModified => _lastModified;

  double _cashBalance = defaultStartingBalance;
  double get cashBalance => _cashBalance;

  double _usdtToInrRate = defaultInrRate;
  double get usdtToInrRate => _usdtToInrRate;

  final Map<String, CryptoHolding> _holdings = {};
  Map<String, CryptoHolding> get holdings => Map.unmodifiable(_holdings);

  /// Latch tracking positions that have already triggered a loss-after-higher alert
  final Set<String> _lossAlertsTriggered = {};
  Set<String> get lossAlertsTriggered => Set.unmodifiable(_lossAlertsTriggered);

  final List<TradingOrder> _orders = [];
  List<TradingOrder> get orders => List.unmodifiable(_orders);

  List<TradingOrder> get pendingOrders =>
      _orders.where((o) => o.isPending).toList(growable: false);

  List<TradingOrder> get filledOrders =>
      _orders.where((o) => o.isFilled).toList(growable: false);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  TradingAssetCategory _selectedCategory = TradingAssetCategory.all;
  TradingAssetCategory get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  PaperTradingProvider({required this.marketService}) {
    _init();
    marketService.addListener(_onMarketTicksUpdated);
  }

  Future<void> _init() async {
    await _loadFromStorage();
    _isInitialized = true;
    for (final sym in _holdings.keys) {
      marketService.addPinnedSymbol(sym);
    }
    marketService.start();
    notifyListeners();
  }

  void _onMarketTicksUpdated() {
    checkLimitOrders(marketService.ticks);
    _evaluateTrailingPeakAlerts(marketService.ticks);
    notifyListeners();
  }

  // ── Category & Search ──────────────────────────────────────────

  void setCategory(TradingAssetCategory cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q.trim();
    notifyListeners();
  }

  List<TradingAsset> get filteredAssets {
    final all = marketService.allSearchableAssets;
    return all.where((a) {
      if (_selectedCategory != TradingAssetCategory.all && a.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toUpperCase();
        final matchesSymbol = a.symbol.toUpperCase().contains(query);
        final matchesDisplay = a.displaySymbol.toUpperCase().contains(query);
        final matchesName = a.name.toUpperCase().contains(query);
        return matchesSymbol || matchesDisplay || matchesName;
      }
      return true;
    }).toList();
  }

  // ── Balance & Config ────────────────────────────────────────────

  Future<void> setCashBalance(double newBalance) async {
    _cashBalance = newBalance.clamp(0.0, 1000000000.0);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> setUsdtToInrRate(double newRate) async {
    _usdtToInrRate = newRate.clamp(1.0, 1000.0);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> resetPortfolio([double balance = defaultStartingBalance]) async {
    _cashBalance = balance;
    _holdings.clear();
    _orders.clear();
    _lossAlertsTriggered.clear();
    await _saveToStorage(notifyCloud: true);
    notifyListeners();
  }

  // ── Holding helpers ─────────────────────────────────────────────

  CryptoHolding? getHolding(String symbol) => _holdings[symbol.toUpperCase()];

  double getReservedCoinQuantity(String symbol) {
    double reserved = 0.0;
    for (final o in pendingOrders) {
      if (o.isSell && o.symbol.toUpperCase() == symbol.toUpperCase()) {
        reserved += o.quantity;
      }
    }
    return reserved;
  }

  double getAvailableCoinQuantity(String symbol) {
    final holding = getHolding(symbol);
    if (holding == null) return 0.0;
    final reserved = getReservedCoinQuantity(symbol);
    return (holding.quantity - reserved).clamp(0.0, double.infinity);
  }

  double getReservedCash() {
    double reserved = 0.0;
    for (final o in pendingOrders) {
      if (o.isBuy) {
        reserved += o.totalINR;
      }
    }
    return reserved;
  }

  double get availableCash => (_cashBalance - getReservedCash()).clamp(0.0, double.infinity);

  // ── Portfolio Metrics ───────────────────────────────────────────

  double totalHoldingsValueINR(Map<String, CryptoPriceTick> ticks) {
    double total = 0.0;
    _holdings.forEach((sym, holding) {
      final tick = ticks[sym];
      final currentPrice = tick?.price ?? holding.avgBuyPriceUSDT;
      total += holding.currentValueINR(currentPrice, _usdtToInrRate);
    });
    return total;
  }

  double totalHoldingsValueUSDT(Map<String, CryptoPriceTick> ticks) {
    return totalHoldingsValueINR(ticks) / _usdtToInrRate;
  }

  double totalPortfolioValueINR(Map<String, CryptoPriceTick> ticks) {
    return _cashBalance + totalHoldingsValueINR(ticks);
  }

  double totalPortfolioValueUSDT(Map<String, CryptoPriceTick> ticks) {
    return totalPortfolioValueINR(ticks) / _usdtToInrRate;
  }

  double totalUnrealizedPnlINR(Map<String, CryptoPriceTick> ticks) {
    double totalPnl = 0.0;
    _holdings.forEach((sym, holding) {
      final tick = ticks[sym];
      final currentPrice = tick?.price ?? holding.avgBuyPriceUSDT;
      totalPnl += holding.pnlINR(currentPrice, _usdtToInrRate);
    });
    return totalPnl;
  }

  double totalUnrealizedPnlPercent(Map<String, CryptoPriceTick> ticks) {
    double totalCost = 0.0;
    for (final h in _holdings.values) {
      totalCost += h.totalCostINR;
    }
    if (totalCost <= 0) return 0.0;
    return (totalUnrealizedPnlINR(ticks) / totalCost) * 100;
  }

  // ── Execution Logic ─────────────────────────────────────────────

  TradeExecutionResult executeMarketOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double currentPriceUSDT, // Native price (INR for NSE, USD for Crypto)
  }) {
    final sym = symbol.toUpperCase();
    final asset = TradingAsset.fromSymbol(sym);
    final coinName = asset.name;
    final isIndian = asset.isIndianMarket || asset.currency == 'INR';

    final totalCostINR = isIndian
        ? quantity * currentPriceUSDT
        : quantity * currentPriceUSDT * _usdtToInrRate;

    if (quantity <= 0) {
      return TradeExecutionResult(success: false, message: 'Quantity must be greater than zero.');
    }
    if (currentPriceUSDT <= 0) {
      return TradeExecutionResult(
          success: false, message: 'Market price unavailable. Please try again.');
    }

    if (side == OrderSide.buy) {
      if (!marketService.isRealtimeActive(sym)) {
        return TradeExecutionResult(
          success: false,
          message: 'Real-time feed for $sym is offline or unverified. Purchases are locked to protect against stale executions.',
        );
      }

      if (totalCostINR > availableCash) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient cash balance. Required: ₹${totalCostINR.toStringAsFixed(2)}, Available: ₹${availableCash.toStringAsFixed(2)}',
        );
      }

      _cashBalance -= totalCostINR;

      final existing = _holdings[sym];
      if (existing != null) {
        final newQty = existing.quantity + quantity;
        final newCost = existing.totalCostINR + totalCostINR;
        final newAvg = isIndian
            ? (newCost / newQty)
            : ((newCost / _usdtToInrRate) / newQty);

        _holdings[sym] = existing.copyWith(
          quantity: newQty,
          avgBuyPriceUSDT: newAvg,
          totalCostINR: newCost,
        );
      } else {
        _holdings[sym] = CryptoHolding(
          symbol: sym,
          coinName: coinName,
          quantity: quantity,
          avgBuyPriceUSDT: currentPriceUSDT,
          totalCostINR: totalCostINR,
          currency: asset.currency,
        );
      }

      // Pin newly bought asset for permanent continuous real-time updates
      marketService.addPinnedSymbol(sym);

      final order = TradingOrder(
        id: const Uuid().v4(),
        symbol: sym,
        coinName: coinName,
        side: OrderSide.buy,
        orderType: TradingOrderType.market,
        quantity: quantity,
        targetPriceUSDT: currentPriceUSDT,
        executedPriceUSDT: currentPriceUSDT,
        totalINR: totalCostINR,
        status: OrderStatus.filled,
        createdAt: DateTime.now(),
        filledAt: DateTime.now(),
        currency: asset.currency,
      );

      _orders.insert(0, order);
      _saveToStorage();
      notifyListeners();

      final unitStr = isIndian
          ? '₹${currentPriceUSDT.toStringAsFixed(2)}'
          : '\$${currentPriceUSDT.toStringAsFixed(2)}';

      return TradeExecutionResult(
        success: true,
        message: 'Successfully bought ${isIndian ? quantity.toInt() : quantity.toStringAsFixed(4)} $sym at $unitStr',
        order: order,
      );
    } else {
      // Sell
      final availableQty = getAvailableCoinQuantity(sym);
      if (quantity > availableQty) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient balance. Available to sell: ${availableQty.toStringAsFixed(2)} $sym',
        );
      }

      final existing = _holdings[sym]!;
      final proceedsINR = totalCostINR;
      _cashBalance += proceedsINR;

      if (quantity >= existing.quantity - 1e-7) {
        _holdings.remove(sym);
        _lossAlertsTriggered.remove(sym);
        marketService.removePinnedSymbol(sym);
      } else {
        final fractionSold = quantity / existing.quantity;
        final remainingCost = existing.totalCostINR * (1.0 - fractionSold);
        final remainingQty = existing.quantity - quantity;
        _holdings[sym] = existing.copyWith(
          quantity: remainingQty,
          totalCostINR: remainingCost,
        );
      }

      final order = TradingOrder(
        id: const Uuid().v4(),
        symbol: sym,
        coinName: coinName,
        side: OrderSide.sell,
        orderType: TradingOrderType.market,
        quantity: quantity,
        targetPriceUSDT: currentPriceUSDT,
        executedPriceUSDT: currentPriceUSDT,
        totalINR: proceedsINR,
        status: OrderStatus.filled,
        createdAt: DateTime.now(),
        filledAt: DateTime.now(),
        currency: asset.currency,
      );

      _orders.insert(0, order);
      _saveToStorage();
      notifyListeners();

      final unitStr = isIndian
          ? '₹${currentPriceUSDT.toStringAsFixed(2)}'
          : '\$${currentPriceUSDT.toStringAsFixed(2)}';

      return TradeExecutionResult(
        success: true,
        message: 'Successfully sold ${isIndian ? quantity.toInt() : quantity.toStringAsFixed(4)} $sym at $unitStr',
        order: order,
      );
    }
  }

  TradeExecutionResult createLimitOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double targetPriceUSDT,
  }) {
    final sym = symbol.toUpperCase();
    final asset = TradingAsset.fromSymbol(sym);
    final coinName = asset.name;
    final isIndian = asset.isIndianMarket || asset.currency == 'INR';

    final totalCostINR = isIndian
        ? quantity * targetPriceUSDT
        : quantity * targetPriceUSDT * _usdtToInrRate;

    if (quantity <= 0) {
      return TradeExecutionResult(success: false, message: 'Quantity must be greater than zero.');
    }
    if (targetPriceUSDT <= 0) {
      return TradeExecutionResult(success: false, message: 'Target price must be greater than zero.');
    }

    if (side == OrderSide.buy) {
      if (!marketService.isRealtimeActive(sym)) {
        return TradeExecutionResult(
          success: false,
          message: 'Real-time feed for $sym is offline or unverified. Buy orders are locked to protect against stale executions.',
        );
      }
      if (totalCostINR > availableCash) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient cash to reserve limit order. Required: ₹${totalCostINR.toStringAsFixed(2)}, Available: ₹${availableCash.toStringAsFixed(2)}',
        );
      }
    } else {
      final availableQty = getAvailableCoinQuantity(sym);
      if (quantity > availableQty) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient balance to place sell limit. Available: ${availableQty.toStringAsFixed(2)} $sym',
        );
      }
    }

    final order = TradingOrder(
      id: const Uuid().v4(),
      symbol: sym,
      coinName: coinName,
      side: side,
      orderType: TradingOrderType.limit,
      quantity: quantity,
      targetPriceUSDT: targetPriceUSDT,
      totalINR: totalCostINR,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      currency: asset.currency,
    );

    _orders.insert(0, order);
    _saveToStorage();
    notifyListeners();

    // Test if market price already matches or crosses the limit
    checkLimitOrders(marketService.ticks);

    return TradeExecutionResult(
      success: true,
      message: 'Limit ${side.name.toUpperCase()} order placed.',
      order: order,
    );
  }

  void checkLimitOrders(Map<String, CryptoPriceTick> ticks) {
    if (pendingOrders.isEmpty) return;

    bool updated = false;

    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (!order.isPending) continue;

      final tick = ticks[order.symbol.toUpperCase()];
      if (tick == null || tick.price <= 0) continue;

      final currentPrice = tick.price;
      final isIndian = order.currency == 'INR' || order.symbol.contains('.NS');

      bool shouldFill = false;
      if (order.isBuy && currentPrice <= order.targetPriceUSDT) {
        shouldFill = true;
      } else if (order.isSell && currentPrice >= order.targetPriceUSDT) {
        shouldFill = true;
      }

      if (shouldFill) {
        final executedTotalINR = isIndian
            ? order.quantity * currentPrice
            : order.quantity * currentPrice * _usdtToInrRate;

        if (order.isBuy) {
          final diff = order.totalINR - executedTotalINR;
          _cashBalance -= executedTotalINR;
          if (diff > 0) {
            // Refund difference if bought cheaper than target
          }

          final existing = _holdings[order.symbol.toUpperCase()];
          if (existing != null) {
            final newQty = existing.quantity + order.quantity;
            final newCost = existing.totalCostINR + executedTotalINR;
            final newAvg = isIndian ? (newCost / newQty) : ((newCost / _usdtToInrRate) / newQty);
            _holdings[order.symbol.toUpperCase()] = existing.copyWith(
              quantity: newQty,
              avgBuyPriceUSDT: newAvg,
              totalCostINR: newCost,
            );
          } else {
            _holdings[order.symbol.toUpperCase()] = CryptoHolding(
              symbol: order.symbol,
              coinName: order.coinName,
              quantity: order.quantity,
              avgBuyPriceUSDT: currentPrice,
              totalCostINR: executedTotalINR,
              currency: order.currency,
            );
          }

          // Pin newly bought asset
          marketService.addPinnedSymbol(order.symbol.toUpperCase());
        } else {
          // Sell
          _cashBalance += executedTotalINR;
          final existing = _holdings[order.symbol.toUpperCase()];
          if (existing != null) {
            if (order.quantity >= existing.quantity - 1e-7) {
              _holdings.remove(order.symbol.toUpperCase());
              _lossAlertsTriggered.remove(order.symbol.toUpperCase());
              marketService.removePinnedSymbol(order.symbol.toUpperCase());
            } else {
              final frac = order.quantity / existing.quantity;
              _holdings[order.symbol.toUpperCase()] = existing.copyWith(
                quantity: existing.quantity - order.quantity,
                totalCostINR: existing.totalCostINR * (1.0 - frac),
              );
            }
          }
        }

        _orders[i] = order.copyWith(
          status: OrderStatus.filled,
          executedPriceUSDT: currentPrice,
          totalINR: executedTotalINR,
          filledAt: DateTime.now(),
        );

        updated = true;
      }
    }

    if (updated) {
      _saveToStorage();
      notifyListeners();
    }
  }

  void _evaluateTrailingPeakAlerts(Map<String, CryptoPriceTick> ticks) {
    if (_holdings.isEmpty) return;

    bool holdingsModified = false;

    for (final entry in _holdings.entries) {
      final sym = entry.key;
      var holding = entry.value;
      final tick = ticks[sym];
      if (tick == null || tick.price <= 0) continue;

      final currentPrice = tick.price;
      final isIndian = holding.currency == 'INR' || sym.contains('.NS');

      // 1. Check for higher price
      if (currentPrice > holding.peakPrice) {
        holding = holding.copyWith(
          peakPrice: currentPrice,
          hasReachedHigher: currentPrice > holding.avgBuyPriceUSDT,
          peakTimestamp: DateTime.now(),
        );
        _holdings[sym] = holding;
        holdingsModified = true;

        // Reset alert latch when price recovers back into profit
        _lossAlertsTriggered.remove(sym);
      } else if (!holding.hasReachedHigher && currentPrice > holding.avgBuyPriceUSDT) {
        // Price rose above entry
        holding = holding.copyWith(
          hasReachedHigher: true,
          peakPrice: currentPrice,
          peakTimestamp: DateTime.now(),
        );
        _holdings[sym] = holding;
        holdingsModified = true;
        _lossAlertsTriggered.remove(sym);
      }

      // 2. Alert if starting to lose money after getting a higher
      if (holding.isLosingMoneyAfterHigher(currentPrice)) {
        if (!_lossAlertsTriggered.contains(sym)) {
          _lossAlertsTriggered.add(sym);
          final lossPct = holding.pnlPercent(currentPrice, _usdtToInrRate);
          final drawdownPct = holding.drawdownFromPeakPercent(currentPrice);
          final priceUnit = isIndian ? '₹' : '\$';

          NotificationService.instance.showTradingAlert(
            title: 'POSITION REVERSAL // ${holding.coinName.toUpperCase()}',
            body: '${holding.coinName} ($sym) fell into net loss (${lossPct.toStringAsFixed(2)}%) after reaching peak of $priceUnit${holding.peakPrice.toStringAsFixed(2)} (-${drawdownPct.toStringAsFixed(1)}% drop). Entry was $priceUnit${holding.avgBuyPriceUSDT.toStringAsFixed(2)}.',
            payload: 'trading:$sym',
          );
        }
      }
    }

    if (holdingsModified) {
      _saveToStorage(notifyCloud: false);
    }
  }

  /// Computes aggregate 1-hour market trend across owned holdings or active assets
  HourlyMarketTrend getHourlyTrend() {
    final symbolsToAnalyze = _holdings.isNotEmpty
        ? _holdings.keys.toList()
        : marketService.allActiveSymbols.isNotEmpty
            ? marketService.allActiveSymbols.toList()
            : BinanceMarketService.defaultSymbols;

    double totalPct = 0.0;
    int count = 0;

    for (final sym in symbolsToAnalyze) {
      final pct = marketService.getHourlyChangePercent(sym);
      if (pct != null) {
        totalPct += pct;
        count++;
      }
    }

    if (count == 0) {
      return const HourlyMarketTrend(avgChangePercent: 0.0, sampleCount: 0);
    }

    final avg = totalPct / count;
    return HourlyMarketTrend(avgChangePercent: avg, sampleCount: count);
  }

  /// Computes aggregate 1-day (24H) market trend across owned holdings or active assets
  MarketPeriodTrend getDailyTrend() {
    final symbolsToAnalyze = _holdings.isNotEmpty
        ? _holdings.keys.toList()
        : marketService.allActiveSymbols.isNotEmpty
            ? marketService.allActiveSymbols.toList()
            : BinanceMarketService.defaultSymbols;

    double totalPct = 0.0;
    int count = 0;

    for (final sym in symbolsToAnalyze) {
      final pct = marketService.getDailyChangePercent(sym);
      if (pct != null) {
        totalPct += pct;
        count++;
      }
    }

    if (count == 0) {
      return const MarketPeriodTrend(
        label: 'Daily (24H)',
        avgChangePercent: 0.0,
        sampleCount: 0,
      );
    }

    final avg = totalPct / count;
    return MarketPeriodTrend(
      label: 'Daily (24H)',
      avgChangePercent: avg,
      sampleCount: count,
    );
  }

  /// Computes aggregate 7-day (1W) market trend across owned holdings or active assets
  MarketPeriodTrend getWeeklyTrend() {
    final symbolsToAnalyze = _holdings.isNotEmpty
        ? _holdings.keys.toList()
        : marketService.allActiveSymbols.isNotEmpty
            ? marketService.allActiveSymbols.toList()
            : BinanceMarketService.defaultSymbols;

    double totalPct = 0.0;
    int count = 0;

    for (final sym in symbolsToAnalyze) {
      final pct = marketService.getWeeklyChangePercent(sym);
      if (pct != null) {
        totalPct += pct;
        count++;
      }
    }

    if (count == 0) {
      return const MarketPeriodTrend(
        label: 'Weekly (7D)',
        avgChangePercent: 0.0,
        sampleCount: 0,
      );
    }

    final avg = totalPct / count;
    return MarketPeriodTrend(
      label: 'Weekly (7D)',
      avgChangePercent: avg,
      sampleCount: count,
    );
  }

  /// Computes aggregate 30-day (1M) market trend across owned holdings or active assets
  MarketPeriodTrend getMonthlyTrend() {
    final symbolsToAnalyze = _holdings.isNotEmpty
        ? _holdings.keys.toList()
        : marketService.allActiveSymbols.isNotEmpty
            ? marketService.allActiveSymbols.toList()
            : BinanceMarketService.defaultSymbols;

    double totalPct = 0.0;
    int count = 0;

    for (final sym in symbolsToAnalyze) {
      final pct = marketService.getMonthlyChangePercent(sym);
      if (pct != null) {
        totalPct += pct;
        count++;
      }
    }

    if (count == 0) {
      return const MarketPeriodTrend(
        label: 'Monthly (30D)',
        avgChangePercent: 0.0,
        sampleCount: 0,
      );
    }

    final avg = totalPct / count;
    return MarketPeriodTrend(
      label: 'Monthly (30D)',
      avgChangePercent: avg,
      sampleCount: count,
    );
  }

  /// Aggregates multi-timeframe market telemetry for HUD alert inspection
  MultiTimeframeMarketTelemetry getMultiTimeframeTelemetry() {
    return MultiTimeframeMarketTelemetry(
      hourly: getHourlyTrend(),
      daily: getDailyTrend(),
      weekly: getWeeklyTrend(),
      monthly: getMonthlyTrend(),
    );
  }

  bool cancelOrder(String orderId) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return false;
    final o = _orders[idx];
    if (!o.isPending) return false;

    _orders[idx] = o.copyWith(status: OrderStatus.cancelled);
    _saveToStorage(notifyCloud: true);
    notifyListeners();
    return true;
  }

  // ── State Serialization & Persistence ────────────────────────────

  Map<String, dynamic> getStateMap() => {
        'cashBalance': _cashBalance,
        'usdtToInrRate': _usdtToInrRate,
        'holdings': _holdings.values.map((h) => h.toJson()).toList(),
        'orders': _orders.map((o) => o.toJson()).toList(),
        'lossAlertsTriggered': _lossAlertsTriggered.toList(),
        'lastModified': _lastModified,
      };

  void loadState(Map<String, dynamic> data, {bool force = false}) {
    if (data.isEmpty) return;
    final incomingTs = (data['lastModified'] as num?)?.toInt() ?? 0;
    if (!force && _lastModified > incomingTs && incomingTs > 0) {
      // Local has newer trading state than incoming snapshot
      return;
    }

    _cashBalance =
        (data['cashBalance'] as num?)?.toDouble() ?? defaultStartingBalance;
    _usdtToInrRate =
        (data['usdtToInrRate'] as num?)?.toDouble() ?? defaultInrRate;
    _lastModified =
        incomingTs > 0 ? incomingTs : DateTime.now().millisecondsSinceEpoch;

    _holdings.clear();
    final hList = data['holdings'] as List?;
    if (hList != null) {
      for (final item in hList) {
        if (item is Map) {
          final h = CryptoHolding.fromJson(Map<String, dynamic>.from(item));
          _holdings[h.symbol.toUpperCase()] = h;
        }
      }
    }

    _orders.clear();
    final oList = data['orders'] as List?;
    if (oList != null) {
      for (final item in oList) {
        if (item is Map) {
          final o = TradingOrder.fromJson(Map<String, dynamic>.from(item));
          _orders.add(o);
        }
      }
    }

    _lossAlertsTriggered.clear();
    final alertList = data['lossAlertsTriggered'] as List?;
    if (alertList != null) {
      for (final a in alertList) {
        _lossAlertsTriggered.add(a.toString());
      }
    }

    // Pin holding symbols for live market ticker updates
    for (final sym in _holdings.keys) {
      marketService.addPinnedSymbol(sym);
    }

    _saveToStorage(notifyCloud: false);
    notifyListeners();
  }

  Future<void> _saveToStorage({bool notifyCloud = true}) async {
    _lastModified = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = getStateMap();
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving paper trading state: $e');
    }
    if (notifyCloud) {
      onStateChanged?.call();
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      loadState(data, force: true);
    } catch (e) {
      debugPrint('Error loading paper trading state: $e');
    }
  }
}
