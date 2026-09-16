import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/services/binance_market_service.dart';

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

  final BinanceMarketService marketService;

  double _cashBalance = defaultStartingBalance;
  double get cashBalance => _cashBalance;

  double _usdtToInrRate = defaultInrRate;
  double get usdtToInrRate => _usdtToInrRate;

  final Map<String, CryptoHolding> _holdings = {};
  Map<String, CryptoHolding> get holdings => Map.unmodifiable(_holdings);

  final List<TradingOrder> _orders = [];
  List<TradingOrder> get orders => List.unmodifiable(_orders);

  List<TradingOrder> get pendingOrders =>
      _orders.where((o) => o.isPending).toList(growable: false);

  List<TradingOrder> get filledOrders =>
      _orders.where((o) => o.isFilled).toList(growable: false);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  PaperTradingProvider({required this.marketService}) {
    _init();
    marketService.addListener(_onMarketTicksUpdated);
  }

  Future<void> _init() async {
    await _loadFromStorage();
    _isInitialized = true;
    marketService.start();
    notifyListeners();
  }

  void _onMarketTicksUpdated() {
    checkLimitOrders(marketService.ticks);
    notifyListeners();
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
      final currentPriceUSDT = tick?.price ?? holding.avgBuyPriceUSDT;
      total += holding.currentValueINR(currentPriceUSDT, _usdtToInrRate);
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
    double pnl = 0.0;
    _holdings.forEach((sym, holding) {
      final tick = ticks[sym];
      final currentPriceUSDT = tick?.price ?? holding.avgBuyPriceUSDT;
      pnl += holding.pnlINR(currentPriceUSDT, _usdtToInrRate);
    });
    return pnl;
  }

  double totalUnrealizedPnlPercent(Map<String, CryptoPriceTick> ticks) {
    double totalCost = 0.0;
    _holdings.forEach((_, h) => totalCost += h.totalCostINR);
    if (totalCost <= 0) return 0.0;
    return (totalUnrealizedPnlINR(ticks) / totalCost) * 100.0;
  }

  // ── Trade Execution ─────────────────────────────────────────────

  TradeExecutionResult executeMarketOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double currentPriceUSDT,
  }) {
    final sym = symbol.toUpperCase();
    final coinMeta = CryptoSymbol.fromRaw(sym);
    final coinName = coinMeta?.name ?? sym;
    final totalCostINR = quantity * currentPriceUSDT * _usdtToInrRate;

    if (quantity <= 0) {
      return TradeExecutionResult(success: false, message: 'Quantity must be greater than zero.');
    }
    if (currentPriceUSDT <= 0) {
      return TradeExecutionResult(success: false, message: 'Invalid market price.');
    }

    if (side == OrderSide.buy) {
      if (totalCostINR > availableCash) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient cash. Required: ₹${totalCostINR.toStringAsFixed(2)}, Available: ₹${availableCash.toStringAsFixed(2)}',
        );
      }

      // Deduct cash
      _cashBalance -= totalCostINR;

      // Update or create holding position
      final existing = _holdings[sym];
      if (existing != null) {
        final newQty = existing.quantity + quantity;
        final newCost = existing.totalCostINR + totalCostINR;
        final newAvgUSDT = (newCost / _usdtToInrRate) / newQty;
        _holdings[sym] = existing.copyWith(
          quantity: newQty,
          avgBuyPriceUSDT: newAvgUSDT,
          totalCostINR: newCost,
        );
      } else {
        _holdings[sym] = CryptoHolding(
          symbol: sym,
          coinName: coinName,
          quantity: quantity,
          avgBuyPriceUSDT: currentPriceUSDT,
          totalCostINR: totalCostINR,
        );
      }

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
      );

      _orders.insert(0, order);
      _saveToStorage();
      notifyListeners();

      return TradeExecutionResult(
        success: true,
        message: 'Successfully bought ${quantity.toStringAsFixed(4)} $sym at \$${currentPriceUSDT.toStringAsFixed(2)}',
        order: order,
      );
    } else {
      // Sell
      final availableQty = getAvailableCoinQuantity(sym);
      if (quantity > availableQty) {
        return TradeExecutionResult(
          success: false,
          message:
              'Insufficient coins. Available to sell: ${availableQty.toStringAsFixed(4)} $sym',
        );
      }

      final existing = _holdings[sym]!;
      final proceedsINR = totalCostINR;
      _cashBalance += proceedsINR;

      if (quantity >= existing.quantity - 1e-7) {
        _holdings.remove(sym);
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
      );

      _orders.insert(0, order);
      _saveToStorage();
      notifyListeners();

      return TradeExecutionResult(
        success: true,
        message: 'Successfully sold ${quantity.toStringAsFixed(4)} $sym at \$${currentPriceUSDT.toStringAsFixed(2)}',
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
    final coinMeta = CryptoSymbol.fromRaw(sym);
    final coinName = coinMeta?.name ?? sym;
    final totalCostINR = quantity * targetPriceUSDT * _usdtToInrRate;

    if (quantity <= 0) {
      return TradeExecutionResult(success: false, message: 'Quantity must be greater than zero.');
    }
    if (targetPriceUSDT <= 0) {
      return TradeExecutionResult(success: false, message: 'Target price must be greater than zero.');
    }

    if (side == OrderSide.buy) {
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
              'Insufficient coins available to place sell limit. Available: ${availableQty.toStringAsFixed(4)} $sym',
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
    );

    _orders.insert(0, order);
    _saveToStorage();
    notifyListeners();

    // Immediately test if market price already matches or crosses the limit
    checkLimitOrders(marketService.ticks);

    return TradeExecutionResult(
      success: true,
      message:
          'Limit ${side.name.toUpperCase()} order placed for ${quantity.toStringAsFixed(4)} $sym at \$${targetPriceUSDT.toStringAsFixed(2)}',
      order: order,
    );
  }

  void cancelOrder(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1 && _orders[index].isPending) {
      final updated = _orders[index].copyWith(status: OrderStatus.cancelled);
      _orders[index] = updated;
      _saveToStorage();
      notifyListeners();
    }
  }

  void checkLimitOrders(Map<String, CryptoPriceTick> ticks) {
    bool stateChanged = false;

    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (!order.isPending) continue;

      final tick = ticks[order.symbol.toUpperCase()];
      if (tick == null || tick.price <= 0) continue;

      bool shouldFill = false;
      if (order.isBuy && tick.price <= order.targetPriceUSDT) {
        // Buy limit triggered!
        shouldFill = true;
      } else if (order.isSell && tick.price >= order.targetPriceUSDT) {
        // Sell limit triggered!
        shouldFill = true;
      }

      if (shouldFill) {
        final fillPriceUSDT = tick.price;
        final totalCostINR = order.quantity * fillPriceUSDT * _usdtToInrRate;

        if (order.isBuy) {
          _cashBalance -= totalCostINR;
          final existing = _holdings[order.symbol];
          if (existing != null) {
            final newQty = existing.quantity + order.quantity;
            final newCost = existing.totalCostINR + totalCostINR;
            final newAvgUSDT = (newCost / _usdtToInrRate) / newQty;
            _holdings[order.symbol] = existing.copyWith(
              quantity: newQty,
              avgBuyPriceUSDT: newAvgUSDT,
              totalCostINR: newCost,
            );
          } else {
            _holdings[order.symbol] = CryptoHolding(
              symbol: order.symbol,
              coinName: order.coinName,
              quantity: order.quantity,
              avgBuyPriceUSDT: fillPriceUSDT,
              totalCostINR: totalCostINR,
            );
          }
        } else {
          // Sell limit filled
          _cashBalance += totalCostINR;
          final existing = _holdings[order.symbol];
          if (existing != null) {
            if (order.quantity >= existing.quantity - 1e-7) {
              _holdings.remove(order.symbol);
            } else {
              final fractionSold = order.quantity / existing.quantity;
              final remainingCost = existing.totalCostINR * (1.0 - fractionSold);
              final remainingQty = existing.quantity - order.quantity;
              _holdings[order.symbol] = existing.copyWith(
                quantity: remainingQty,
                totalCostINR: remainingCost,
              );
            }
          }
        }

        _orders[i] = order.copyWith(
          status: OrderStatus.filled,
          executedPriceUSDT: fillPriceUSDT,
          totalINR: totalCostINR,
          filledAt: DateTime.now(),
        );

        stateChanged = true;
      }
    }

    if (stateChanged) {
      _saveToStorage();
    }
  }

  // ── Persistence ─────────────────────────────────────────────────

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'cashBalance': _cashBalance,
        'usdtToInrRate': _usdtToInrRate,
        'holdings': _holdings.map((k, v) => MapEntry(k, v.toJson())),
        'orders': _orders.map((o) => o.toJson()).toList(),
      };
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving paper trading state: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return;

      final Map<String, dynamic> json = jsonDecode(raw);
      if (json['cashBalance'] != null) {
        _cashBalance = (json['cashBalance'] as num).toDouble();
      }
      if (json['usdtToInrRate'] != null) {
        _usdtToInrRate = (json['usdtToInrRate'] as num).toDouble();
      }
      if (json['holdings'] != null) {
        _holdings.clear();
        final holdingsMap = json['holdings'] as Map<String, dynamic>;
        holdingsMap.forEach((k, v) {
          _holdings[k] = CryptoHolding.fromJson(v as Map<String, dynamic>);
        });
      }
      if (json['orders'] != null) {
        _orders.clear();
        final ordersList = json['orders'] as List<dynamic>;
        for (final o in ordersList) {
          _orders.add(TradingOrder.fromJson(o as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('Error loading paper trading state: $e');
    }
  }

  @override
  void dispose() {
    marketService.removeListener(_onMarketTicksUpdated);
    super.dispose();
  }
}
