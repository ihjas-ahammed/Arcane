import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Asset category for filtering
enum TradingAssetCategory {
  all('ALL', 'All Markets'),
  indianEquity('NSE STOCKS', 'Indian Equities (NSE)'),
  indianIndex('INDICES', 'Indian & Global Indices'),
  crypto('CRYPTO', 'Cryptocurrencies (Binance)'),
  commodity('COMMODITIES', 'Commodities & Macro');

  final String label;
  final String description;

  const TradingAssetCategory(this.label, this.description);
}

/// Unified Tradable Asset Model
class TradingAsset {
  final String symbol;          // e.g. 'RELIANCE.NS', 'BTCUSDT', '^NSEI'
  final String displaySymbol;   // e.g. 'RELIANCE', 'BTC', 'NIFTY 50'
  final String name;            // e.g. 'Reliance Industries Ltd.', 'Bitcoin'
  final TradingAssetCategory category;
  final String currency;        // 'INR' or 'USD'
  final int decimals;
  final String exchange;        // 'NSE', 'BSE', 'Binance', 'MCX'
  final bool is24x7;
  final Color brandColor;
  final IconData icon;

  const TradingAsset({
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.category,
    required this.currency,
    required this.decimals,
    required this.exchange,
    required this.is24x7,
    required this.brandColor,
    required this.icon,
  });

  bool get isCrypto => category == TradingAssetCategory.crypto;
  bool get isIndianEquity => category == TradingAssetCategory.indianEquity;
  bool get isIndex => category == TradingAssetCategory.indianIndex;
  bool get isCommodity => category == TradingAssetCategory.commodity;
  bool get isIndianMarket => isIndianEquity || isIndex;
  bool get isIndianAsset => currency == 'INR' || isIndianMarket;
  String get baseAsset => displaySymbol;
  String get pairLabel => '$displaySymbol/$currency';
  bool get isTradable => !isIndex;

  factory TradingAsset.fromCryptoSymbol(CryptoSymbol c) => TradingAsset(
    symbol: c.rawSymbol,
    displaySymbol: c.baseAsset,
    name: c.name,
    category: TradingAssetCategory.crypto,
    currency: 'USD',
    decimals: c.decimals,
    exchange: 'Binance',
    is24x7: true,
    brandColor: c.brandColor,
    icon: c.icon,
  );

  String get currencySymbol => currency == 'INR' ? '₹' : '\$';

