import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/models/trading_psychology_models.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:missions/src/utils/trading_risk_math.dart' as risk_math;

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

  // ── Smart Money Protocol state ────────────────────────────────────
  final List<TradeRecord> _tradeRecords = []; // newest first
  List<TradeRecord> get tradeRecords => List.unmodifiable(_tradeRecords);

  TradingRiskSettings _riskSettings = const TradingRiskSettings();
  TradingRiskSettings get riskSettings => _riskSettings;

  final List<EquitySnapshot> _equitySnapshots = [];
  List<EquitySnapshot> get equitySnapshots => List.unmodifiable(_equitySnapshots);

  double _equityPeakINR = defaultStartingBalance;
  double get equityPeakINR => _equityPeakINR;

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
    checkProtectiveStops(marketService.ticks);
    _evaluateTrailingPeakAlerts(marketService.ticks);
    recordEquitySnapshot(marketService.ticks);
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
    // Risk settings persist across a reset; the journal & equity curve do not.
    _tradeRecords.clear();
    _equitySnapshots.clear();
    _equityPeakINR = balance;
    await _saveToStorage(notifyCloud: true);
    notifyListeners();
  }

  Future<void> updateRiskSettings(TradingRiskSettings settings) async {
    _riskSettings = settings;
    await _saveToStorage();
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
    TradePlan? plan,
    double? stopPrice,
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

      // ── Smart Money Protocol guards ──────────────────────────────
      final cap = _riskSettings.dailyTradeCap;
      if (cap > 0 && tradesToday >= cap) {
        return TradeExecutionResult(
          success: false,
          message: 'MACHINE-GUN GUARD: $tradesToday buys already today. Plan your trades when the market is closed.',
        );
      }

      if (_riskSettings.strictRiskGuard &&
          plan?.riskPercentOfPortfolio != null &&
          plan!.riskPercentOfPortfolio! > _riskSettings.maxRiskPercent + 1e-9) {
        return TradeExecutionResult(
          success: false,
          message:
              'RISK RULE: this idea risks ${plan.riskPercentOfPortfolio!.toStringAsFixed(2)}% of the portfolio; your max is ${_riskSettings.maxRiskPercent.toStringAsFixed(2)}%. Reduce size or move the stop closer.',
        );
      }

      if (_riskSettings.requireChecklist && (plan?.checklistScore ?? 0) < 3) {
        return TradeExecutionResult(
          success: false,
          message: 'GATE: tick at least 3 of 5 checks before buying.',
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
          stopPrice: _mergeStop(existing.stopPrice, stopPrice),
          initialStopPrice: existing.initialStopPrice ?? stopPrice,
          plannedRiskINR: (existing.plannedRiskINR ?? 0.0) + (plan?.plannedRiskINR ?? 0.0),
          openedAt: existing.openedAt ?? DateTime.now(),
          plan: existing.plan ?? plan,
        );
      } else {
        _holdings[sym] = CryptoHolding(
          symbol: sym,
          coinName: coinName,
          quantity: quantity,
          avgBuyPriceUSDT: currentPriceUSDT,
          totalCostINR: totalCostINR,
          currency: asset.currency,
          stopPrice: (stopPrice != null && stopPrice > 0) ? stopPrice : null,
          initialStopPrice: stopPrice,
          plannedRiskINR: plan?.plannedRiskINR,
          openedAt: DateTime.now(),
          plan: plan,
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
        plan: plan,
      );

      _orders.insert(0, order);
      recordEquitySnapshot(marketService.ticks);
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
      return _executeSell(
        sym: sym,
        asset: asset,
        coinName: coinName,
        isIndian: isIndian,
        quantity: quantity,
        currentPriceNative: currentPriceUSDT,
        proceedsINR: totalCostINR,
        orderType: TradingOrderType.market,
        exitReason: TradeExitReason.manual,
      );
    }
  }

  /// Merges an incoming stop price with an existing one: a stop can only rise.
  double? _mergeStop(double? existingStop, double? incomingStop) {
    final e = existingStop ?? 0.0;
    final i = incomingStop ?? 0.0;
    final merged = e > i ? e : i;
    return merged > 0 ? merged : existingStop;
  }

  /// Shared sell execution path used by market sells, protective stop fills,
  /// and (indirectly) limit sell fills. Records the journal entry BEFORE the
  /// holding is mutated or removed.
  TradeExecutionResult _executeSell({
    required String sym,
    required TradingAsset asset,
    required String coinName,
    required bool isIndian,
    required double quantity,
    required double currentPriceNative,
    required double proceedsINR,
    required TradingOrderType orderType,
    required TradeExitReason exitReason,
    String? note,
  }) {
    final availableQty = getAvailableCoinQuantity(sym);
    if (quantity > availableQty) {
      return TradeExecutionResult(
        success: false,
        message: 'Insufficient balance. Available to sell: ${availableQty.toStringAsFixed(2)} $sym',
      );
    }

    final existing = _holdings[sym]!;
    _recordClose(sym, quantity, currentPriceNative, proceedsINR, exitReason);
    _cashBalance += proceedsINR;

    if (quantity >= existing.quantity - 1e-7) {
      _holdings.remove(sym);
      _lossAlertsTriggered.remove(sym);
      marketService.removePinnedSymbol(sym);
    } else {
      final fractionSold = quantity / existing.quantity;
      final remainingCost = existing.totalCostINR * (1.0 - fractionSold);
      final remainingQty = existing.quantity - quantity;
      final remainingRisk =
          existing.plannedRiskINR == null ? null : existing.plannedRiskINR! * (1.0 - fractionSold);
      _holdings[sym] = existing.copyWith(
        quantity: remainingQty,
        totalCostINR: remainingCost,
        plannedRiskINR: remainingRisk,
      );
    }

    final order = TradingOrder(
      id: const Uuid().v4(),
      symbol: sym,
      coinName: coinName,
      side: OrderSide.sell,
      orderType: orderType,
      quantity: quantity,
      targetPriceUSDT: currentPriceNative,
      executedPriceUSDT: currentPriceNative,
      totalINR: proceedsINR,
      status: OrderStatus.filled,
      createdAt: DateTime.now(),
      filledAt: DateTime.now(),
      currency: asset.currency,
      note: note,
    );

    _orders.insert(0, order);
    recordEquitySnapshot(marketService.ticks);
    _saveToStorage();
    notifyListeners();

    final unitStr = isIndian
        ? '₹${currentPriceNative.toStringAsFixed(2)}'
        : '\$${currentPriceNative.toStringAsFixed(2)}';

    return TradeExecutionResult(
      success: true,
      message: 'Successfully sold ${isIndian ? quantity.toInt() : quantity.toStringAsFixed(4)} $sym at $unitStr',
      order: order,
    );
  }

  /// Records a closed (or partially closed) round trip into the journal.
  /// Must be called BEFORE the holding is mutated or removed.
  void _recordClose(
    String sym,
    double qtySold,
    double exitPriceNative,
    double proceedsINR,
    TradeExitReason reason,
  ) {
    final holding = _holdings[sym];
    if (holding == null || holding.quantity <= 0 || qtySold <= 0) return;

    final fraction = (qtySold / holding.quantity).clamp(0.0, 1.0);
    final costINR = holding.totalCostINR * fraction;
    final plannedRisk = holding.plannedRiskINR == null ? null : holding.plannedRiskINR! * fraction;
    final openedAt = holding.openedAt ?? _earliestBuyFilledAt(sym) ?? DateTime.now();

    final record = TradeRecord(
      id: const Uuid().v4(),
      symbol: sym,
      coinName: holding.coinName,
      currency: holding.currency,
      quantity: qtySold,
      entryAvgPrice: holding.avgBuyPriceUSDT,
      exitAvgPrice: exitPriceNative,
      costINR: costINR,
      proceedsINR: proceedsINR,
      plannedRiskINR: plannedRisk,
      openedAt: openedAt,
      closedAt: DateTime.now(),
      exitReason: reason,
      plan: holding.plan,
    );

    _tradeRecords.insert(0, record);
  }

  DateTime? _earliestBuyFilledAt(String sym) {
    DateTime? earliest;
    for (final o in _orders) {
      if (o.isBuy && o.symbol.toUpperCase() == sym.toUpperCase() && o.filledAt != null) {
        if (earliest == null || o.filledAt!.isBefore(earliest)) earliest = o.filledAt;
      }
    }
    return earliest;
  }

  TradeExecutionResult createLimitOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double targetPriceUSDT,
    TradePlan? plan,
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
      plan: plan,
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
          final planStop = order.plan?.stopPrice;
          final planRisk = order.plan?.plannedRiskINR;
          if (existing != null) {
            final newQty = existing.quantity + order.quantity;
            final newCost = existing.totalCostINR + executedTotalINR;
            final newAvg = isIndian ? (newCost / newQty) : ((newCost / _usdtToInrRate) / newQty);
            _holdings[order.symbol.toUpperCase()] = existing.copyWith(
              quantity: newQty,
              avgBuyPriceUSDT: newAvg,
              totalCostINR: newCost,
              stopPrice: _mergeStop(existing.stopPrice, planStop),
              initialStopPrice: existing.initialStopPrice ?? planStop,
              plannedRiskINR: (existing.plannedRiskINR ?? 0.0) + (planRisk ?? 0.0),
              openedAt: existing.openedAt ?? DateTime.now(),
              plan: existing.plan ?? order.plan,
            );
          } else {
            _holdings[order.symbol.toUpperCase()] = CryptoHolding(
              symbol: order.symbol,
              coinName: order.coinName,
              quantity: order.quantity,
              avgBuyPriceUSDT: currentPrice,
              totalCostINR: executedTotalINR,
              currency: order.currency,
              stopPrice: (planStop != null && planStop > 0) ? planStop : null,
              initialStopPrice: planStop,
              plannedRiskINR: planRisk,
              openedAt: DateTime.now(),
              plan: order.plan,
            );
          }

          // Pin newly bought asset
          marketService.addPinnedSymbol(order.symbol.toUpperCase());
        } else {
          // Sell
          final existing = _holdings[order.symbol.toUpperCase()];
          if (existing != null) {
            _recordClose(
              order.symbol.toUpperCase(),
              order.quantity,
              currentPrice,
              executedTotalINR,
              TradeExitReason.limitFilled,
            );
          }
          _cashBalance += executedTotalINR;
          if (existing != null) {
            if (order.quantity >= existing.quantity - 1e-7) {
              _holdings.remove(order.symbol.toUpperCase());
              _lossAlertsTriggered.remove(order.symbol.toUpperCase());
              marketService.removePinnedSymbol(order.symbol.toUpperCase());
            } else {
              final frac = order.quantity / existing.quantity;
              final remainingRisk =
                  existing.plannedRiskINR == null ? null : existing.plannedRiskINR! * (1.0 - frac);
              _holdings[order.symbol.toUpperCase()] = existing.copyWith(
                quantity: existing.quantity - order.quantity,
                totalCostINR: existing.totalCostINR * (1.0 - frac),
                plannedRiskINR: remainingRisk,
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
      recordEquitySnapshot(ticks);
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

  // ── Smart Money Protocol: protective stops ───────────────────────

  /// Sells any holding whose live price has fallen to or through its
  /// protective stop. Called on every tick, before the trailing-peak alert.
  void checkProtectiveStops(Map<String, CryptoPriceTick> ticks) {
    if (_holdings.isEmpty) return;

    final hits = <MapEntry<String, double>>[];
    for (final entry in _holdings.entries) {
      final stop = entry.value.stopPrice;
      if (stop == null || stop <= 0) continue;
      final tick = ticks[entry.key];
      if (tick == null || tick.price <= 0) continue;
      if (tick.price <= stop) {
        if (getAvailableCoinQuantity(entry.key) <= 0) continue;
        hits.add(MapEntry(entry.key, tick.price));
      }
    }

    for (final hit in hits) {
      final sym = hit.key;
      final price = hit.value;
      final holding = _holdings[sym];
      if (holding == null) continue;

      final qty = getAvailableCoinQuantity(sym);
      if (qty <= 0) continue;

      final asset = TradingAsset.fromSymbol(sym);
      final isIndian = asset.isIndianMarket || asset.currency == 'INR';
      final proceedsINR = isIndian ? qty * price : qty * price * _usdtToInrRate;

      final result = _executeSell(
        sym: sym,
        asset: asset,
        coinName: holding.coinName,
        isIndian: isIndian,
        quantity: qty,
        currentPriceNative: price,
        proceedsINR: proceedsINR,
        orderType: TradingOrderType.stop,
        exitReason: TradeExitReason.stopHit,
        note: 'PROTECTIVE STOP HIT @ ${price.toStringAsFixed(2)}',
      );

      if (result.success) {
        try {
          NotificationService.instance.showTradingAlert(
            title: 'STOP HIT // ${holding.coinName.toUpperCase()}',
            body:
                '${holding.coinName} ($sym) hit its protective stop at ${isIndian ? '₹' : '\$'}${price.toStringAsFixed(2)}. Position closed for ${isIndian ? '₹' : '\$'}${proceedsINR.toStringAsFixed(2)}.',
            payload: 'trading:$sym',
          );
        } catch (_) {
          // NotificationService may be un-initialized in tests / headless runs.
        }
      }
    }
  }

  /// Sets (or raises) a holding's protective stop. A stop can only be raised,
  /// never lowered — the defense-first rule that gives the app its name.
  TradeExecutionResult setProtectiveStop(String symbol, double newStop) {
    final sym = symbol.toUpperCase();
    final holding = _holdings[sym];
    if (holding == null) {
      return TradeExecutionResult(success: false, message: 'No open position for $sym.');
    }
    if (newStop <= 0) {
      return TradeExecutionResult(success: false, message: 'Stop price must be greater than zero.');
    }

    final tick = marketService.getTick(sym);
    final currentPrice = (tick != null && tick.price > 0) ? tick.price : holding.avgBuyPriceUSDT;

    if (newStop >= currentPrice) {
      return TradeExecutionResult(success: false, message: 'A stop must sit below the current price.');
    }

    if (holding.stopPrice != null && newStop < holding.stopPrice!) {
      return TradeExecutionResult(
        success: false,
        message:
            "NEVER WIDEN A STOP: it's at ${holding.stopPrice!.toStringAsFixed(2)}. You can raise it, exit, or leave it.",
      );
    }

    _holdings[sym] = holding.copyWith(
      stopPrice: newStop,
      initialStopPrice: holding.initialStopPrice ?? newStop,
    );
    _saveToStorage();
    notifyListeners();

    try {
      NotificationService.instance.showTradingAlert(
        title: 'STOP UPDATED // ${holding.coinName.toUpperCase()}',
        body: 'Protective stop for $sym set to ${newStop.toStringAsFixed(2)}.',
        payload: 'trading:$sym',
      );
    } catch (_) {
      // NotificationService may be un-initialized in tests / headless runs.
    }

    return TradeExecutionResult(success: true, message: 'Stop set to ${newStop.toStringAsFixed(2)}.');
  }

  /// Raises the stop to breakeven (the average entry price).
  TradeExecutionResult raiseStopToBreakeven(String symbol) {
    final sym = symbol.toUpperCase();
    final holding = _holdings[sym];
    if (holding == null) {
      return TradeExecutionResult(success: false, message: 'No open position for $sym.');
    }
    final tick = marketService.getTick(sym);
    final currentPrice = (tick != null && tick.price > 0) ? tick.price : holding.avgBuyPriceUSDT;
    if (currentPrice <= holding.avgBuyPriceUSDT) {
      return TradeExecutionResult(
        success: false,
        message: 'Price must be above your average entry to move the stop to breakeven.',
      );
    }
    return setProtectiveStop(sym, holding.avgBuyPriceUSDT);
  }

  /// Trails the stop a fixed percentage below the current live price.
  TradeExecutionResult trailStop(String symbol, double percentBelowCurrent) {
    final sym = symbol.toUpperCase();
    final holding = _holdings[sym];
    if (holding == null) {
      return TradeExecutionResult(success: false, message: 'No open position for $sym.');
    }
    final tick = marketService.getTick(sym);
    final currentPrice = (tick != null && tick.price > 0) ? tick.price : holding.avgBuyPriceUSDT;
    final newStop = currentPrice * (1 - percentBelowCurrent / 100);
    return setProtectiveStop(sym, newStop);
  }

  /// True when a position is up 5%+ and its stop hasn't been moved to (or past) breakeven yet.
  bool shouldSuggestBreakeven(CryptoHolding h, double currentPrice) {
    if (h.avgBuyPriceUSDT <= 0) return false;
    final gainPercent = (currentPrice - h.avgBuyPriceUSDT) / h.avgBuyPriceUSDT * 100;
    return gainPercent >= 5 && (h.stopPrice == null || h.stopPrice! < h.avgBuyPriceUSDT);
  }

  /// Number of BUY orders filled today (local date) — feeds the daily trade cap guard.
  int get tradesToday {
    final now = DateTime.now();
    return _orders.where((o) {
      final filledAt = o.filledAt;
      return o.isBuy &&
          o.isFilled &&
          filledAt != null &&
          filledAt.year == now.year &&
          filledAt.month == now.month &&
          filledAt.day == now.day;
    }).length;
  }

  // ── Smart Money Protocol: journal, stats & equity curve ──────────

  /// Records (or updates) today's equity snapshot. Cheap: one entry per
  /// calendar day, same-day calls replace the latest value.
  void recordEquitySnapshot(Map<String, CryptoPriceTick> ticks) {
    final now = DateTime.now();
    final value = totalPortfolioValueINR(ticks);
    if (value > _equityPeakINR) _equityPeakINR = value;

    if (_equitySnapshots.isNotEmpty) {
      final last = _equitySnapshots.last;
      final sameDay =
          last.at.year == now.year && last.at.month == now.month && last.at.day == now.day;
      if (sameDay) {
        _equitySnapshots[_equitySnapshots.length - 1] = EquitySnapshot(at: now, valueINR: value);
        return;
      }
    }

    _equitySnapshots.add(EquitySnapshot(at: now, valueINR: value));
    while (_equitySnapshots.length > 400) {
      _equitySnapshots.removeAt(0);
    }
  }

  /// Expectancy / drawdown statistics computed from the trade journal.
  SmartMoneyStats statsFor(Map<String, CryptoPriceTick> ticks) {
    return SmartMoneyStats.compute(
      records: _tradeRecords,
      snapshots: _equitySnapshots,
      currentEquityINR: totalPortfolioValueINR(ticks),
      startingEquityINR: defaultStartingBalance,
    );
  }

  /// The risk percent the drawdown ladder currently suggests, derived from
  /// the configured base risk and the account's current drawdown.
  double suggestedRiskPercentFor(Map<String, CryptoPriceTick> ticks) {
    final stats = statsFor(ticks);
    return risk_math.suggestedRiskPercent(_riskSettings.baseRiskPercent, stats.currentDrawdownPercent);
  }

  /// Attaches a post-trade review (process grade, lesson, followed-plan) to a journal entry.
  Future<void> reviewTrade(
    String recordId, {
    bool? followedPlan,
    String? processGrade,
    String? lesson,
  }) async {
    final idx = _tradeRecords.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    _tradeRecords[idx] = _tradeRecords[idx].copyWith(
      followedPlan: followedPlan,
      processGrade: processGrade,
      lesson: lesson,
      reviewedAt: DateTime.now(),
    );
    await _saveToStorage();
    notifyListeners();
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
        'tradeRecords': _tradeRecords.map((r) => r.toJson()).toList(),
        'riskSettings': _riskSettings.toJson(),
        'equitySnapshots': _equitySnapshots.map((s) => s.toJson()).toList(),
        'equityPeakINR': _equityPeakINR,
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

    _tradeRecords.clear();
    final trList = data['tradeRecords'] as List?;
    if (trList != null) {
      for (final item in trList) {
        if (item is Map) {
          _tradeRecords.add(TradeRecord.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final riskSettingsMap = data['riskSettings'];
    _riskSettings = riskSettingsMap is Map
        ? TradingRiskSettings.fromJson(Map<String, dynamic>.from(riskSettingsMap))
        : const TradingRiskSettings();

    _equitySnapshots.clear();
    final esList = data['equitySnapshots'] as List?;
    if (esList != null) {
      for (final item in esList) {
        if (item is Map) {
          _equitySnapshots.add(EquitySnapshot.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    _equityPeakINR = (data['equityPeakINR'] as num?)?.toDouble() ?? _cashBalance;

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
