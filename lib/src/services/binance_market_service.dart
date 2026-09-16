import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:missions/src/models/trading_models.dart';

enum MarketConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

class BinanceMarketService extends ChangeNotifier {
  static const String _wsBaseUrl =
      'wss://stream.binance.com:9443/stream?streams=btcusdt@ticker/ethusdt@ticker/solusdt@ticker/bnbusdt@ticker/xrpusdt@ticker/dogeusdt@ticker';
  static const List<String> defaultSymbols = [
    'BTCUSDT',
    'ETHUSDT',
    'SOLUSDT',
    'BNBUSDT',
    'XRPUSDT',
    'DOGEUSDT',
  ];

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _indianMarketPollTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  MarketConnectionStatus _status = MarketConnectionStatus.disconnected;
  MarketConnectionStatus get status => _status;

  final Map<String, CryptoPriceTick> _ticks = {};
  Map<String, CryptoPriceTick> get ticks => Map.unmodifiable(_ticks);
  CryptoPriceTick? getTick(String symbol) => _ticks[symbol.toUpperCase()];

  /// Rolling tick history for live intraday sparklines
  final Map<String, List<double>> _priceHistory = {};
  Map<String, List<double>> get priceHistory => _priceHistory;
  List<double> getHistory(String symbol) => _priceHistory[symbol.toUpperCase()] ?? const [];

  /// Cache for real historical summaries (key: symbol_timeframe)
  final Map<String, HistoricalPriceSummary> _historicalCache = {};

  /// Comprehensive searchable assets catalog
  final List<TradingAsset> _allAssets = List.from(TradingAsset.curatedAssets);
  List<TradingAsset> get allSearchableAssets => List.unmodifiable(_allAssets);

  bool _loadedBinancePairs = false;

  BinanceMarketService() {
    for (final a in TradingAsset.curatedAssets) {
      _priceHistory[a.symbol.toUpperCase()] = [];
    }
  }

  /// Check whether Indian NSE/BSE equity market is open (09:15 to 15:30 IST, Mon-Fri)
  bool get isIndianMarketOpen {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    if (ist.weekday == DateTime.saturday || ist.weekday == DateTime.sunday) {
      return false;
    }
    final minutesSinceMidnight = ist.hour * 60 + ist.minute;
    const marketOpen = 9 * 60 + 15;   // 09:15 IST
    const marketClose = 15 * 60 + 30; // 15:30 IST
    return minutesSinceMidnight >= marketOpen && minutesSinceMidnight <= marketClose;
  }

  String get indianMarketStatusText {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    if (ist.weekday == DateTime.saturday || ist.weekday == DateTime.sunday) {
      return 'NSE CLOSED (WEEKEND)';
    }
    final minutesSinceMidnight = ist.hour * 60 + ist.minute;
    const marketOpen = 9 * 60 + 15;
    const marketClose = 15 * 60 + 30;
    if (minutesSinceMidnight < marketOpen) {
      return 'NSE OPENS 09:15 IST';
    } else if (minutesSinceMidnight > marketClose) {
      return 'NSE CLOSED';
    }
    return 'NSE LIVE (09:15-15:30 IST)';
  }

