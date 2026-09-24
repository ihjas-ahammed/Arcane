import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Trading Database Synchronization Tests', () {
    test('PaperTradingProvider serializes state to map correctly', () {
      final provider = PaperTradingProvider.instance;
      provider.resetPortfolio();

      final state = provider.getStateMap();
      expect(state['cashBalance'], 100000.0);
      expect(state['usdtToInrRate'], 88.0);
      expect(state['holdings'], isEmpty);
      expect(state['orders'], isEmpty);
      expect(state['lossAlertsTriggered'], isEmpty);
      expect(state['lastModified'], isA<int>());
    });

    test('PaperTradingProvider loads state from map correctly', () {
      final provider = PaperTradingProvider.instance;

      final testData = {
        'cashBalance': 75432.50,
        'usdtToInrRate': 89.2,
        'holdings': [
          {
            'symbol': 'BTCUSDT',
            'coinName': 'Bitcoin',
            'quantity': 0.15,
            'avgBuyPriceUSDT': 62000.0,
            'totalCostINR': 829560.0,
            'currency': 'USD',
            'peakPrice': 65000.0,
            'hasReachedHigher': true,
          }
        ],
        'orders': [
          {
            'id': 'test-ord-1',
            'symbol': 'BTCUSDT',
            'side': 'buy',
            'type': 'market',
            'quantity': 0.15,
            'priceUSDT': 62000.0,
            'totalINR': 829560.0,
            'status': 'filled',
            'timestamp': DateTime.now().toIso8601String(),
            'currency': 'USD',
          }
        ],
        'lossAlertsTriggered': ['BTCUSDT'],
        'lastModified': DateTime.now().millisecondsSinceEpoch,
      };

      provider.loadState(testData, force: true);

      expect(provider.cashBalance, 75432.50);
      expect(provider.usdtToInrRate, 89.2);
      expect(provider.holdings.containsKey('BTCUSDT'), isTrue);
      expect(provider.holdings['BTCUSDT']!.quantity, 0.15);
      expect(provider.holdings['BTCUSDT']!.peakPrice, 65000.0);
      expect(provider.orders.length, 1);
      expect(provider.orders.first.id, 'test-ord-1');
      expect(provider.lossAlertsTriggered, contains('BTCUSDT'));
    });

    test('State changes trigger onStateChanged callback', () async {
      final provider = PaperTradingProvider.instance;
      await provider.resetPortfolio();

      int callCount = 0;
      provider.onStateChanged = () {
        callCount++;
      };

      await provider.setCashBalance(105000.0);
      expect(callCount, 1);
      expect(provider.cashBalance, 105000.0);

      await provider.setUsdtToInrRate(91.5);
      expect(callCount, 2);
      expect(provider.usdtToInrRate, 91.5);

      await provider.resetPortfolio();
      expect(callCount, 3);
    });

    test('AppProvider includes trading data in getFullAppState and restores it in loadStateFromMap', () async {
      final appProvider = AppProvider.forTest();
      final tradingProvider = PaperTradingProvider.instance;
      await tradingProvider.resetPortfolio();

      // Verify trading provider is wired into appProvider
      expect(appProvider.getTradingStateMap(), isNotNull);

      // Mutate trading state
      await tradingProvider.setCashBalance(112345.0);

      final fullState = appProvider.getFullAppState();
      expect(fullState.containsKey('trading'), isTrue);
      final tradingState = fullState['trading'] as Map<String, dynamic>;
      expect(tradingState['cashBalance'], 112345.0);

      // Now test restoring via loadStateFromMap
      final remoteData = {
        'trading': {
          'cashBalance': 55555.0,
          'usdtToInrRate': 90.0,
          'holdings': [],
          'orders': [],
          'lossAlertsTriggered': [],
          'lastModified': DateTime.now().millisecondsSinceEpoch + 10000,
        }
      };

      appProvider.loadStateFromMap(remoteData);
      expect(tradingProvider.cashBalance, 55555.0);
      expect(tradingProvider.usdtToInrRate, 90.0);
    });

    test('StorageService defines trading document methods', () {
      final storage = StorageService();
      expect(storage.saveTrading, isNotNull);
      expect(storage.getTrading, isNotNull);
    });
  });
}
