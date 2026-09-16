import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Supported crypto symbols for paper trading
enum CryptoSymbol {
  btc('BTCUSDT', 'Bitcoin', 'BTC', 4, Color(0xFFF7931A)),
  eth('ETHUSDT', 'Ethereum', 'ETH', 4, Color(0xFF627EEA)),
  sol('SOLUSDT', 'Solana', 'SOL', 3, Color(0xFF14F195));

  final String rawSymbol;
  final String name;
  final String baseAsset;
  final int decimals;
  final Color brandColor;

  const CryptoSymbol(this.rawSymbol, this.name, this.baseAsset, this.decimals, this.brandColor);

  String get pairLabel => '$baseAsset/USDT';

  IconData get icon {
    switch (this) {
      case CryptoSymbol.btc:
        return Icons.currency_bitcoin_rounded;
      case CryptoSymbol.eth:
        return MdiIcons.rhombusOutline;
      case CryptoSymbol.sol:
        return Icons.bolt_rounded;
    }
  }

  static CryptoSymbol? fromRaw(String raw) {
    for (final s in CryptoSymbol.values) {
      if (s.rawSymbol.toUpperCase() == raw.toUpperCase()) return s;
    }
    return null;
  }
}

/// Realtime price tick from Binance WebSocket
class CryptoPriceTick {
  final String symbol;
  final double price;
  final double changePercent24h;
  final double high24h;
  final double low24h;
  final double volume24h;
  final DateTime timestamp;

  CryptoPriceTick({
    required this.symbol,
    required this.price,
    required this.changePercent24h,
    required this.high24h,
    required this.low24h,
    required this.volume24h,
    required this.timestamp,
  });

