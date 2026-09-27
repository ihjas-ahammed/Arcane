import 'package:flutter/material.dart';
import 'package:missions/src/models/trading_models.dart';

/// Emotional state a trader can flag before placing an order.
///
/// Five of the six states are the "dumb money" states the book's psychology
/// framework warns about; `calm` is the goal, `fearful` is a caution state
/// (not automatically dumb-money, but worth a second look).
enum TraderMood { calm, fearful, fomo, revenge, bored, overconfident }

extension TraderMoodX on TraderMood {
  String get label {
    switch (this) {
      case TraderMood.calm:
        return 'CALM';
      case TraderMood.fearful:
        return 'FEARFUL';
      case TraderMood.fomo:
        return 'FOMO';
      case TraderMood.revenge:
        return 'REVENGE';
      case TraderMood.bored:
        return 'BORED';
      case TraderMood.overconfident:
        return 'OVERCONFIDENT';
    }
  }

  /// True for the states the book associates with impulsive, low-quality decisions.
  bool get isDumbMoneyState =>
      this == TraderMood.fomo ||
      this == TraderMood.revenge ||
      this == TraderMood.bored ||
      this == TraderMood.overconfident;

  /// Fear isn't a dumb-money state on its own, but it deserves a caution flag.
  bool get isCaution => this == TraderMood.fearful;

  String get coaching {
    switch (this) {
      case TraderMood.calm:
        return 'Clear head, defined risk — this is the state good decisions come from.';
      case TraderMood.fearful:
        return 'Fear is a reason to size down, not a reason to abandon a plan you already validated.';
      case TraderMood.fomo:
        return 'The market will wait. If you missed the entry, wait for the next one.';
      case TraderMood.revenge:
        return 'This trade will not undo the last one. Step away before you size up trying to get even.';
      case TraderMood.bored:
        return 'Boredom is not an edge. No setup, no trade — go find one instead of forcing this.';
      case TraderMood.overconfident:
        return 'A hot streak is a reason to protect what you have, not to size up. Keep the plan the same.';
    }
  }
}

/// The defense-first plan attached to a BUY order and carried onto the holding it opens.
class TradePlan {
  final double? stopPrice; // native price (INR for NSE, USD for crypto)
  final double? plannedRiskINR; // (entry - stop) * qty * inrPerUnit
  final double? riskPercentOfPortfolio; // plannedRiskINR / portfolio value at entry * 100
  final String? edge; // one line
  final String? meView;
  final String? crowdView;
  final String? againstView;
  final TraderMood? mood;
  final int checklistScore; // e.g. 4
  final int checklistTotal; // e.g. 5
  final DateTime createdAt;