  /// Preloaded Curated Universe for Indian & Global Investors
  static final List<TradingAsset> curatedAssets = [
    // --- 🪙 Top Cryptos (Binance Live Stream) ---
    const TradingAsset(
      symbol: 'BTCUSDT',
      displaySymbol: 'BTC',
      name: 'Bitcoin',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 4,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFFF7931A),
      icon: Icons.currency_bitcoin_rounded,
    ),
    const TradingAsset(
      symbol: 'ETHUSDT',
      displaySymbol: 'ETH',
      name: 'Ethereum',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 4,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFF627EEA),
      icon: MdiIcons.rhombusOutline,
    ),
    const TradingAsset(
      symbol: 'SOLUSDT',
      displaySymbol: 'SOL',
      name: 'Solana',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 3,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFF14F195),
      icon: Icons.bolt_rounded,
    ),
    const TradingAsset(
      symbol: 'BNBUSDT',
      displaySymbol: 'BNB',
      name: 'Binance Coin',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 3,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFFF3BA2F),
      icon: Icons.toll_rounded,
    ),
    const TradingAsset(
      symbol: 'XRPUSDT',
      displaySymbol: 'XRP',
      name: 'Ripple XRP',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 4,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFF23292F),
      icon: Icons.swap_horiz_rounded,
    ),
    const TradingAsset(
      symbol: 'DOGEUSDT',
      displaySymbol: 'DOGE',
      name: 'Dogecoin',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 1,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFFC2A633),
      icon: Icons.pets_rounded,
    ),
    const TradingAsset(
      symbol: 'ADAUSDT',
      displaySymbol: 'ADA',
      name: 'Cardano',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 2,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFF0033AD),
      icon: Icons.all_inclusive_rounded,
    ),
    const TradingAsset(
      symbol: 'AVAXUSDT',
      displaySymbol: 'AVAX',
      name: 'Avalanche',
      category: TradingAssetCategory.crypto,
      currency: 'USD',
      decimals: 3,
      exchange: 'Binance',
      is24x7: true,
      brandColor: Color(0xFFE84142),
      icon: Icons.terrain_rounded,
    ),

    // --- 🇮🇳 Top Indian Bluechips (NSE) ---
    const TradingAsset(
      symbol: 'RELIANCE.NS',
      displaySymbol: 'RELIANCE',
      name: 'Reliance Industries',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF005EB8),
      icon: Icons.oil_barrel_outlined,
    ),
    const TradingAsset(
      symbol: 'TCS.NS',
      displaySymbol: 'TCS',
      name: 'Tata Consultancy Services',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF1B4D3E),
      icon: Icons.computer_rounded,
    ),
    const TradingAsset(
      symbol: 'HDFCBANK.NS',
      displaySymbol: 'HDFCBANK',
      name: 'HDFC Bank Ltd.',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF004C8F),
      icon: Icons.account_balance_rounded,
    ),
    const TradingAsset(
      symbol: 'INFY.NS',
      displaySymbol: 'INFY',
      name: 'Infosys Limited',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF007CC3),
      icon: Icons.code_rounded,
    ),
    const TradingAsset(
      symbol: 'ICICIBANK.NS',
      displaySymbol: 'ICICIBANK',
      name: 'ICICI Bank Ltd.',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFB3261E),
      icon: Icons.account_balance_outlined,
    ),
    const TradingAsset(
      symbol: 'SBIN.NS',
      displaySymbol: 'SBIN',
      name: 'State Bank of India',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF280071),
      icon: Icons.domain_rounded,
    ),
    const TradingAsset(
      symbol: 'BHARTIARTL.NS',
      displaySymbol: 'BHARTIARTL',
      name: 'Bharti Airtel',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFED1C24),
      icon: Icons.cell_tower_rounded,
    ),
    const TradingAsset(
      symbol: 'ITC.NS',
      displaySymbol: 'ITC',
      name: 'ITC Limited',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFD4AF37),
      icon: Icons.shopping_basket_rounded,
    ),
    const TradingAsset(
      symbol: 'LT.NS',
      displaySymbol: 'LT',
      name: 'Larsen & Toubro',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFFF9900),
      icon: Icons.precision_manufacturing_rounded,
    ),
    const TradingAsset(
      symbol: 'BAJFINANCE.NS',
      displaySymbol: 'BAJFINANCE',
      name: 'Bajaj Finance',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF003876),
      icon: Icons.credit_card_rounded,
    ),
    const TradingAsset(
      symbol: 'MARUTI.NS',
      displaySymbol: 'MARUTI',
      name: 'Maruti Suzuki India',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFE31B23),
      icon: Icons.directions_car_rounded,
    ),
    const TradingAsset(
      symbol: 'SUNPHARMA.NS',
      displaySymbol: 'SUNPHARMA',
      name: 'Sun Pharma',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFF26522),
      icon: Icons.medical_services_rounded,
    ),
    const TradingAsset(
      symbol: 'TITAN.NS',
      displaySymbol: 'TITAN',
      name: 'Titan Company',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF800020),
      icon: Icons.watch_rounded,
    ),
    const TradingAsset(
      symbol: 'WIPRO.NS',
      displaySymbol: 'WIPRO',
      name: 'Wipro Limited',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF4A90E2),
      icon: Icons.dns_rounded,
    ),
    const TradingAsset(
      symbol: 'KOTAKBANK.NS',
      displaySymbol: 'KOTAKBANK',
      name: 'Kotak Mahindra Bank',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFFED1C24),
      icon: Icons.account_balance_wallet_rounded,
    ),
    const TradingAsset(
      symbol: 'AXISBANK.NS',
      displaySymbol: 'AXISBANK',
      name: 'Axis Bank Ltd.',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF97144D),
      icon: Icons.payment_rounded,
    ),
    const TradingAsset(
      symbol: 'JIOFIN.NS',
      displaySymbol: 'JIOFIN',
      name: 'Jio Financial Services',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF0F52BA),
      icon: Icons.stream_rounded,
    ),
    const TradingAsset(
      symbol: 'TATAPOWER.NS',
      displaySymbol: 'TATAPOWER',
      name: 'Tata Power Company',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF00A3E0),
      icon: Icons.electric_bolt_rounded,
    ),
    const TradingAsset(
      symbol: 'ADANIENT.NS',
      displaySymbol: 'ADANIENT',
      name: 'Adani Enterprises',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF0C2340),
      icon: Icons.corporate_fare_rounded,
    ),
    const TradingAsset(
      symbol: 'HINDUNILVR.NS',
      displaySymbol: 'HINDUNILVR',
      name: 'Hindustan Unilever',
      category: TradingAssetCategory.indianEquity,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF001F60),
      icon: Icons.clean_hands_rounded,
    ),

    // --- 📈 Benchmark Indices ---
    const TradingAsset(
      symbol: '^NSEI',
      displaySymbol: 'NIFTY 50',
      name: 'NIFTY 50 Benchmark Index',
      category: TradingAssetCategory.indianIndex,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF00BFA5),
      icon: Icons.stacked_line_chart_rounded,
    ),
    const TradingAsset(
      symbol: '^BSESN',
      displaySymbol: 'SENSEX',
      name: 'BSE SENSEX 30 Index',
      category: TradingAssetCategory.indianIndex,
      currency: 'INR',
      decimals: 2,
      exchange: 'BSE',
      is24x7: false,
      brandColor: Color(0xFF6200EA),
      icon: Icons.show_chart_rounded,
    ),
    const TradingAsset(
      symbol: '^NSEBANK',
      displaySymbol: 'BANK NIFTY',
      name: 'NIFTY Bank Sectoral Index',
      category: TradingAssetCategory.indianIndex,
      currency: 'INR',
      decimals: 2,
      exchange: 'NSE',
      is24x7: false,
      brandColor: Color(0xFF2979FF),
      icon: Icons.account_balance_rounded,
    ),

    // --- 🟡 Commodities & Macro ---
    const TradingAsset(
      symbol: 'GC=F',
      displaySymbol: 'GOLD',
      name: 'Gold (Spot/MCX)',
      category: TradingAssetCategory.commodity,
      currency: 'USD',
      decimals: 2,
      exchange: 'MCX/Comex',
      is24x7: false,
      brandColor: Color(0xFFFFD700),
      icon: Icons.diamond_outlined,
    ),
    const TradingAsset(
      symbol: 'SI=F',
      displaySymbol: 'SILVER',
      name: 'Silver (Spot/MCX)',
      category: TradingAssetCategory.commodity,
      currency: 'USD',
      decimals: 2,
      exchange: 'MCX/Comex',
      is24x7: false,
      brandColor: Color(0xFFC0C0C0),
      icon: Icons.lens_blur_rounded,
    ),
    const TradingAsset(
      symbol: 'CL=F',
      displaySymbol: 'CRUDE OIL',
      name: 'Crude Oil WTI',
      category: TradingAssetCategory.commodity,
      currency: 'USD',
      decimals: 2,
      exchange: 'NYMEX',
      is24x7: false,
      brandColor: Color(0xFF37474F),
      icon: Icons.water_drop_rounded,
    ),
    const TradingAsset(
      symbol: 'USDINR=X',
      displaySymbol: 'USD/INR',
      name: 'USD to Indian Rupee',
      category: TradingAssetCategory.commodity,
      currency: 'INR',
      decimals: 2,
      exchange: 'Forex',
      is24x7: false,
      brandColor: Color(0xFF00897B),
      icon: Icons.currency_rupee_rounded,
    ),
  ];

  static TradingAsset fromSymbol(String sym) {
    final clean = sym.toUpperCase().replaceAll('/', '');
    for (final a in curatedAssets) {
      if (a.symbol.toUpperCase() == clean ||
          a.displaySymbol.toUpperCase() == clean ||
          a.symbol.toUpperCase().replaceAll('.NS', '') == clean) {
        return a;
      }
    }
    // Dynamic fallback for any search symbol
    final isNs = clean.endsWith('.NS') || (!clean.contains('USDT') && !clean.startsWith('^'));
    final isUsdt = clean.endsWith('USDT');
    return TradingAsset(
      symbol: isNs && !clean.endsWith('.NS') ? '$clean.NS' : clean,
      displaySymbol: clean.replaceAll('.NS', '').replaceAll('USDT', ''),
      name: clean.replaceAll('.NS', '').replaceAll('USDT', ''),
      category: isUsdt
          ? TradingAssetCategory.crypto
          : (clean.startsWith('^')
              ? TradingAssetCategory.indianIndex
              : TradingAssetCategory.indianEquity),
      currency: isUsdt ? 'USD' : 'INR',
      decimals: isUsdt ? 4 : 2,
      exchange: isUsdt ? 'Binance' : 'NSE',
      is24x7: isUsdt,
      brandColor: const Color(0xFF00E5FF),
      icon: Icons.candlestick_chart_rounded,
    );
  }
}

