import 'dart:math' as math;

/// Pure risk-sizing math for the Smart Money Protocol layer.
///
/// Nothing here touches the provider, market data, or widgets — every
/// function is a straight numeric transform so it can be unit tested in
/// isolation.

/// How much INR you're willing to lose on one idea, given the portfolio
/// value and a risk percent (e.g. 1.0 for 1%).
double riskBudgetINR(double portfolioValueINR, double riskPercent) {
  if (portfolioValueINR <= 0 || riskPercent <= 0) return 0.0;
  return portfolioValueINR * riskPercent / 100.0;
}

/// Sizes a position so that a fill at [stopPrice] loses exactly [riskBudgetINR].
///
/// [inrPerUnit] is 1.0 for INR-priced assets and the USDT→INR rate for
/// USD-priced ones. Returns 0 when the stop doesn't sit below entry or any
/// input is non-positive. Floors to whole units when [wholeUnits] is true,
/// otherwise rounds down to [decimals] decimal places.
double positionSizeForRisk({
  required double entryPrice,
  required double stopPrice,
  required double riskBudgetINR,
  required double inrPerUnit,
  required int decimals,
  required bool wholeUnits,
}) {
  if (entryPrice <= 0 || stopPrice <= 0 || riskBudgetINR <= 0 || inrPerUnit <= 0) {
    return 0.0;
  }
  if (stopPrice >= entryPrice) return 0.0;

  final riskPerUnitINR = (entryPrice - stopPrice) * inrPerUnit;
  if (riskPerUnitINR <= 0) return 0.0;

  final rawQuantity = riskBudgetINR / riskPerUnitINR;
  if (wholeUnits) return rawQuantity.floorToDouble();

  final factor = math.pow(10, decimals).toDouble();
  return (rawQuantity * factor).floorToDouble() / factor;
}

/// The INR that would be lost if [quantity] units were stopped out at [stopPrice].
double riskAmountINR({
  required double entryPrice,
  required double stopPrice,
  required double quantity,
  required double inrPerUnit,
}) {
  if (quantity <= 0 || inrPerUnit <= 0) return 0.0;
  final risk = (entryPrice - stopPrice) * quantity * inrPerUnit;
  return risk > 0 ? risk : 0.0;
}

/// How far, in percent, the stop sits below the entry price.
double stopDistancePercent(double entryPrice, double stopPrice) {
  if (entryPrice <= 0) return 0.0;
  return (entryPrice - stopPrice) / entryPrice * 100;
}

/// The drawdown ladder: step risk per idea down as the account digs a hole,
/// and never raise it just because of a hot streak.
double suggestedRiskPercent(double baseRiskPercent, double currentDrawdownPercent) {
  double result;
  if (currentDrawdownPercent < 3) {
    result = baseRiskPercent;
  } else if (currentDrawdownPercent < 6) {
    result = baseRiskPercent * 0.75;
  } else if (currentDrawdownPercent < 10) {
    result = baseRiskPercent * 0.5;
  } else {
    result = baseRiskPercent * 0.25;
  }
  return double.parse(result.toStringAsFixed(2));
}

/// The gain needed, in percent, to recover from a given percentage loss.
/// 10% → 11.11%, 20% → 25%, 50% → 100%.
double recoveryGainNeededPercent(double lossPercent) {
  if (lossPercent >= 100) return double.infinity;
  if (lossPercent <= 0) return 0.0;
  return lossPercent / (100 - lossPercent) * 100;
}