  TradePlan({
    this.stopPrice,
    this.plannedRiskINR,
    this.riskPercentOfPortfolio,
    this.edge,
    this.meView,
    this.crowdView,
    this.againstView,
    this.mood,
    this.checklistScore = 0,
    this.checklistTotal = 5,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'stopPrice': stopPrice,
        'plannedRiskINR': plannedRiskINR,
        'riskPercentOfPortfolio': riskPercentOfPortfolio,
        'edge': edge,
        'meView': meView,
        'crowdView': crowdView,
        'againstView': againstView,
        'mood': mood?.name,
        'checklistScore': checklistScore,
        'checklistTotal': checklistTotal,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TradePlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TradePlan();
    return TradePlan(
      stopPrice: (json['stopPrice'] as num?)?.toDouble(),
      plannedRiskINR: (json['plannedRiskINR'] as num?)?.toDouble(),
      riskPercentOfPortfolio: (json['riskPercentOfPortfolio'] as num?)?.toDouble(),
      edge: json['edge'] as String?,
      meView: json['meView'] as String?,
      crowdView: json['crowdView'] as String?,
      againstView: json['againstView'] as String?,
      mood: json['mood'] != null
          ? TraderMood.values.firstWhere(
              (m) => m.name == json['mood'],
              orElse: () => TraderMood.calm,
            )
          : null,
      checklistScore: (json['checklistScore'] as num?)?.toInt() ?? 0,
      checklistTotal: (json['checklistTotal'] as num?)?.toInt() ?? 5,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

/// Why a position was closed.
enum TradeExitReason { manual, stopHit, limitFilled }

/// One closed (or partially closed) round trip — a row in the trade journal.
class TradeRecord {
  final String id;
  final String symbol;
  final String coinName;
  final String currency;
  final double quantity;
  final double entryAvgPrice; // native price
  final double exitAvgPrice; // native price
  final double costINR;
  final double proceedsINR;
  final double? plannedRiskINR; // scaled to the closed fraction
  final DateTime openedAt;
  final DateTime closedAt;
  final TradeExitReason exitReason;
  final TradePlan? plan;

  // Post-trade review
  final bool? followedPlan;
  final String? processGrade; // 'A' | 'B' | 'C'
  final String? lesson;
  final DateTime? reviewedAt;

  TradeRecord({
    required this.id,
    required this.symbol,
    required this.coinName,
    required this.currency,
    required this.quantity,
    required this.entryAvgPrice,
    required this.exitAvgPrice,
    required this.costINR,
    required this.proceedsINR,
    this.plannedRiskINR,
    required this.openedAt,
    required this.closedAt,
    required this.exitReason,
    this.plan,
    this.followedPlan,
    this.processGrade,
    this.lesson,
    this.reviewedAt,
  });

  double get realizedPnlINR => proceedsINR - costINR;

  double get realizedPnlPercent => costINR <= 0 ? 0.0 : realizedPnlINR / costINR * 100;

  double? get rMultiple =>
      (plannedRiskINR == null || plannedRiskINR! <= 0) ? null : realizedPnlINR / plannedRiskINR!;

  Duration get holdingPeriod => closedAt.difference(openedAt);

  bool get isReviewed => reviewedAt != null;

  TradeRecord copyWith({
    bool? followedPlan,
    String? processGrade,
    String? lesson,
    DateTime? reviewedAt,
  }) {
    return TradeRecord(
      id: id,
      symbol: symbol,
      coinName: coinName,
      currency: currency,
      quantity: quantity,
      entryAvgPrice: entryAvgPrice,
      exitAvgPrice: exitAvgPrice,
      costINR: costINR,
      proceedsINR: proceedsINR,
      plannedRiskINR: plannedRiskINR,
      openedAt: openedAt,
      closedAt: closedAt,
      exitReason: exitReason,
      plan: plan,
      followedPlan: followedPlan ?? this.followedPlan,
      processGrade: processGrade ?? this.processGrade,
      lesson: lesson ?? this.lesson,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'coinName': coinName,
        'currency': currency,
        'quantity': quantity,
        'entryAvgPrice': entryAvgPrice,
        'exitAvgPrice': exitAvgPrice,
        'costINR': costINR,
        'proceedsINR': proceedsINR,
        'plannedRiskINR': plannedRiskINR,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt.toIso8601String(),
        'exitReason': exitReason.name,
        'plan': plan?.toJson(),
        'followedPlan': followedPlan,
        'processGrade': processGrade,
        'lesson': lesson,
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory TradeRecord.fromJson(Map<String, dynamic> json) => TradeRecord(
        id: json['id'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        coinName: json['coinName'] as String? ?? '',
        currency: json['currency'] as String? ?? 'USD',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        entryAvgPrice: (json['entryAvgPrice'] as num?)?.toDouble() ?? 0.0,
        exitAvgPrice: (json['exitAvgPrice'] as num?)?.toDouble() ?? 0.0,
        costINR: (json['costINR'] as num?)?.toDouble() ?? 0.0,
        proceedsINR: (json['proceedsINR'] as num?)?.toDouble() ?? 0.0,
        plannedRiskINR: (json['plannedRiskINR'] as num?)?.toDouble(),
        openedAt: DateTime.tryParse(json['openedAt'] as String? ?? '') ?? DateTime.now(),
        closedAt: DateTime.tryParse(json['closedAt'] as String? ?? '') ?? DateTime.now(),
        exitReason: TradeExitReason.values.firstWhere(
          (e) => e.name == json['exitReason'],
          orElse: () => TradeExitReason.manual,
        ),
        plan: json['plan'] is Map ? TradePlan.fromJson(Map<String, dynamic>.from(json['plan'] as Map)) : null,
        followedPlan: json['followedPlan'] as bool?,
        processGrade: json['processGrade'] as String?,
        lesson: json['lesson'] as String?,
        reviewedAt: json['reviewedAt'] != null ? DateTime.tryParse(json['reviewedAt'] as String) : null,
      );
}

/// Persistent risk-management rules the trader configures once.
class TradingRiskSettings {
  final double baseRiskPercent;
  final double maxRiskPercent;
  final bool strictRiskGuard;
  final double defaultStopPercent;
  final int dailyTradeCap; // 0 = off
  final bool requireChecklist;

  const TradingRiskSettings({
    this.baseRiskPercent = 1.0,
    this.maxRiskPercent = 1.0,
    this.strictRiskGuard = true,
    this.defaultStopPercent = 7.0,
    this.dailyTradeCap = 5,
    this.requireChecklist = false,
  });

  TradingRiskSettings copyWith({
    double? baseRiskPercent,
    double? maxRiskPercent,
    bool? strictRiskGuard,
    double? defaultStopPercent,
    int? dailyTradeCap,
    bool? requireChecklist,
  }) {
    return TradingRiskSettings(
      baseRiskPercent: baseRiskPercent ?? this.baseRiskPercent,
      maxRiskPercent: maxRiskPercent ?? this.maxRiskPercent,
      strictRiskGuard: strictRiskGuard ?? this.strictRiskGuard,
      defaultStopPercent: defaultStopPercent ?? this.defaultStopPercent,
      dailyTradeCap: dailyTradeCap ?? this.dailyTradeCap,
      requireChecklist: requireChecklist ?? this.requireChecklist,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseRiskPercent': baseRiskPercent,
        'maxRiskPercent': maxRiskPercent,
        'strictRiskGuard': strictRiskGuard,
        'defaultStopPercent': defaultStopPercent,
        'dailyTradeCap': dailyTradeCap,
        'requireChecklist': requireChecklist,
      };

  factory TradingRiskSettings.fromJson(Map<String, dynamic> json) => TradingRiskSettings(
        baseRiskPercent: (json['baseRiskPercent'] as num?)?.toDouble() ?? 1.0,
        maxRiskPercent: (json['maxRiskPercent'] as num?)?.toDouble() ?? 1.0,
        strictRiskGuard: json['strictRiskGuard'] as bool? ?? true,
        defaultStopPercent: (json['defaultStopPercent'] as num?)?.toDouble() ?? 7.0,
        dailyTradeCap: (json['dailyTradeCap'] as num?)?.toInt() ?? 5,
        requireChecklist: json['requireChecklist'] as bool? ?? false,
      );
}

/// A single point on the portfolio equity curve, at most one per calendar day.
class EquitySnapshot {
  final DateTime at;
  final double valueINR;

  const EquitySnapshot({required this.at, required this.valueINR});

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'valueINR': valueINR,
      };

  factory EquitySnapshot.fromJson(Map<String, dynamic> json) => EquitySnapshot(
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        valueINR: (json['valueINR'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Aggregate expectancy / drawdown statistics computed from the trade journal.
class SmartMoneyStats {
  final int closedTrades;
  final int wins;
  final int losses;
  final double winRate; // 0..100
  final double avgWinINR;
  final double avgLossINR; // positive magnitude
  final double winLossRatio; // avgWin / avgLoss (0 if no losses)
  final double expectancyINR; // per-trade expected value in INR
  final double? expectancyR; // mean R-multiple over records that have one
  final double profitFactor; // grossWins / grossLosses
  final double largestWinINR;
  final double largestLossINR; // positive magnitude
  final int currentStreak; // +n consecutive wins, -n consecutive losses
  final double equityPeakINR;
  final double currentEquityINR;
  final double currentDrawdownPercent; // >= 0
  final double maxDrawdownPercent; // >= 0

  const SmartMoneyStats({
    required this.closedTrades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.avgWinINR,
    required this.avgLossINR,
    required this.winLossRatio,
    required this.expectancyINR,
    required this.expectancyR,
    required this.profitFactor,
    required this.largestWinINR,
    required this.largestLossINR,
    required this.currentStreak,
    required this.equityPeakINR,
    required this.currentEquityINR,
    required this.currentDrawdownPercent,
    required this.maxDrawdownPercent,
  });

  factory SmartMoneyStats.empty(double equityINR) => SmartMoneyStats(
        closedTrades: 0,
        wins: 0,
        losses: 0,
        winRate: 0,
        avgWinINR: 0,
        avgLossINR: 0,
        winLossRatio: 0,
        expectancyINR: 0,
        expectancyR: null,
        profitFactor: 0,
        largestWinINR: 0,
        largestLossINR: 0,
        currentStreak: 0,
        equityPeakINR: equityINR,
        currentEquityINR: equityINR,
        currentDrawdownPercent: 0,
        maxDrawdownPercent: 0,
      );

  static SmartMoneyStats compute({
    required List<TradeRecord> records,
    required List<EquitySnapshot> snapshots,
    required double currentEquityINR,
    required double startingEquityINR,
  }) {
    final closed = records.length;
    int wins = 0;
    int losses = 0;
    double grossWins = 0.0;
    double grossLosses = 0.0; // positive magnitude
    double largestWin = 0.0;
    double largestLoss = 0.0; // positive magnitude
    final rValues = <double>[];

    for (final r in records) {
      final pnl = r.realizedPnlINR;
      if (pnl > 0) {
        wins++;
        grossWins += pnl;
        if (pnl > largestWin) largestWin = pnl;
      } else if (pnl < 0) {
        losses++;
        grossLosses += -pnl;
        if (-pnl > largestLoss) largestLoss = -pnl;
      }
      final rm = r.rMultiple;
      if (rm != null) rValues.add(rm);
    }

    final winRate = closed > 0 ? wins / closed * 100 : 0.0;
    final avgWin = wins > 0 ? grossWins / wins : 0.0;
    final avgLoss = losses > 0 ? grossLosses / losses : 0.0;
    final winLossRatio = losses > 0 ? avgWin / avgLoss : 0.0;
    final winProbability = closed > 0 ? wins / closed : 0.0;
    final lossProbability = closed > 0 ? losses / closed : 0.0;
    final expectancy = closed > 0 ? (winProbability * avgWin - lossProbability * avgLoss) : 0.0;
    final expectancyR = rValues.isEmpty ? null : rValues.reduce((a, b) => a + b) / rValues.length;
    final profitFactor = grossLosses > 0
        ? grossWins / grossLosses
        : (grossWins > 0 ? double.infinity : 0.0);

    // Streak: walk backwards from the most recently closed trade.
    final sortedByClose = [...records]..sort((a, b) => a.closedAt.compareTo(b.closedAt));
    int streak = 0;
    for (int i = sortedByClose.length - 1; i >= 0; i--) {
      final pnl = sortedByClose[i].realizedPnlINR;
      if (pnl == 0) break;
      final isWin = pnl > 0;
      if (streak == 0) {
        streak = isWin ? 1 : -1;
      } else if ((streak > 0) == isWin) {
        streak += isWin ? 1 : -1;
      } else {
        break;
      }
    }

    double peak = startingEquityINR;
    double maxDrawdown = 0.0;
    for (final s in snapshots) {
      if (s.valueINR > peak) peak = s.valueINR;
      final dd = peak > 0 ? (peak - s.valueINR) / peak * 100 : 0.0;
      if (dd > maxDrawdown) maxDrawdown = dd;
    }
    if (currentEquityINR > peak) peak = currentEquityINR;
    final currentDrawdown = peak > 0 ? (peak - currentEquityINR) / peak * 100 : 0.0;
    if (currentDrawdown > maxDrawdown) maxDrawdown = currentDrawdown;

    return SmartMoneyStats(
      closedTrades: closed,
      wins: wins,
      losses: losses,
      winRate: winRate,
      avgWinINR: avgWin,
      avgLossINR: avgLoss,
      winLossRatio: winLossRatio,
      expectancyINR: expectancy,
      expectancyR: expectancyR,
      profitFactor: profitFactor,
      largestWinINR: largestWin,
      largestLossINR: largestLoss,
      currentStreak: streak,
      equityPeakINR: peak,
      currentEquityINR: currentEquityINR,
      currentDrawdownPercent: currentDrawdown < 0 ? 0.0 : currentDrawdown,
      maxDrawdownPercent: maxDrawdown < 0 ? 0.0 : maxDrawdown,
    );
  }
}

/// The eight Smart Money Protocol guide cards, in original wording.
class SmartMoneyGuides {
  static List<TradingGuideCard> get cards => const [
        TradingGuideCard(
          id: 'respect_risk',
          title: 'Rule one: always respect risk',
          subtitle: 'Defense first',
          icon: Icons.shield_outlined,
          content:
              "Before you buy, decide where you'll exit if you're wrong and how much that costs. Big funds rarely risk more than 1% of the portfolio on one idea. The math is brutal in reverse: a 10% loss needs +11% to get back to even, 20% needs +25%, 50% needs +100%. Small losses are the cost of doing business; large ones are how accounts die. This simulator sizes every buy from your stop and your risk budget so the loss is known before the trade exists.",
        ),
        TradingGuideCard(
          id: 'three_exits',
          title: 'There are only three exits',
          subtitle: 'Gain · Breakeven · Loss',
          icon: Icons.call_split_rounded,
          content:
              "Every position ends one of three ways: a gain, a breakeven, or a loss. Decide all three in advance. Place the protective stop just below a logical support level. When the trade is up roughly 5–10%, raise the stop to breakeven so the market can no longer take your capital. Then trail it higher behind the trend. Selling is a decision you make before you enter, not in the heat of the moment.",
        ),
        TradingGuideCard(
          id: 'never_widen',
          title: 'Reduce risk after entry. Never increase it.',
          subtitle: 'Stops only move up',
          icon: Icons.lock_outline_rounded,
          content:
              "The beginner's reflex when a trade goes wrong is to move the stop lower to 'give it room'. That converts a small, planned loss into an unplanned large one. Here, a stop can be raised but never lowered. If a position isn't acting right, exit or tighten — those are the only two options.",
        ),
        TradingGuideCard(
          id: 'win_rate_myth',
          title: 'Win rate is the wrong scoreboard',
          subtitle: 'Size of wins vs size of losses',
          icon: Icons.leaderboard_outlined,
          content:
              "Excellent traders are often right only 3 times in 10 and still compound wealth, because each winner is several times larger than each loser. Lose 1 unit nine times and win 20 once and you're up 11. The Journal tab therefore leads with expectancy, average-win-to-average-loss and profit factor; the win rate is shown small on purpose.",
        ),
        TradingGuideCard(
          id: 'equity_curve',
          title: 'Trade your equity curve',
          subtitle: 'Drawdown ladder',
          icon: Icons.ssid_chart_rounded,
          content:
              "Drawdowns are inevitable; the skill is managing them. When your portfolio is under its peak, step the risk per idea down (1% → 0.75% → 0.5% → 0.25%) until you're back on track, and never raise it just because you feel hot. The order sheet suggests a reduced risk percentage automatically when the account is in a drawdown.",
        ),
        TradingGuideCard(
          id: 'gate',
          title: 'Ask before you pull the trigger',
          subtitle: 'The pre-trade gate',
          icon: Icons.fact_check_outlined,
          content:
              "Is this the best idea available right now, or am I forcing it? Am I early (buying the bounce after the dip) or late (chasing an extended move)? Am I aligned with the trend? What is my edge in one sentence? What is the crowd doing — and would I rather do the opposite? Write three columns: Me, Crowd, Against. If you can't fill them, you haven't thought it through.",
        ),
        TradingGuideCard(
          id: 'biases',
          title: 'Catch the bias before it costs you',
          subtitle: 'Anchoring · Sunk cost · Disposition',
          icon: Icons.psychology_outlined,
          content:
              "Anchoring: your entry price is an arbitrary number the market doesn't know about. Sunk cost: a paper loss is a real loss; averaging down is throwing good money after bad. Disposition effect: selling winners early and holding losers long — the exact opposite of what works. Recency and groupthink: when everyone is talking about it, the move is usually over. Judge each decision by the information you had, not by the outcome.",
        ),
        TradingGuideCard(
          id: 'personalities',
          title: 'Which trader are you today?',
          subtitle: 'Seven personalities',
          icon: Icons.groups_outlined,
          content:
              "The Scaredy Cat trades from fear and bails on good positions. The Cowboy goes all-in and eventually blows up. The Professor analyses forever and never pulls the trigger. The Machine Gun fires trades all day for the rush. The Artist trades conspiracy theories instead of price. The Passive Trader watches from the sidelines. The Smart Money Trader plays defense first, makes unemotional decisions and lets time do the work. Pick a mood before every order; the app will tell you which one you're being.",
        ),
      ];
}