  void start() {
    if (_status == MarketConnectionStatus.connected ||
        _status == MarketConnectionStatus.connecting) {
      return;
    }
    _fetchRestSnapshot();
    _connectWebSocket();
    _fetchIndianMarkets();
    _loadAllBinanceUniverse();

    // Poll Indian markets every 15 seconds
    _indianMarketPollTimer?.cancel();
    _indianMarketPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchIndianMarkets();
    });
  }

  /// Initial snapshot for crypto pairs from Binance REST
  Future<void> _fetchRestSnapshot() async {
    try {
      final futures = defaultSymbols.map((s) async {
        final uri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$s');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final tick = CryptoPriceTick.fromBinanceRest(data);
          _updateTick(tick);
        }
      });
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Binance REST snapshot notice: $e');
    }
  }

  /// Fetches quotes for Indian stocks, indices, and commodities via Yahoo Finance
  Future<void> _fetchIndianMarkets() async {
    final nonCryptoAssets = _allAssets.where((a) => !a.isCrypto).toList();
    for (final asset in nonCryptoAssets) {
      try {
        final encodedSym = Uri.encodeComponent(asset.symbol);
        final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$encodedSym?range=1d&interval=5m';
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final results = json['chart']?['result'] as List?;
          if (results != null && results.isNotEmpty) {
            final meta = results[0]['meta'] as Map<String, dynamic>?;
            if (meta != null) {
              final tick = CryptoPriceTick.fromYahooFinance(meta);
              _updateTick(tick);

              // Update rolling history if close series available
              final quotes = results[0]['indicators']?['quote'] as List?;
              if (quotes != null && quotes.isNotEmpty) {
                final closes = quotes[0]['close'] as List?;
                if (closes != null) {
                  final validCloses = closes
                      .whereType<num>()
                      .map((n) => n.toDouble())
                      .toList();
                  if (validCloses.isNotEmpty) {
                    _priceHistory[asset.symbol.toUpperCase()] = validCloses.length > 50
                        ? validCloses.sublist(validCloses.length - 50)
                        : validCloses;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        // Silently continue for next symbol
      }
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Connects to Binance live WebSocket stream
  void _connectWebSocket() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _setStatus(_reconnectAttempts > 0
        ? MarketConnectionStatus.reconnecting
        : MarketConnectionStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsBaseUrl));

      _subscription = _channel!.stream.listen(
        (message) {
          if (_status != MarketConnectionStatus.connected) {
            _setStatus(MarketConnectionStatus.connected);
            _reconnectAttempts = 0;
          }
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('Binance WS error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Binance WS closed.');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Binance WS connect error: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final Map<String, dynamic> json = jsonDecode(raw.toString());
      final dynamic data = json['data'];
      if (data is Map<String, dynamic>) {
        final tick = CryptoPriceTick.fromBinanceWs(data);
        _updateTick(tick);
      }
    } catch (e) {
      debugPrint('Error parsing Binance tick: $e');
    }
  }

  void _updateTick(CryptoPriceTick tick) {
    if (_isDisposed) return;
    final sym = tick.symbol.toUpperCase();
    _ticks[sym] = tick;

    // Record price point in history
    final history = _priceHistory.putIfAbsent(sym, () => []);
    if (history.isEmpty || (history.last - tick.price).abs() > 0.0001) {
      history.add(tick.price);
      if (history.length > 50) {
        history.removeAt(0);
      }
    }

    notifyListeners();
  }

  /// Fetches full Binance universe (700+ USDT pairs) in background to support global crypto search
  Future<void> _loadAllBinanceUniverse() async {
    if (_loadedBinancePairs) return;
    try {
      final res = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final existingSymbols = _allAssets.map((a) => a.symbol.toUpperCase()).toSet();

        for (final item in list) {
          final sym = item['symbol']?.toString() ?? '';
          if (sym.endsWith('USDT') && !existingSymbols.contains(sym)) {
            final base = sym.replaceAll('USDT', '');
            final tick = CryptoPriceTick.fromBinanceRest(item as Map<String, dynamic>);
            _ticks[sym.toUpperCase()] = tick;

            _allAssets.add(
              TradingAsset(
                symbol: sym,
                displaySymbol: base,
                name: '$base Token',
                category: TradingAssetCategory.crypto,
                currency: 'USD',
                decimals: tick.price < 1.0 ? 4 : 2,
                exchange: 'Binance',
                is24x7: true,
                brandColor: const Color(0xFF00E5FF),
                icon: Icons.currency_bitcoin_rounded,
              ),
            );
            existingSymbols.add(sym);
          }
        }
        _loadedBinancePairs = true;
        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('Notice loading all Binance pairs: $e');
    }
  }

  /// Real Historical Price Data Engine (Binance Klines & Yahoo Finance)
  Future<HistoricalPriceSummary?> fetchHistoricalData(
    String symbol,
    String timeframe,
  ) async {
    final cacheKey = '${symbol.toUpperCase()}_$timeframe';
    if (_historicalCache.containsKey(cacheKey)) {
      return _historicalCache[cacheKey];
    }

    final isCrypto = symbol.toUpperCase().endsWith('USDT') ||
        symbol.toUpperCase().endsWith('BTC') ||
        symbol.toUpperCase().endsWith('ETH');

    HistoricalPriceSummary? summary;
    if (isCrypto) {
      summary = await _fetchCryptoKlines(symbol, timeframe);
    } else {
      summary = await _fetchYahooHistorical(symbol, timeframe);
    }

    if (summary != null) {
      _historicalCache[cacheKey] = summary;
    }
    return summary;
  }

  Future<HistoricalPriceSummary?> _fetchCryptoKlines(
    String symbol,
    String timeframe,
  ) async {
    try {
      String interval;
      int limit;

      switch (timeframe) {
        case '1D':
          interval = '15m';
          limit = 96;
          break;
        case '1W':
          interval = '1h';
          limit = 168;
          break;
        case '1M':
          interval = '4h';
          limit = 180;
          break;
        case '1Y':
          interval = '1d';
          limit = 365;
          break;
        case 'ALL':
        default:
          interval = '1w';
          limit = 260;
          break;
      }

      final url = 'https://api.binance.com/api/v3/klines?symbol=${symbol.toUpperCase()}&interval=$interval&limit=$limit';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final points = <HistoricalDataPoint>[];
        double minP = double.infinity;
        double maxP = double.negativeInfinity;

        for (final item in list) {
          final timeMs = item[0] as int;
          final openP = double.tryParse(item[1].toString()) ?? 0.0;
          final highP = double.tryParse(item[2].toString()) ?? 0.0;
          final lowP = double.tryParse(item[3].toString()) ?? 0.0;
          final closeP = double.tryParse(item[4].toString()) ?? 0.0;
          final vol = double.tryParse(item[5].toString()) ?? 0.0;

          if (closeP < minP) minP = closeP;
          if (closeP > maxP) maxP = closeP;

          points.add(HistoricalDataPoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(timeMs),
            price: closeP,
            open: openP,
            high: highP,
            low: lowP,
            volume: vol,
          ));
        }

        if (points.isEmpty) return null;

        final startPrice = points.first.price;
        final endPrice = points.last.price;
        final returnPct = startPrice > 0 ? ((endPrice - startPrice) / startPrice) * 100 : 0.0;

        return HistoricalPriceSummary(
          symbol: symbol,
          timeframe: timeframe,
          points: points,
          dayHigh: maxP,
          dayLow: minP,
          minPrice: minP,
          maxPrice: maxP,
          periodReturnPercent: returnPct,
        );
      }
    } catch (e) {
      debugPrint('Error fetching crypto klines: $e');
    }
    return null;
  }

  Future<HistoricalPriceSummary?> _fetchYahooHistorical(
    String symbol,
    String timeframe,
  ) async {
    try {
      String range;
      String interval;

      switch (timeframe) {
        case '1D':
          range = '1d';
          interval = '5m';
          break;
        case '1W':
          range = '5d';
          interval = '15m';
          break;
        case '1M':
          range = '1mo';
          interval = '1d';
          break;
        case '1Y':
          range = '1y';
          interval = '1wk';
          break;
        case 'ALL':
        default:
          range = '5y';
          interval = '1mo';
          break;
      }

      final encoded = Uri.encodeComponent(symbol);
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$encoded?range=$range&interval=$interval';
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final chart = json['chart']?['result']?[0];
        if (chart == null) return null;

        final meta = chart['meta'] as Map<String, dynamic>?;
        final timestamps = (chart['timestamp'] as List?)?.cast<int>() ?? [];
        final quotes = chart['indicators']?['quote']?[0] as Map<String, dynamic>?;
        final closes = quotes?['close'] as List?;
        final opens = quotes?['open'] as List?;
        final highs = quotes?['high'] as List?;
        final lows = quotes?['low'] as List?;
        final volumes = quotes?['volume'] as List?;

        if (closes == null || timestamps.isEmpty) return null;

        final points = <HistoricalDataPoint>[];
        double minP = double.infinity;
        double maxP = double.negativeInfinity;

        final count = timestamps.length.clamp(0, closes.length);
        for (int i = 0; i < count; i++) {
          final closeVal = closes[i];
          if (closeVal == null) continue;
          final p = (closeVal as num).toDouble();
          if (p <= 0) continue;

          if (p < minP) minP = p;
          if (p > maxP) maxP = p;

          points.add(
            HistoricalDataPoint(
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
              price: p,
              open: (opens?[i] as num?)?.toDouble(),
              high: (highs?[i] as num?)?.toDouble(),
              low: (lows?[i] as num?)?.toDouble(),
              volume: (volumes?[i] as num?)?.toDouble(),
            ),
          );
        }

        if (points.isEmpty) return null;

        final startPrice = points.first.price;
        final endPrice = points.last.price;
        final returnPct = startPrice > 0 ? ((endPrice - startPrice) / startPrice) * 100 : 0.0;

        return HistoricalPriceSummary(
          symbol: symbol,
          timeframe: timeframe,
          points: points,
          fiftyTwoWeekHigh: (meta?['fiftyTwoWeekHigh'] as num?)?.toDouble(),
          fiftyTwoWeekLow: (meta?['fiftyTwoWeekLow'] as num?)?.toDouble(),
          dayHigh: (meta?['regularMarketDayHigh'] as num?)?.toDouble() ?? maxP,
          dayLow: (meta?['regularMarketDayLow'] as num?)?.toDouble() ?? minP,
          previousClose: (meta?['chartPreviousClose'] as num?)?.toDouble(),
          periodReturnPercent: returnPct,
          minPrice: minP,
          maxPrice: maxP,
        );
      }
    } catch (e) {
      debugPrint('Error fetching Yahoo Finance chart: $e');
    }
    return null;
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _cleanSubscription();
    _setStatus(MarketConnectionStatus.reconnecting);

    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 10);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        _connectWebSocket();
      }
    });
  }

  void _cleanSubscription() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _setStatus(MarketConnectionStatus newStatus) {
    if (_status != newStatus && !_isDisposed) {
      _status = newStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _indianMarketPollTimer?.cancel();
    _cleanSubscription();
    super.dispose();
  }
}
