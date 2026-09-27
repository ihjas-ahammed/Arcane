import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/models/trading_psychology_models.dart';
import 'package:missions/src/services/binance_market_service.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/utils/trading_risk_math.dart';

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

CryptoPriceTick _tick(String symbol, double price, {String currency = 'INR'}) {
  return CryptoPriceTick(
    symbol: symbol,
    price: price,
    changePercent24h: 0.0,
    high24h: price,
    low24h: price,
    volume24h: 1000,
    timestamp: DateTime.now(),
    currency: currency,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('A/B. Risk math (pure functions)', () {
    test('riskBudgetINR', () {
      expect(riskBudgetINR(100000, 1.0), 1000.0);
    });

    test('positionSizeForRisk — whole units (Indian equity)', () {
      final qty = positionSizeForRisk(
        entryPrice: 100,
        stopPrice: 95,
        riskBudgetINR: 1000,
        inrPerUnit: 1.0,
        decimals: 0,
        wholeUnits: true,
      );
      expect(qty, 200.0);
    });

    test('positionSizeForRisk — fractional units (crypto)', () {
      final qty = positionSizeForRisk(
        entryPrice: 100,
        stopPrice: 95,
        riskBudgetINR: 1000,
        inrPerUnit: 88.0,
        decimals: 4,
        wholeUnits: false,
      );
      expect(qty, closeTo(2.2727, 0.0001));
    });

    test('positionSizeForRisk returns 0 when stop >= entry', () {
      expect(
        positionSizeForRisk(
          entryPrice: 100,
          stopPrice: 100,
          riskBudgetINR: 1000,
          inrPerUnit: 1.0,
          decimals: 2,
          wholeUnits: false,
        ),
        0.0,
      );
      expect(
        positionSizeForRisk(
          entryPrice: 100,
          stopPrice: 105,
          riskBudgetINR: 1000,
          inrPerUnit: 1.0,
          decimals: 2,
          wholeUnits: false,
        ),
        0.0,
      );
    });

    test('recoveryGainNeededPercent', () {
      expect(recoveryGainNeededPercent(10), closeTo(11.11, 0.01));
      expect(recoveryGainNeededPercent(20), closeTo(25.0, 0.001));
      expect(recoveryGainNeededPercent(50), closeTo(100.0, 0.001));
    });

    test('suggestedRiskPercent drawdown ladder', () {
      expect(suggestedRiskPercent(1.0, 0), 1.0);
      expect(suggestedRiskPercent(1.0, 2.9), 1.0);
      expect(suggestedRiskPercent(1.0, 3), 0.75);
      expect(suggestedRiskPercent(1.0, 6), 0.5);
      expect(suggestedRiskPercent(1.0, 10.1), 0.25);
    });
  });

  group('C/D. Buy plan, guards, protective stops, journal, stats', () {
    late MockMarketService mock;
    late PaperTradingProvider provider;

    setUp(() {
      mock = MockMarketService();
      provider = PaperTradingProvider(marketService: mock);
    });

    test('Buy with plan sets holding stop/plannedRisk/openedAt; order carries plan; JSON round trips; old JSON loads with null stop', () {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));

      final plan = TradePlan(
        stopPrice: 2700.0,
        plannedRiskINR: 2000.0,
        riskPercentOfPortfolio: 0.7,
        edge: 'Bounce off support',
        checklistScore: 4,
        checklistTotal: 5,
      );

      final result = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10,
        currentPriceUSDT: 2900.0,
        plan: plan,
        stopPrice: 2700.0,
      );

      expect(result.success, isTrue);
      final holding = provider.getHolding('RELIANCE.NS')!;
      expect(holding.stopPrice, 2700.0);
      expect(holding.initialStopPrice, 2700.0);
      expect(holding.plannedRiskINR, 2000.0);
      expect(holding.openedAt, isNotNull);
      expect(holding.plan, isNotNull);

      expect(result.order!.plan, isNotNull);
      expect(result.order!.plan!.edge, 'Bounce off support');

      // JSON round trip preserves the new fields.
      final json = holding.toJson();
      final restored = CryptoHolding.fromJson(json);
      expect(restored.stopPrice, 2700.0);
      expect(restored.plannedRiskINR, 2000.0);
      expect(restored.plan?.edge, 'Bounce off support');

      // Old JSON without any of the new keys must still load, with stop null.
      final oldJson = {
        'symbol': 'TCS.NS',
        'coinName': 'Tata Consultancy Services',
        'quantity': 5.0,
        'avgBuyPriceUSDT': 3500.0,
        'totalCostINR': 17500.0,
        'currency': 'INR',
      };
      final legacy = CryptoHolding.fromJson(oldJson);
      expect(legacy.stopPrice, isNull);
      expect(legacy.initialStopPrice, isNull);
      expect(legacy.plannedRiskINR, isNull);
      expect(legacy.openedAt, isNull);
      expect(legacy.plan, isNull);
    });

    test('Strict risk guard refuses a buy above max risk %; disabling the guard allows it', () {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));

      final riskyPlan = TradePlan(riskPercentOfPortfolio: 5.0);

      final refused = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
        plan: riskyPlan,
      );
      expect(refused.success, isFalse);
      expect(refused.message, contains('RISK RULE'));

      provider.updateRiskSettings(provider.riskSettings.copyWith(strictRiskGuard: false));

      final allowed = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
        plan: riskyPlan,
      );
      expect(allowed.success, isTrue);
    });

    test('Daily trade cap refuses the (cap+1)th buy; cap 0 disables the guard', () async {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      await provider.updateRiskSettings(provider.riskSettings.copyWith(dailyTradeCap: 2));

      final r1 = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
      );
      final r2 = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
      );
      expect(r1.success, isTrue);
      expect(r2.success, isTrue);
      expect(provider.tradesToday, 2);

      final r3 = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
      );
      expect(r3.success, isFalse);
      expect(r3.message, contains('MACHINE-GUN GUARD'));

      await provider.updateRiskSettings(provider.riskSettings.copyWith(dailyTradeCap: 0));
      final r4 = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
      );
      expect(r4.success, isTrue);
    });

    test('setProtectiveStop: refuses stop >= current price, refuses lowering, allows raising; raiseStopToBreakeven', () {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10,
        currentPriceUSDT: 2900.0,
        stopPrice: 2700.0,
      );

      final tooHigh = provider.setProtectiveStop('RELIANCE.NS', 2950.0);
      expect(tooHigh.success, isFalse);
      expect(tooHigh.message, contains('below the current price'));

      final lowered = provider.setProtectiveStop('RELIANCE.NS', 2600.0);
      expect(lowered.success, isFalse);
      expect(lowered.message, contains('NEVER WIDEN'));

      final raised = provider.setProtectiveStop('RELIANCE.NS', 2800.0);
      expect(raised.success, isTrue);
      expect(provider.getHolding('RELIANCE.NS')!.stopPrice, 2800.0);

      // Price rises above avg entry (2900) -> breakeven raises stop to 2900.
      mock.setMockTick(_tick('RELIANCE.NS', 3100.0));
      final be = provider.raiseStopToBreakeven('RELIANCE.NS');
      expect(be.success, isTrue);
      expect(provider.getHolding('RELIANCE.NS')!.stopPrice, 2900.0);
    });

    test('Stop hit sells the holding, credits cash, records a stopHit journal entry with a loss R-multiple', () {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10,
        currentPriceUSDT: 2900.0,
        plan: TradePlan(plannedRiskINR: 2000.0),
        stopPrice: 2700.0,
      );

      final cashAfterBuy = provider.cashBalance;

      // Price falls through the stop.
      mock.setMockTick(_tick('RELIANCE.NS', 2650.0));
      provider.checkProtectiveStops(mock.ticks);

      expect(provider.getHolding('RELIANCE.NS'), isNull);
      expect(provider.cashBalance, closeTo(cashAfterBuy + 10 * 2650.0, 0.01));

      final stopOrder = provider.orders.firstWhere((o) => o.orderType == TradingOrderType.stop);
      expect(stopOrder.note, contains('PROTECTIVE STOP HIT'));
      expect(stopOrder.side, OrderSide.sell);

      final record = provider.tradeRecords.first;
      expect(record.exitReason, TradeExitReason.stopHit);
      expect(record.rMultiple, isNotNull);
      expect(record.rMultiple, lessThan(0));
      // Realized loss = 10 * (2650-2900) = -2500; planned risk 2000 -> R = -1.25
      expect(record.rMultiple, closeTo(-1.25, 0.01));
    });

    test('Partial manual sell records the sold fraction; later full close records a second entry', () {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10,
        currentPriceUSDT: 2900.0,
        plan: TradePlan(plannedRiskINR: 2000.0),
      );

      final partial = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.sell,
        quantity: 4,
        currentPriceUSDT: 3000.0,
      );
      expect(partial.success, isTrue);
      expect(provider.tradeRecords.length, 1);
      final firstRecord = provider.tradeRecords.first;
      expect(firstRecord.quantity, 4);
      expect(firstRecord.costINR, closeTo(2900.0 * 10 * 0.4, 0.01));
      expect(firstRecord.plannedRiskINR, closeTo(2000.0 * 0.4, 0.01));

      final remaining = provider.getHolding('RELIANCE.NS')!;
      expect(remaining.quantity, 6);
      expect(remaining.plannedRiskINR, closeTo(2000.0 * 0.6, 0.01));

      final full = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.sell,
        quantity: 6,
        currentPriceUSDT: 3050.0,
      );
      expect(full.success, isTrue);
      expect(provider.tradeRecords.length, 2);
      expect(provider.getHolding('RELIANCE.NS'), isNull);
    });

    test('SmartMoneyStats: 9 losses of ₹1000 + 1 win of ₹20000', () {
      final now = DateTime.now();
      final records = <TradeRecord>[
        for (int i = 0; i < 9; i++)
          TradeRecord(
            id: 'loss-$i',
            symbol: 'RELIANCE.NS',
            coinName: 'Reliance',
            currency: 'INR',
            quantity: 1,
            entryAvgPrice: 100,
            exitAvgPrice: 90,
            costINR: 1000,
            proceedsINR: 0,
            openedAt: now.subtract(Duration(days: 20 - i)),
            closedAt: now.subtract(Duration(days: 19 - i)),
            exitReason: TradeExitReason.manual,
          ),
        TradeRecord(
          id: 'win-1',
          symbol: 'RELIANCE.NS',
          coinName: 'Reliance',
          currency: 'INR',
          quantity: 1,
          entryAvgPrice: 100,
          exitAvgPrice: 300,
          costINR: 10000,
          proceedsINR: 30000,
          openedAt: now.subtract(const Duration(days: 2)),
          closedAt: now, // most recent -> streak should be +1
          exitReason: TradeExitReason.manual,
        ),
      ];
      // costINR/proceedsINR above give realizedPnlINR = -1000 * 9 and +20000 * 1
      final stats = SmartMoneyStats.compute(
        records: records,
        snapshots: const [],
        currentEquityINR: 100000,
        startingEquityINR: 100000,
      );

      expect(stats.closedTrades, 10);
      expect(stats.wins, 1);
      expect(stats.losses, 9);
      expect(stats.winRate, closeTo(10.0, 0.001));
      expect(stats.avgWinINR, closeTo(20000.0, 0.001));
      expect(stats.avgLossINR, closeTo(1000.0, 0.001));
      expect(stats.winLossRatio, closeTo(20.0, 0.001));
      expect(stats.expectancyINR, closeTo(1100.0, 0.001));
      expect(stats.profitFactor, closeTo(2.2222, 0.001));
      expect(stats.largestLossINR, closeTo(1000.0, 0.001));
      // The win is the most recently closed trade -> current streak is +1.
      expect(stats.currentStreak, 1);
    });

    test('recordEquitySnapshot: two same-day calls keep a single entry', () {
      mock.setMockTick(_tick('RELIANCE.NS', 100.0));
      provider.recordEquitySnapshot(mock.ticks);
      final firstCount = provider.equitySnapshots.length;
      provider.recordEquitySnapshot(mock.ticks);
      expect(provider.equitySnapshots.length, firstCount);

      // A later same-day call still replaces, rather than appending, the entry.
      mock.setMockTick(_tick('RELIANCE.NS', 150.0));
      provider.recordEquitySnapshot(mock.ticks);
      expect(provider.equitySnapshots.length, 1);
      expect(provider.equitySnapshots.first.valueINR, closeTo(100000.0, 0.01));
      expect(provider.equityPeakINR, greaterThanOrEqualTo(100000.0));
    });

    test('SmartMoneyStats.compute derives current & max drawdown from the equity peak', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final stats = SmartMoneyStats.compute(
        records: const [],
        snapshots: [EquitySnapshot(at: yesterday, valueINR: 120000.0)],
        currentEquityINR: 102000.0,
        startingEquityINR: 100000.0,
      );
      expect(stats.equityPeakINR, 120000.0);
      // (120000 - 102000) / 120000 * 100 = 15%
      expect(stats.currentDrawdownPercent, closeTo(15.0, 0.01));
      expect(stats.maxDrawdownPercent, greaterThanOrEqualTo(stats.currentDrawdownPercent));
    });

    test('reviewTrade persists grade/lesson and survives getStateMap -> loadState', () async {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 10,
        currentPriceUSDT: 2900.0,
      );
      provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.sell,
        quantity: 10,
        currentPriceUSDT: 3000.0,
      );

      final recordId = provider.tradeRecords.first.id;
      await provider.reviewTrade(
        recordId,
        followedPlan: true,
        processGrade: 'A',
        lesson: 'Followed the plan exactly.',
      );

      final reviewed = provider.tradeRecords.firstWhere((r) => r.id == recordId);
      expect(reviewed.processGrade, 'A');
      expect(reviewed.lesson, 'Followed the plan exactly.');
      expect(reviewed.followedPlan, isTrue);

      final state = provider.getStateMap();
      provider.loadState(state, force: true);

      final restored = provider.tradeRecords.firstWhere((r) => r.id == recordId);
      expect(restored.processGrade, 'A');
      expect(restored.lesson, 'Followed the plan exactly.');
      expect(restored.followedPlan, isTrue);
    });

    test('requireChecklist guard refuses a buy with an under-filled gate', () async {
      mock.setMockTick(_tick('RELIANCE.NS', 2900.0));
      await provider.updateRiskSettings(provider.riskSettings.copyWith(requireChecklist: true));

      final weakPlan = TradePlan(checklistScore: 1, checklistTotal: 5);
      final refused = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
        plan: weakPlan,
      );
      expect(refused.success, isFalse);
      expect(refused.message, contains('GATE'));

      final strongPlan = TradePlan(checklistScore: 4, checklistTotal: 5);
      final allowed = provider.executeMarketOrder(
        symbol: 'RELIANCE.NS',
        side: OrderSide.buy,
        quantity: 1,
        currentPriceUSDT: 2900.0,
        plan: strongPlan,
      );
      expect(allowed.success, isTrue);
    });
  });

  group('TraderMood', () {
    test('label / isDumbMoneyState / isCaution / coaching', () {
      expect(TraderMood.fomo.label, 'FOMO');
      expect(TraderMood.fomo.isDumbMoneyState, isTrue);
      expect(TraderMood.calm.isDumbMoneyState, isFalse);
      expect(TraderMood.fearful.isDumbMoneyState, isFalse);
      expect(TraderMood.fearful.isCaution, isTrue);
      expect(TraderMood.fomo.coaching, contains('The market will wait'));
    });
  });

  group('SmartMoneyGuides', () {
    test('exposes 8 cards with the exact spec ids', () {
      final ids = SmartMoneyGuides.cards.map((c) => c.id).toList();
      expect(ids, [
        'respect_risk',
        'three_exits',
        'never_widen',
        'win_rate_myth',
        'equity_curve',
        'gate',
        'biases',
        'personalities',
      ]);
    });
  });
}
