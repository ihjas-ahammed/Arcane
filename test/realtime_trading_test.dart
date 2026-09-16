import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/screens/trading/trading_guide_sheet.dart';

class MockMarketService extends BinanceMarketService {
  final Map<String, CryptoPriceTick> _mockTicks = {};

  @override
  Map<String, CryptoPriceTick> get ticks => _mockTicks;

  @override
  CryptoPriceTick? getTick(String symbol) => _mockTicks[symbol.toUpperCase()];

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

      // If current price rises to $70,000:
      // Current value = 0.5 * 70,000 * 88 = ₹30,80,000
      // PnL INR = 30,80,000 - 26,40,000 = +₹4,40,000
      // PnL % = (4,40,000 / 26,40,000) * 100 = 16.67%
      expect(holding.currentValueUSDT(70000.0), 35000.0);
      expect(holding.currentValueINR(70000.0, 88.0), 3080000.0);
      expect(holding.pnlINR(70000.0, 88.0), 440000.0);
      expect(holding.pnlPercent(70000.0, 88.0), closeTo(16.666, 0.01));

      // If price drops to $50,000:
      // Current value = 0.5 * 50,000 * 88 = ₹22,00,000
      // PnL INR = 22,00,000 - 26,40,000 = -₹4,40,000
      expect(holding.pnlINR(50000.0, 88.0), -440000.0);
      expect(holding.pnlPercent(50000.0, 88.0), closeTo(-16.666, 0.01));
    });
  });

  group('PaperTradingProvider Engine Tests', () {
    late MockMarketService mockMarketService;
    late PaperTradingProvider provider;

    setUp(() {
      mockMarketService = MockMarketService();
      provider = PaperTradingProvider(marketService: mockMarketService);
    });

    test('Initializes with default starting virtual cash ₹1,00,000', () {
      expect(provider.cashBalance, 100000.0);
      expect(provider.usdtToInrRate, 88.0);
      expect(provider.holdings, isEmpty);
      expect(provider.orders, isEmpty);
      expect(provider.availableCash, 100000.0);
    });

    test('Executes Market BUY order successfully and updates position', () {
      // Buy 0.01 BTC at $60,000.
      // Total cost = 0.01 * 60,000 * 88 = ₹52,800.
      final result = provider.executeMarketOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        quantity: 0.01,
        currentPriceUSDT: 60000.0,
      );

      expect(result.success, isTrue);
      expect(provider.cashBalance, closeTo(100000.0 - 52800.0, 0.01)); // ₹47,200
      expect(provider.holdings.containsKey('BTCUSDT'), isTrue);

      final holding = provider.getHolding('BTCUSDT')!;
      expect(holding.quantity, 0.01);
      expect(holding.avgBuyPriceUSDT, 60000.0);
      expect(holding.totalCostINR, 52800.0);

      expect(provider.orders.length, 1);
      expect(provider.orders.first.isFilled, isTrue);
      expect(provider.orders.first.isBuy, isTrue);
    });

    test('Rejects Market BUY when cash balance is insufficient', () {
      // Attempt to buy 1.0 BTC at $60,000 -> requires ₹52,80,000, but user only has ₹1,00,000
      final result = provider.executeMarketOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        quantity: 1.0,
        currentPriceUSDT: 60000.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Insufficient cash'));
      expect(provider.cashBalance, 100000.0);
      expect(provider.holdings, isEmpty);
    });

    test('Executes Market SELL order partially and fully', () {
      // First buy 0.02 BTC at $50,000 (Cost = 0.02 * 50,000 * 88 = ₹88,000)
      provider.executeMarketOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        quantity: 0.02,
        currentPriceUSDT: 50000.0,
      );

      // Now sell 0.01 BTC at $60,000 (Proceeds = 0.01 * 60,000 * 88 = ₹52,800)
      final sell1 = provider.executeMarketOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.sell,
        quantity: 0.01,
        currentPriceUSDT: 60000.0,
      );

      expect(sell1.success, isTrue);
      final holding = provider.getHolding('BTCUSDT')!;
      expect(holding.quantity, 0.01);
      expect(holding.totalCostINR, 44000.0); // Half cost remains

      // Sell remaining 0.01 BTC
      final sell2 = provider.executeMarketOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.sell,
        quantity: 0.01,
        currentPriceUSDT: 60000.0,
      );

      expect(sell2.success, isTrue);
      expect(provider.getHolding('BTCUSDT'), isNull); // Holding cleared
    });

    test('Rejects Market SELL when coins are insufficient', () {
      final result = provider.executeMarketOrder(
        symbol: 'SOLUSDT',
        side: OrderSide.sell,
        quantity: 5.0,
        currentPriceUSDT: 150.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Insufficient coins'));
    });

    test('Places Limit Order as pending and auto-fills on WebSocket price cross', () {
      // Place a BUY limit order for 0.01 BTC at $55,000 (Current price is $60,000)
      final orderResult = provider.createLimitOrder(
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        quantity: 0.01,
        targetPriceUSDT: 55000.0,
      );

      expect(orderResult.success, isTrue);
      expect(provider.pendingOrders.length, 1);
      final pending = provider.pendingOrders.first;
      expect(pending.isPending, isTrue);
      expect(pending.targetPriceUSDT, 55000.0);

      // Market price tick arrives at $58,000 (does not cross 55,000 yet)
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'BTCUSDT',
        price: 58000.0,
        changePercent24h: 1.0,
        high24h: 60000.0,
        low24h: 58000.0,
        volume24h: 5000.0,
        timestamp: DateTime.now(),
      ));

      expect(provider.pendingOrders.length, 1);
      expect(provider.getHolding('BTCUSDT'), isNull);

      // Market drops to $54,500 (crosses target limit price of $55,000!)
      mockMarketService.setMockTick(CryptoPriceTick(
        symbol: 'BTCUSDT',
        price: 54500.0,
        changePercent24h: -3.0,
        high24h: 60000.0,
        low24h: 54000.0,
        volume24h: 7000.0,
        timestamp: DateTime.now(),
      ));

      // Limit order should now be auto-filled!
      expect(provider.pendingOrders, isEmpty);
      expect(provider.filledOrders.length, 1);
      expect(provider.filledOrders.first.isFilled, isTrue);
      expect(provider.getHolding('BTCUSDT'), isNotNull);
      expect(provider.getHolding('BTCUSDT')!.quantity, 0.01);
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
  });
}
