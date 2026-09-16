import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const String _wsUrl =
      'wss://stream.binance.com:9443/stream?streams=btcusdt@ticker/ethusdt@ticker/solusdt@ticker';
  static const List<String> defaultSymbols = ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'];

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  MarketConnectionStatus _status = MarketConnectionStatus.disconnected;
  MarketConnectionStatus get status => _status;

  final Map<String, CryptoPriceTick> _ticks = {};
  Map<String, CryptoPriceTick> get ticks => Map.unmodifiable(_ticks);

  /// Rolling price history for line charts (up to 50 samples per symbol)
  final Map<String, List<double>> _priceHistory = {};
  Map<String, List<double>> get priceHistory => _priceHistory;

  BinanceMarketService() {
    for (final s in defaultSymbols) {
      _priceHistory[s] = [];
    }
  }

  void start() {
    if (_status == MarketConnectionStatus.connected ||
        _status == MarketConnectionStatus.connecting) {
      return;
    }
    _fetchRestSnapshot();
    _connectWebSocket();
  }

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

  void _connectWebSocket() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _setStatus(_reconnectAttempts > 0
        ? MarketConnectionStatus.reconnecting
        : MarketConnectionStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

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

  CryptoPriceTick? getTick(String symbol) => _ticks[symbol.toUpperCase()];

  List<double> getHistory(String symbol) =>
      List.unmodifiable(_priceHistory[symbol.toUpperCase()] ?? []);

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanSubscription();
    super.dispose();
  }
}