  bool get isPositive => changePercent24h >= 0;

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);

  factory CryptoPriceTick.fromBinanceWs(Map<String, dynamic> data) {
    final symbol = (data['s'] as String?) ?? '';
    final price = double.tryParse(data['c']?.toString() ?? '0') ?? 0.0;
    final changePercent = double.tryParse(data['P']?.toString() ?? '0') ?? 0.0;
    final high = double.tryParse(data['h']?.toString() ?? '0') ?? 0.0;
    final low = double.tryParse(data['l']?.toString() ?? '0') ?? 0.0;
    final volume = double.tryParse(data['v']?.toString() ?? '0') ?? 0.0;
    final eventTime = data['E'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['E'] as int)
        : DateTime.now();

    return CryptoPriceTick(
      symbol: symbol,
      price: price,
      changePercent24h: changePercent,
      high24h: high,
      low24h: low,
      volume24h: volume,
      timestamp: eventTime,
    );
  }

  factory CryptoPriceTick.fromBinanceRest(Map<String, dynamic> data) {
    final symbol = (data['symbol'] as String?) ?? '';
    final price = double.tryParse(data['lastPrice']?.toString() ?? '0') ?? 0.0;
    final changePercent = double.tryParse(data['priceChangePercent']?.toString() ?? '0') ?? 0.0;
    final high = double.tryParse(data['highPrice']?.toString() ?? '0') ?? 0.0;
    final low = double.tryParse(data['lowPrice']?.toString() ?? '0') ?? 0.0;
    final volume = double.tryParse(data['volume']?.toString() ?? '0') ?? 0.0;

    return CryptoPriceTick(
      symbol: symbol,
      price: price,
      changePercent24h: changePercent,
      high24h: high,
      low24h: low,
      volume24h: volume,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'price': price,
        'changePercent24h': changePercent24h,
        'high24h': high24h,
        'low24h': low24h,
        'volume24h': volume24h,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CryptoPriceTick.fromJson(Map<String, dynamic> json) => CryptoPriceTick(
        symbol: json['symbol'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        changePercent24h: (json['changePercent24h'] as num?)?.toDouble() ?? 0.0,
        high24h: (json['high24h'] as num?)?.toDouble() ?? 0.0,
        low24h: (json['low24h'] as num?)?.toDouble() ?? 0.0,
        volume24h: (json['volume24h'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Simulated holding position
class CryptoHolding {
  final String symbol;
  final String coinName;
  final double quantity;
  final double avgBuyPriceUSDT;
  final double totalCostINR;

  CryptoHolding({
    required this.symbol,
    required this.coinName,
    required this.quantity,
    required this.avgBuyPriceUSDT,
    required this.totalCostINR,
  });

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);

  double currentValueUSDT(double currentPriceUSDT) => quantity * currentPriceUSDT;

  double currentValueINR(double currentPriceUSDT, double usdtToInrRate) =>
      currentValueUSDT(currentPriceUSDT) * usdtToInrRate;

  double pnlINR(double currentPriceUSDT, double usdtToInrRate) =>
      currentValueINR(currentPriceUSDT, usdtToInrRate) - totalCostINR;

  double pnlPercent(double currentPriceUSDT, double usdtToInrRate) {
    if (totalCostINR <= 0) return 0.0;
    return (pnlINR(currentPriceUSDT, usdtToInrRate) / totalCostINR) * 100;
  }

  CryptoHolding copyWith({
    String? symbol,
    String? coinName,
    double? quantity,
    double? avgBuyPriceUSDT,
    double? totalCostINR,
  }) {
    return CryptoHolding(
      symbol: symbol ?? this.symbol,
      coinName: coinName ?? this.coinName,
      quantity: quantity ?? this.quantity,
      avgBuyPriceUSDT: avgBuyPriceUSDT ?? this.avgBuyPriceUSDT,
      totalCostINR: totalCostINR ?? this.totalCostINR,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'coinName': coinName,
        'quantity': quantity,
        'avgBuyPriceUSDT': avgBuyPriceUSDT,
        'totalCostINR': totalCostINR,
      };

  factory CryptoHolding.fromJson(Map<String, dynamic> json) => CryptoHolding(
        symbol: json['symbol'] as String? ?? '',
        coinName: json['coinName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        avgBuyPriceUSDT: (json['avgBuyPriceUSDT'] as num?)?.toDouble() ?? 0.0,
        totalCostINR: (json['totalCostINR'] as num?)?.toDouble() ?? 0.0,
      );
}

enum OrderSide { buy, sell }

enum TradingOrderType { market, limit }

enum OrderStatus { pending, filled, cancelled }

/// Simulated trade order
class TradingOrder {
  final String id;
  final String symbol;
  final String coinName;
  final OrderSide side;
  final TradingOrderType orderType;
  final double quantity;
  final double targetPriceUSDT;
  final double? executedPriceUSDT;
  final double totalINR;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? filledAt;

  TradingOrder({
    required this.id,
    required this.symbol,
    required this.coinName,
    required this.side,
    required this.orderType,
    required this.quantity,
    required this.targetPriceUSDT,
    this.executedPriceUSDT,
    required this.totalINR,
    required this.status,
    required this.createdAt,
    this.filledAt,
  });

  bool get isBuy => side == OrderSide.buy;
  bool get isSell => side == OrderSide.sell;
  bool get isLimit => orderType == TradingOrderType.limit;
  bool get isMarket => orderType == TradingOrderType.market;
  bool get isPending => status == OrderStatus.pending;
  bool get isFilled => status == OrderStatus.filled;
  bool get isCancelled => status == OrderStatus.cancelled;

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);

  TradingOrder copyWith({
    OrderStatus? status,
    double? executedPriceUSDT,
    double? totalINR,
    DateTime? filledAt,
  }) {
    return TradingOrder(
      id: id,
      symbol: symbol,
      coinName: coinName,
      side: side,
      orderType: orderType,
      quantity: quantity,
      targetPriceUSDT: targetPriceUSDT,
      executedPriceUSDT: executedPriceUSDT ?? this.executedPriceUSDT,
      totalINR: totalINR ?? this.totalINR,
      status: status ?? this.status,
      createdAt: createdAt,
      filledAt: filledAt ?? this.filledAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'coinName': coinName,
        'side': side.name,
        'orderType': orderType.name,
        'quantity': quantity,
        'targetPriceUSDT': targetPriceUSDT,
        'executedPriceUSDT': executedPriceUSDT,
        'totalINR': totalINR,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'filledAt': filledAt?.toIso8601String(),
      };

  factory TradingOrder.fromJson(Map<String, dynamic> json) => TradingOrder(
        id: json['id'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        coinName: json['coinName'] as String? ?? '',
        side: OrderSide.values.firstWhere(
          (s) => s.name == json['side'],
          orElse: () => OrderSide.buy,
        ),
        orderType: TradingOrderType.values.firstWhere(
          (t) => t.name == json['orderType'],
          orElse: () => TradingOrderType.market,
        ),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        targetPriceUSDT: (json['targetPriceUSDT'] as num?)?.toDouble() ?? 0.0,
        executedPriceUSDT: (json['executedPriceUSDT'] as num?)?.toDouble(),
        totalINR: (json['totalINR'] as num?)?.toDouble() ?? 0.0,
        status: OrderStatus.values.firstWhere(
          (st) => st.name == json['status'],
          orElse: () => OrderStatus.filled,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        filledAt: json['filledAt'] != null ? DateTime.tryParse(json['filledAt'] as String) : null,
      );
}

/// Educational guide card definition
class TradingGuideCard {
  final String id;
  final String title;
  final String subtitle;
  final String content;
  final IconData icon;

  const TradingGuideCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.icon,
  });

  static List<TradingGuideCard> get allGuides => const [
        TradingGuideCard(
          id: 'spread',
          title: "Why the price you see isn't always the price you get",
          subtitle: 'The Bid-Ask Spread',
          icon: Icons.compare_arrows_rounded,
          content:
              "Every market has two prices simultaneously: the highest price buyers want to pay (the Bid) and the lowest price sellers will accept (the Ask). The gap between them is the spread. The price on your screen is simply the last price someone agreed on. When you tap Buy now, you don't get that past price — you buy from the lowest seller on the Ask.",
        ),
        TradingGuideCard(
          id: 'order_types',
          title: 'Market order vs Limit order — which to use when',
          subtitle: 'Speed vs Price Guarantee',
          icon: Icons.tune_rounded,
          content:
              "A Market Order prioritizes speed: it fills right now at whatever price sellers are offering. Use it when you must enter or exit immediately and small price differences don't matter. A Limit Order prioritizes price: you set your exact price (e.g. 'buy only if BTC drops to ₹70L'). Your order waits patiently and fills only if the market reaches your target. If prices never reach it, it never executes.",
        ),
        TradingGuideCard(
          id: 'slippage',
          title: 'What is slippage',
          subtitle: 'Expected Price vs Filled Price',
          icon: Icons.trending_down_rounded,
          content:
              "Slippage is the difference between the price you expected when pressing 'Buy' and the actual price you paid. In fast-moving markets or large orders, prices can move in milliseconds before your order arrives, or there aren't enough sellers at the top price to fill your whole amount. Market orders always carry slippage risk; limit orders eliminate it.",
        ),
        TradingGuideCard(
          id: 'flash_crash',
          title: 'Why prices move — a real example',
          subtitle: 'The Oct 2012 NSE Flash Crash',
          icon: Icons.electric_bolt_rounded,
          content:
              "Prices change when supply and demand fall out of balance. On October 5, 2012, an institutional broker on the National Stock Exchange (NSE) accidentally placed erroneous bulk sell orders worth ₹650 crore on 59 stocks. The sudden flood instantly vaporized available buyers, causing the Nifty index to crash ~900 points (16%) within seconds! To prevent such cascade panics, exchanges now enforce circuit breakers that temporarily halt all trading when extreme shocks occur.",
        ),
      ];
}