/// Backwards compatibility enum
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

/// Realtime or Snapshot price tick
class CryptoPriceTick {
  final String symbol;
  final double price;
  final double changePercent24h;
  final double high24h;
  final double low24h;
  final double volume24h;
  final DateTime timestamp;
  final String currency; // 'INR' or 'USD'
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final double? previousClose;

  CryptoPriceTick({
    required this.symbol,
    required this.price,
    required this.changePercent24h,
    required this.high24h,
    required this.low24h,
    required this.volume24h,
    required this.timestamp,
    this.currency = 'USD',
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.previousClose,
  });

  bool get isPositive => changePercent24h >= 0;

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);

  TradingAsset get assetInfo => TradingAsset.fromSymbol(symbol);

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
      currency: 'USD',
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
      currency: 'USD',
    );
  }

  factory CryptoPriceTick.fromYahooFinance(Map<String, dynamic> meta) {
    final symbol = meta['symbol']?.toString() ?? '';
    final price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
    final changePercent = (meta['regularMarketChangePercent'] as num?)?.toDouble() ?? 0.0;
    final high = (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? price;
    final low = (meta['regularMarketDayLow'] as num?)?.toDouble() ?? price;
    final volume = (meta['regularMarketVolume'] as num?)?.toDouble() ?? 0.0;
    final fiftyTwoHigh = (meta['fiftyTwoWeekHigh'] as num?)?.toDouble();
    final fiftyTwoLow = (meta['fiftyTwoWeekLow'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    final currency = meta['currency']?.toString().toUpperCase() == 'INR' ? 'INR' : 'USD';

    return CryptoPriceTick(
      symbol: symbol,
      price: price,
      changePercent24h: changePercent,
      high24h: high,
      low24h: low,
      volume24h: volume,
      timestamp: DateTime.now(),
      currency: currency,
      fiftyTwoWeekHigh: fiftyTwoHigh,
      fiftyTwoWeekLow: fiftyTwoLow,
      previousClose: prevClose,
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
        'currency': currency,
        'fiftyTwoWeekHigh': fiftyTwoWeekHigh,
        'fiftyTwoWeekLow': fiftyTwoWeekLow,
        'previousClose': previousClose,
      };

  factory CryptoPriceTick.fromJson(Map<String, dynamic> json) => CryptoPriceTick(
        symbol: json['symbol'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        changePercent24h: (json['changePercent24h'] as num?)?.toDouble() ?? 0.0,
        high24h: (json['high24h'] as num?)?.toDouble() ?? 0.0,
        low24h: (json['low24h'] as num?)?.toDouble() ?? 0.0,
        volume24h: (json['volume24h'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        currency: json['currency'] as String? ?? 'USD',
        fiftyTwoWeekHigh: (json['fiftyTwoWeekHigh'] as num?)?.toDouble(),
        fiftyTwoWeekLow: (json['fiftyTwoWeekLow'] as num?)?.toDouble(),
        previousClose: (json['previousClose'] as num?)?.toDouble(),
      );
}

/// Supported historical chart timeframes
enum TradingTimeframe {
  oneDay('1D', 'Past 24 Hours', '1D'),
  oneWeek('1W', 'Past 7 Days', '1W'),
  oneMonth('1M', 'Past 30 Days', '1M'),
  oneYear('1Y', 'Past 1 Year', '1Y'),
  all('ALL', 'All Time', 'ALL');

  final String label;
  final String title;
  final String apiValue;

  const TradingTimeframe(this.label, this.title, this.apiValue);
}

/// A real historical data point for multi-timeframe charts
class HistoricalDataPoint {
  final DateTime timestamp;
  final double price;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;

  const HistoricalDataPoint({
    required this.timestamp,
    required this.price,
    this.open,
    this.high,
    this.low,
    this.volume,
  });

  double get close => price;
}

/// Historical price bundle for an asset
class HistoricalPriceSummary {
  final String symbol;
  final String timeframe; // '1D', '1W', '1M', '1Y', 'ALL'
  final List<HistoricalDataPoint> points;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final double? dayHigh;
  final double? dayLow;
  final double? previousClose;
  final double periodReturnPercent;
  final double minPrice;
  final double maxPrice;

  const HistoricalPriceSummary({
    required this.symbol,
    required this.timeframe,
    required this.points,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.dayHigh,
    this.dayLow,
    this.previousClose,
    required this.periodReturnPercent,
    required this.minPrice,
    required this.maxPrice,
  });

  bool get isPositive => periodReturnPercent >= 0;

  double? get high52w => fiftyTwoWeekHigh;
  double? get low52w => fiftyTwoWeekLow;
  double? get highPeriod => dayHigh ?? (points.isNotEmpty ? maxPrice : null);
  double? get lowPeriod => dayLow ?? (points.isNotEmpty ? minPrice : null);
  double get volumePeriod =>
      points.fold<double>(0.0, (acc, p) => acc + (p.volume ?? 0.0));
}

/// Types of comparison shadow curves that can be overlaid behind the active chart
enum ShadowGraphType {
  none('OFF', 'None', 'Disable shadow comparison'),
  previousPeriod('PREV PERIOD', 'Previous Period', 'Previous cycle comparison'),
  sameDayLastWeek('LAST WEEK', 'Same Day Last Week', 'Same weekday from prior week'),
  sameDayLastMonth('LAST MONTH', 'Same Day Last Month', 'Same calendar day from prior month'),
  sameDayLastYear('1 YEAR AGO', '1 Year Ago', 'Exact same date / period from 1 year ago');

  final String chipLabel;
  final String title;
  final String description;

  const ShadowGraphType(this.chipLabel, this.title, this.description);

  /// Dynamic contextual label adapted to current timeframe
  String getContextLabel(TradingTimeframe tf) {
    switch (this) {
      case ShadowGraphType.none:
        return 'OFF';
      case ShadowGraphType.previousPeriod:
        switch (tf) {
          case TradingTimeframe.oneDay:
            return 'YESTERDAY';
          case TradingTimeframe.oneWeek:
            return 'LAST WEEK';
          case TradingTimeframe.oneMonth:
            return 'LAST MONTH';
          case TradingTimeframe.oneYear:
            return 'LAST YEAR';
          case TradingTimeframe.all:
            return 'PREV CYCLE';
        }
      case ShadowGraphType.sameDayLastWeek:
        switch (tf) {
          case TradingTimeframe.oneDay:
            return 'LAST WEEK DAY';
          case TradingTimeframe.oneWeek:
            return 'PRIOR 7D CYCLE';
          case TradingTimeframe.oneMonth:
            return 'PRIOR 4W CYCLE';
          case TradingTimeframe.oneYear:
            return 'WEEKDAY PROFILE';
          case TradingTimeframe.all:
            return 'PRIOR CYCLE';
        }
      case ShadowGraphType.sameDayLastMonth:
        switch (tf) {
          case TradingTimeframe.oneDay:
            return 'LAST MONTH DAY';
          case TradingTimeframe.oneWeek:
            return 'SAME WEEK LAST MO';
          case TradingTimeframe.oneMonth:
            return 'PRIOR MONTH';
          case TradingTimeframe.oneYear:
            return 'MONTHLY PROFILE';
          case TradingTimeframe.all:
            return 'PRIOR EPOCH';
        }
      case ShadowGraphType.sameDayLastYear:
        switch (tf) {
          case TradingTimeframe.oneDay:
            return '1 YEAR AGO';
          case TradingTimeframe.oneWeek:
            return 'SAME WEEK 1Y AGO';
          case TradingTimeframe.oneMonth:
            return 'SAME MONTH 1Y AGO';
          case TradingTimeframe.oneYear:
            return 'PRIOR YEAR';
          case TradingTimeframe.all:
            return 'ANNUAL BENCHMARK';
        }
    }
  }
}

/// Represents a shadow comparison dataset aligned with the primary chart
class ShadowComparisonSeries {
  final ShadowGraphType type;
  final String label;
  final List<HistoricalDataPoint> points;
  final double periodReturnPercent;
  final double minPrice;
  final double maxPrice;
  final DateTime? referenceDate;

  const ShadowComparisonSeries({
    required this.type,
    required this.label,
    required this.points,
    required this.periodReturnPercent,
    required this.minPrice,
    required this.maxPrice,
    this.referenceDate,
  });

  bool get isPositive => periodReturnPercent >= 0;
  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  /// Returns normalized overlay prices aligned with the target length and starting base price.
  /// Uses financial rebased indexing:
  /// P_overlay(i) = baseStartPrice * (1 + (P_shadow(i) - P_shadow_start) / P_shadow_start)
  List<double> getAlignedPrices({
    required int targetLength,
    required double baseStartPrice,
    bool normalized = true,
  }) {
    if (points.isEmpty || targetLength <= 0) return [];

    final shadowStartPrice = points.first.price;
    final res = <double>[];

    for (int i = 0; i < targetLength; i++) {
      final double progress = targetLength > 1 ? i / (targetLength - 1) : 0.0;
      final double shadowIndexFloat = progress * (points.length - 1);
      final int lowerIdx = shadowIndexFloat.floor().clamp(0, points.length - 1);
      final int upperIdx = shadowIndexFloat.ceil().clamp(0, points.length - 1);
      final double fraction = shadowIndexFloat - lowerIdx;

      final double rawPrice = (lowerIdx == upperIdx)
          ? points[lowerIdx].price
          : points[lowerIdx].price * (1.0 - fraction) + points[upperIdx].price * fraction;

      if (normalized && shadowStartPrice > 0 && baseStartPrice > 0) {
        final double shadowReturn = (rawPrice - shadowStartPrice) / shadowStartPrice;
        res.add(baseStartPrice * (1.0 + shadowReturn));
      } else {
        res.add(rawPrice);
      }
    }

    return res;
  }
}


/// Universal holding position (Crypto + Indian stocks)
/// Universal holding position (Crypto + Indian stocks) with peak tracking
class CryptoHolding {
  final String symbol;
  final String coinName;
  final double quantity;
  final double avgBuyPriceUSDT; // or avgBuyPrice in native currency (INR for stocks)
  final double totalCostINR;
  final String currency;        // 'INR' or 'USD'
  final double peakPrice;       // Highest price reached since position opened
  final bool hasReachedHigher;  // True if position has ever been in profit / reached a higher high
  final DateTime? peakTimestamp;

  CryptoHolding({
    required this.symbol,
    required this.coinName,
    required this.quantity,
    required this.avgBuyPriceUSDT,
    required this.totalCostINR,
    this.currency = 'USD',
    double? peakPrice,
    this.hasReachedHigher = false,
    this.peakTimestamp,
  }) : peakPrice = peakPrice ?? avgBuyPriceUSDT;

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);
  TradingAsset get assetInfo => TradingAsset.fromSymbol(symbol);

  double currentValueUSDT(double currentPriceNative) {
    if (currency == 'INR') {
      return (quantity * currentPriceNative) / 88.0;
    }
    return quantity * currentPriceNative;
  }

  double currentValueINR(double currentPriceNative, double usdtToInrRate) {
    if (currency == 'INR') {
      return quantity * currentPriceNative;
    }
    return quantity * currentPriceNative * usdtToInrRate;
  }

  double pnlINR(double currentPriceNative, double usdtToInrRate) =>
      currentValueINR(currentPriceNative, usdtToInrRate) - totalCostINR;

  double pnlPercent(double currentPriceNative, double usdtToInrRate) {
    if (totalCostINR <= 0) return 0.0;
    return (pnlINR(currentPriceNative, usdtToInrRate) / totalCostINR) * 100;
  }

  /// Calculates percentage gain at the peak price
  double get peakGainPercent {
    if (avgBuyPriceUSDT <= 0) return 0.0;
    return ((peakPrice - avgBuyPriceUSDT) / avgBuyPriceUSDT) * 100.0;
  }

  /// Percentage retracement / drawdown from peak
  double drawdownFromPeakPercent(double currentPriceNative) {
    if (peakPrice <= 0) return 0.0;
    return ((peakPrice - currentPriceNative) / peakPrice) * 100.0;
  }

  /// True if position was higher than buy price previously, but has now dropped into net loss
  bool isLosingMoneyAfterHigher(double currentPriceNative) {
    return hasReachedHigher && currentPriceNative < avgBuyPriceUSDT;
  }

  CryptoHolding copyWith({
    String? symbol,
    String? coinName,
    double? quantity,
    double? avgBuyPriceUSDT,
    double? totalCostINR,
    String? currency,
    double? peakPrice,
    bool? hasReachedHigher,
    DateTime? peakTimestamp,
  }) {
    return CryptoHolding(
      symbol: symbol ?? this.symbol,
      coinName: coinName ?? this.coinName,
      quantity: quantity ?? this.quantity,
      avgBuyPriceUSDT: avgBuyPriceUSDT ?? this.avgBuyPriceUSDT,
      totalCostINR: totalCostINR ?? this.totalCostINR,
      currency: currency ?? this.currency,
      peakPrice: peakPrice ?? this.peakPrice,
      hasReachedHigher: hasReachedHigher ?? this.hasReachedHigher,
      peakTimestamp: peakTimestamp ?? this.peakTimestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'coinName': coinName,
        'quantity': quantity,
        'avgBuyPriceUSDT': avgBuyPriceUSDT,
        'totalCostINR': totalCostINR,
        'currency': currency,
        'peakPrice': peakPrice,
        'hasReachedHigher': hasReachedHigher,
        'peakTimestamp': peakTimestamp?.toIso8601String(),
      };

  factory CryptoHolding.fromJson(Map<String, dynamic> json) {
    final avgBuy = (json['avgBuyPriceUSDT'] as num?)?.toDouble() ?? 0.0;
    return CryptoHolding(
      symbol: json['symbol'] as String? ?? '',
      coinName: json['coinName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      avgBuyPriceUSDT: avgBuy,
      totalCostINR: (json['totalCostINR'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ??
          (json['symbol']?.toString().contains('.NS') == true ? 'INR' : 'USD'),
      peakPrice: (json['peakPrice'] as num?)?.toDouble() ?? avgBuy,
      hasReachedHigher: json['hasReachedHigher'] as bool? ?? false,
      peakTimestamp: json['peakTimestamp'] != null
          ? DateTime.tryParse(json['peakTimestamp'] as String)
          : null,
    );
  }
}

/// Represents the aggregate hourly trend and direction
class HourlyMarketTrend {
  final double avgChangePercent;
  final int sampleCount;

  const HourlyMarketTrend({
    required this.avgChangePercent,
    required this.sampleCount,
  });

  bool get isGoingUp => avgChangePercent > 0.03;
  bool get isGoingDown => avgChangePercent < -0.03;
  bool get isSideways => !isGoingUp && !isGoingDown;

  String get directionLabel {
    if (isGoingUp) return 'GOING UP';
    if (isGoingDown) return 'GOING DOWN';
    return 'SIDEWAYS';
  }
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
  final double targetPriceUSDT; // In asset's native currency
  final double? executedPriceUSDT;
  final double totalINR;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? filledAt;
  final String currency; // 'INR' or 'USD'

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
    this.currency = 'USD',
  });

  bool get isBuy => side == OrderSide.buy;
  bool get isSell => side == OrderSide.sell;
  bool get isLimit => orderType == TradingOrderType.limit;
  bool get isMarket => orderType == TradingOrderType.market;
  bool get isPending => status == OrderStatus.pending;
  bool get isFilled => status == OrderStatus.filled;
  bool get isCancelled => status == OrderStatus.cancelled;

  CryptoSymbol? get symbolInfo => CryptoSymbol.fromRaw(symbol);
  TradingAsset get assetInfo => TradingAsset.fromSymbol(symbol);

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
      currency: currency,
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
        'currency': currency,
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
        currency: json['currency'] as String? ?? (json['symbol']?.toString().contains('.NS') == true ? 'INR' : 'USD'),
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
