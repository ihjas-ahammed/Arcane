import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/models/trading_psychology_models.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/screens/trading/trading_smart_money_widgets.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/trading_risk_math.dart' as risk_math;

class TradingOrderSheet extends StatefulWidget {
  final TradingAsset asset;
  final PaperTradingProvider provider;
  final OrderSide initialSide;

  TradingOrderSheet({
    super.key,
    TradingAsset? asset,
    CryptoSymbol? symbol,
    required this.provider,
    this.initialSide = OrderSide.buy,
  }) : asset = asset ??
            (symbol != null
                ? TradingAsset.fromCryptoSymbol(symbol)
                : TradingAsset.fromCryptoSymbol(CryptoSymbol.btc));

  static Future<void> show({
    required BuildContext context,
    TradingAsset? asset,
    CryptoSymbol? symbol,
    required PaperTradingProvider provider,
    OrderSide initialSide = OrderSide.buy,
  }) {
    final effectiveAsset = asset ??
        (symbol != null
            ? TradingAsset.fromCryptoSymbol(symbol)
            : TradingAsset.fromCryptoSymbol(CryptoSymbol.btc));

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TradingOrderSheet(
        asset: effectiveAsset,
        provider: provider,
        initialSide: initialSide,
      ),
    );
  }

  @override
  State<TradingOrderSheet> createState() => _TradingOrderSheetState();
}

class _TradingOrderSheetState extends State<TradingOrderSheet> {
  late OrderSide _side;
  TradingOrderType _orderType = TradingOrderType.market;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _limitPriceController = TextEditingController();

  // ── Smart Money Protocol: risk plan + gate + mood ────────────────
  final TextEditingController _stopPriceController = TextEditingController();
  final TextEditingController _edgeController = TextEditingController();
  final TextEditingController _meController = TextEditingController();
  final TextEditingController _crowdController = TextEditingController();
  final TextEditingController _againstController = TextEditingController();
  late double _selectedRiskPercent;
  bool _gateBestIdea = false;
  bool _gateEarly = false;
  bool _gateTrend = false;
  TraderMood? _selectedMood;

  bool _isEditingQuantity = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;

    final tick = widget.provider.marketService.getTick(widget.asset.symbol);
    final initialPrice = tick?.price ?? (widget.asset.isIndianAsset ? 1500.0 : 1000.0);
    _limitPriceController.text = initialPrice.toStringAsFixed(widget.asset.isIndianAsset ? 2 : 2);

    final riskSettings = widget.provider.riskSettings;
    _selectedRiskPercent = widget.provider.suggestedRiskPercentFor(widget.provider.marketService.ticks);
    final defaultStop = initialPrice * (1 - riskSettings.defaultStopPercent / 100);
    if (defaultStop > 0) {
      _stopPriceController.text = defaultStop.toStringAsFixed(2);
    }
    _stopPriceController.addListener(_onRiskFieldChanged);
    _edgeController.addListener(_onRiskFieldChanged);
  }

  void _onRiskFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _quantityController.dispose();
    _limitPriceController.dispose();
    _stopPriceController.dispose();
    _edgeController.dispose();
    _meController.dispose();
    _crowdController.dispose();
    _againstController.dispose();
    super.dispose();
  }

  double get _currentLivePrice {
    final tick = widget.provider.marketService.getTick(widget.asset.symbol);
    return tick?.price ?? (widget.asset.isIndianAsset ? 1500.0 : 1000.0);
  }

  double get _effectivePrice {
    if (_orderType == TradingOrderType.limit) {
      return double.tryParse(_limitPriceController.text) ?? _currentLivePrice;
    }
    return _currentLivePrice;
  }

  double get _effectivePriceINR {
    if (widget.asset.isIndianAsset) {
      return _effectivePrice;
    }
    return _effectivePrice * widget.provider.usdtToInrRate;
  }

  // ── Smart Money Protocol: risk plan calculations ─────────────────

  Map<String, CryptoPriceTick> get _ticks => widget.provider.marketService.ticks;

  double get _totalPortfolioValueINR => widget.provider.totalPortfolioValueINR(_ticks);

  double get _inrPerUnit => widget.asset.isIndianAsset ? 1.0 : widget.provider.usdtToInrRate;

  double get _stopPriceValue => double.tryParse(_stopPriceController.text) ?? 0.0;

  double get _enteredQuantity => double.tryParse(_quantityController.text) ?? 0.0;

  double get _riskIfStoppedINR => risk_math.riskAmountINR(
        entryPrice: _effectivePrice,
        stopPrice: _stopPriceValue,
        quantity: _enteredQuantity,
        inrPerUnit: _inrPerUnit,
      );

  double get _riskPercentOfPortfolio =>
      _totalPortfolioValueINR > 0 ? (_riskIfStoppedINR / _totalPortfolioValueINR) * 100 : 0.0;

  double get _stopDistancePercentValue => risk_math.stopDistancePercent(_effectivePrice, _stopPriceValue);

  double get _positionPercentOfPortfolio {
    final totalINR = widget.asset.isIndianAsset
        ? _enteredQuantity * _effectivePrice
        : _enteredQuantity * _effectivePrice * widget.provider.usdtToInrRate;
    return _totalPortfolioValueINR > 0 ? (totalINR / _totalPortfolioValueINR) * 100 : 0.0;
  }

  double get _recoveryIfStoppedPercent => risk_math.recoveryGainNeededPercent(_stopDistancePercentValue);

  bool get _gateExitDefined => _stopPriceValue > 0 && _stopPriceValue < _effectivePrice;

  bool get _gateEdgeStated => _edgeController.text.trim().isNotEmpty;

  bool get _strictRiskBlocked {
    final riskSettings = widget.provider.riskSettings;
    return riskSettings.strictRiskGuard &&
        _riskIfStoppedINR > 0 &&
        _riskPercentOfPortfolio > riskSettings.maxRiskPercent + 1e-9;
  }

  bool get _dailyCapBlocked {
    final cap = widget.provider.riskSettings.dailyTradeCap;
    return cap > 0 && widget.provider.tradesToday >= cap;
  }

  int get _checklistScore =>
      (_gateBestIdea ? 1 : 0) +
      (_gateEarly ? 1 : 0) +
      (_gateTrend ? 1 : 0) +
      (_gateExitDefined ? 1 : 0) +
      (_gateEdgeStated ? 1 : 0);

  TradePlan _buildPlan() {
    return TradePlan(
      stopPrice: _stopPriceValue > 0 ? _stopPriceValue : null,
      plannedRiskINR: _riskIfStoppedINR > 0 ? _riskIfStoppedINR : null,
      riskPercentOfPortfolio: _riskIfStoppedINR > 0 ? _riskPercentOfPortfolio : null,
      edge: _edgeController.text.trim().isEmpty ? null : _edgeController.text.trim(),
      meView: _meController.text.trim().isEmpty ? null : _meController.text.trim(),
      crowdView: _crowdController.text.trim().isEmpty ? null : _crowdController.text.trim(),
      againstView: _againstController.text.trim().isEmpty ? null : _againstController.text.trim(),
      mood: _selectedMood,
      checklistScore: _checklistScore,
      checklistTotal: 5,
    );
  }

  void _sizeByRisk() {
    final budget = risk_math.riskBudgetINR(_totalPortfolioValueINR, _selectedRiskPercent);
    final qty = risk_math.positionSizeForRisk(
      entryPrice: _effectivePrice,
      stopPrice: _stopPriceValue,
      riskBudgetINR: budget,
      inrPerUnit: _inrPerUnit,
      decimals: widget.asset.decimals,
      wholeUnits: widget.asset.decimals == 0,
    );
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a stop below the live price first.')),
      );
      return;
    }
    _quantityController.text = qty.toStringAsFixed(widget.asset.decimals);
    _onQuantityChanged(_quantityController.text);
  }

  void _nudgeStopPercent(double pctBelow) {
    final base = _effectivePrice;
    final newStop = base * (1 - pctBelow / 100);
    // The controller's listener (_onRiskFieldChanged) triggers the rebuild.
    _stopPriceController.text = newStop > 0 ? newStop.toStringAsFixed(2) : '';
  }

  void _onAmountChanged(String val) {
    if (_isEditingQuantity) return;
    final inr = double.tryParse(val) ?? 0.0;
    if (_effectivePriceINR > 0) {
      final rawQty = inr / _effectivePriceINR;
      final qty = widget.asset.isIndianAsset && widget.asset.decimals == 0
          ? rawQty.floorToDouble()
          : rawQty;
      _quantityController.text = qty > 0 ? qty.toStringAsFixed(widget.asset.decimals) : '0';
    } else {
      _quantityController.text = '0';
    }
    setState(() {});
  }

  void _onQuantityChanged(String val) {
    _isEditingQuantity = true;
    final qty = double.tryParse(val) ?? 0.0;
    final inr = qty * _effectivePriceINR;
    _amountController.text = inr > 0 ? inr.toStringAsFixed(0) : '';
    _isEditingQuantity = false;
    setState(() {});
  }

  void _applyPercentage(double fraction) {
    if (_side == OrderSide.buy) {
      final maxCash = widget.provider.availableCash;
      final targetSpend = maxCash * fraction;
      _amountController.text = targetSpend.toStringAsFixed(0);
      _onAmountChanged(_amountController.text);
    } else {
      final availableUnits = widget.provider.getAvailableCoinQuantity(widget.asset.symbol);
      final rawTarget = availableUnits * fraction;
      final targetQty = widget.asset.isIndianAsset && widget.asset.decimals == 0
          ? rawTarget.floorToDouble()
          : rawTarget;
      _quantityController.text = targetQty.toStringAsFixed(widget.asset.decimals);
      _onQuantityChanged(_quantityController.text);
    }
  }

  void _adjustLimitPrice(double percentChange) {
    final current = double.tryParse(_limitPriceController.text) ?? _currentLivePrice;
    final updated = current * (1.0 + (percentChange / 100.0));
    _limitPriceController.text = updated.toStringAsFixed(2);
    _onAmountChanged(_amountController.text);
  }

  Future<void> _reviewAndConfirm() async {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final price = _effectivePrice;
    final totalINR = widget.asset.isIndianAsset
        ? qty * price
        : qty * price * widget.provider.usdtToInrRate;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity or spend amount.')),
      );
      return;
    }

    if (widget.asset.isIndianAsset && widget.asset.decimals == 0 && qty != qty.roundToDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indian equities require integer whole share quantities.')),
      );
      return;
    }

    if (_side == OrderSide.buy && !widget.provider.marketService.isRealtimeActive(widget.asset.symbol)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Real-time feed is offline or unverified. Purchases are locked to protect against stale fills.')),
      );
      return;
    }

    if (_side == OrderSide.buy && totalINR > widget.provider.availableCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient cash. Available: ₹${widget.provider.availableCash.toStringAsFixed(2)}')),
      );
      return;
    }

    if (_side == OrderSide.sell) {
      final availableQty = widget.provider.getAvailableCoinQuantity(widget.asset.symbol);
      if (qty > availableQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient position. Available: ${availableQty.toStringAsFixed(widget.asset.decimals)} ${widget.asset.baseAsset}')),
        );
        return;
      }
    }

    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          'CONFIRM ${_side.name.toUpperCase()} ORDER',
          style: GoogleFonts.jetBrainsMono(
            color: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReviewRow('Action', '${_side.name.toUpperCase()} (${_orderType.name.toUpperCase()})'),
            _buildReviewRow('Asset', widget.asset.pairLabel),
            _buildReviewRow('Exchange', widget.asset.exchange),
            _buildReviewRow('Quantity', '${qty.toStringAsFixed(widget.asset.decimals)} ${widget.asset.baseAsset}'),
            _buildReviewRow(
              'Unit Price',
              widget.asset.isIndianAsset
                  ? inrFormat.format(price)
                  : '\$${price.toStringAsFixed(2)} (~${inrFormat.format(price * widget.provider.usdtToInrRate)})',
            ),
            const Divider(height: 16),
            _buildReviewRow(
              'Estimated Total',
              widget.asset.isIndianAsset
                  ? inrFormat.format(totalINR)
                  : '${inrFormat.format(totalINR)} (\$${(totalINR / widget.provider.usdtToInrRate).toStringAsFixed(2)})',
              isHighlight: true,
            ),
            if (_side == OrderSide.buy && _stopPriceValue > 0) ...[
              const Divider(height: 16),
              _buildReviewRow(
                'Stop',
                widget.asset.isIndianAsset ? inrFormat.format(_stopPriceValue) : '\$${_stopPriceValue.toStringAsFixed(2)}',
              ),
              _buildReviewRow(
                'Risk',
                '₹${_riskIfStoppedINR.toStringAsFixed(0)} (${_riskPercentOfPortfolio.toStringAsFixed(2)}%)',
              ),
              if (_riskIfStoppedINR > 0)
                _buildReviewRow('R:R hint', '(1R = ₹${_riskIfStoppedINR.toStringAsFixed(0)})'),
              _buildReviewRow('Gate', '$_checklistScore/5'),
              if (_selectedMood != null) _buildReviewRow('Mood', _selectedMood!.label),
            ],
            const SizedBox(height: 10),
            Text(
              _orderType == TradingOrderType.market
                  ? 'Fills immediately at simulated market price.'
                  : 'Order will sit pending until market reaches target price.',
              style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11),
            ),
            if (_side == OrderSide.buy && _selectedMood != null && _selectedMood!.isDumbMoneyState) ...[
              const SizedBox(height: 10),
              Text(
                'Emotional state flagged: ${_selectedMood!.label}. The market will wait. Continue anyway?',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'EXECUTE ${_side.name.toUpperCase()}',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final plan = _side == OrderSide.buy ? _buildPlan() : null;

      if (_orderType == TradingOrderType.market) {
        final result = widget.provider.executeMarketOrder(
          symbol: widget.asset.symbol,
          side: _side,
          quantity: qty,
          currentPriceUSDT: price,
          plan: plan,
          stopPrice: _side == OrderSide.buy ? (_stopPriceValue > 0 ? _stopPriceValue : null) : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? JweTheme.accentTeal : JweTheme.accentRed,
          ),
        );
      } else {
        final result = widget.provider.createLimitOrder(
          symbol: widget.asset.symbol,
          side: _side,
          quantity: qty,
          targetPriceUSDT: price,
          plan: plan,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? JweTheme.accentAmber : JweTheme.accentRed,
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  Widget _buildReviewRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 12)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: isHighlight ? JweTheme.textWhite : JweTheme.textMid,
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Smart Money Protocol: BUY risk plan + gate panels ─────────────

  String _fmtPct(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  Widget _riskRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(String text, {required bool strong}) {
    final color = strong ? JweTheme.accentRed : JweTheme.accentAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRiskPlanPanel(BuildContext context) {
    final riskSettings = widget.provider.riskSettings;
    final suggested = widget.provider.suggestedRiskPercentFor(_ticks);
    const riskChips = [0.25, 0.5, 0.75, 1.0];
    const stopChips = [4.0, 6.0, 8.0, 10.0];
    final overMax = _riskIfStoppedINR > 0 && _riskPercentOfPortfolio > riskSettings.maxRiskPercent + 1e-9;
    final tradesToday = widget.provider.tradesToday;
    final cap = riskSettings.dailyTradeCap;
    final capReached = cap > 0 && tradesToday >= cap;
    final capWarning = cap > 0 && !capReached && tradesToday >= cap - 1;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.accentAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 6),
              Text(
                'DEFENSE FIRST · RISK PLAN',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.asset.isIndianAsset ? 'STOP PRICE (INR)' : 'STOP PRICE (USDT)',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _stopPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
            decoration: InputDecoration(
              prefixText: widget.asset.isIndianAsset ? '₹ ' : '\$ ',
              prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 13),
              filled: true,
              fillColor: JweTheme.panel2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5), borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: stopChips.map((pct) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 26), side: BorderSide(color: JweTheme.border)),
                    onPressed: () => _nudgeStopPercent(pct),
                    child: Text('−${pct.toInt()}%', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'RISK PER IDEA',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Row(
            children: riskChips.map((pct) {
              final isSelected = (_selectedRiskPercent - pct).abs() < 0.001;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _selectedRiskPercent = pct),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? JweTheme.accentAmber.withValues(alpha: 0.18) : JweTheme.panel2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: isSelected ? JweTheme.accentAmber : JweTheme.border),
                      ),
                      child: Center(
                        child: Text(
                          '${_fmtPct(pct)}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: isSelected ? JweTheme.accentAmber : JweTheme.textMid,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (suggested < riskSettings.baseRiskPercent - 0.001) ...[
            const SizedBox(height: 6),
            Text(
              'Drawdown ladder: suggested ${suggested.toStringAsFixed(2)}% (base ${riskSettings.baseRiskPercent.toStringAsFixed(2)}%)',
              style: GoogleFonts.inter(color: JweTheme.accentAmber, fontSize: 9.5),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentAmber, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: _sizeByRisk,
            child: Text('SIZE BY RISK', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: JweTheme.bgCanvas, borderRadius: BorderRadius.circular(6), border: Border.all(color: JweTheme.border.withValues(alpha: 0.6))),
            child: Column(
              children: [
                _riskRow('RISK IF STOPPED', '₹${_riskIfStoppedINR.toStringAsFixed(0)} (${_riskPercentOfPortfolio.toStringAsFixed(2)}% of portfolio)'),
                _riskRow('STOP DISTANCE', '${_stopDistancePercentValue.toStringAsFixed(1)}%'),
                _riskRow('POSITION', '${_positionPercentOfPortfolio.toStringAsFixed(1)}% of portfolio'),
                _riskRow(
                  'RECOVERY IF STOPPED',
                  _recoveryIfStoppedPercent.isInfinite ? '∞' : '+${_recoveryIfStoppedPercent.toStringAsFixed(2)}%',
                  isLast: true,
                ),
              ],
            ),
          ),
          if (overMax) ...[
            const SizedBox(height: 10),
            _warningBanner(
              'RISK ABOVE YOUR MAX (${_riskPercentOfPortfolio.toStringAsFixed(2)}% > ${riskSettings.maxRiskPercent.toStringAsFixed(2)}%)',
              strong: riskSettings.strictRiskGuard,
            ),
          ],
          if (capWarning || capReached) ...[
            const SizedBox(height: 10),
            _warningBanner('MACHINE-GUN GUARD: $tradesToday/$cap buys today', strong: capReached),
          ],
        ],
      ),
    );
  }

  Widget _gateCheckTile(String label, bool value, ValueChanged<bool?>? onChanged, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: JweTheme.accentCyan,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 11, height: 1.2))),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
  }

  Widget _threeSidesField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: JweTheme.textWhite, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
        filled: true,
        fillColor: JweTheme.panel2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5), borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildGatePanel(BuildContext context) {
    final regimeLabel = widget.provider.getMultiTimeframeTelemetry().overallRegimeLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.accentCyan.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 14, color: JweTheme.accentCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SMART MONEY GATE',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
              Text('$_checklistScore/5', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          _gateCheckTile(
            'Best idea available right now — not forcing it',
            _gateBestIdea,
            (v) => setState(() => _gateBestIdea = v ?? false),
          ),
          _gateCheckTile(
            'Early entry: buying the bounce after the dip, not chasing',
            _gateEarly,
            (v) => setState(() => _gateEarly = v ?? false),
          ),
          _gateCheckTile(
            'Aligned with the trend',
            _gateTrend,
            (v) => setState(() => _gateTrend = v ?? false),
            trailing: SmartMoneyTinyChip(label: regimeLabel, color: JweTheme.textMuted),
          ),
          _gateCheckTile('Exit defined: stop + risk budget set', _gateExitDefined, null),
          _gateCheckTile("I can state my edge in one line", _gateEdgeStated, null),
          const SizedBox(height: 8),
          Text('EDGE', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          TextField(
            controller: _edgeController,
            style: GoogleFonts.inter(color: JweTheme.textWhite, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'e.g. Reclaimed the 50DMA on volume',
              hintStyle: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11),
              filled: true,
              fillColor: JweTheme.panel2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5), borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            type: MaterialType.transparency,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'THREE SIDES: ME · CROWD · AGAINST',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                iconColor: JweTheme.accentCyan,
                collapsedIconColor: JweTheme.textMuted,
                children: [
                  _threeSidesField('ME', _meController),
                  const SizedBox(height: 8),
                  _threeSidesField('CROWD', _crowdController),
                  const SizedBox(height: 8),
                  _threeSidesField('AGAINST', _againstController),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('MOOD', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: TraderMood.values.map((mood) {
              final isSelected = _selectedMood == mood;
              return InkWell(
                onTap: () => setState(() => _selectedMood = mood),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? JweTheme.accentCyan.withValues(alpha: 0.18) : JweTheme.panel2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: isSelected ? JweTheme.accentCyan : JweTheme.border),
                  ),
                  child: Text(
                    mood.label,
                    style: GoogleFonts.jetBrainsMono(
                      color: isSelected ? JweTheme.accentCyan : JweTheme.textMid,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedMood != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedMood!.coaching,
              style: GoogleFonts.inter(
                color: _selectedMood!.isDumbMoneyState
                    ? JweTheme.accentAmber
                    : (_selectedMood!.isCaution ? JweTheme.textMid : JweTheme.textMuted),
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellPositionBox(BuildContext context) {
    final holding = widget.provider.getHolding(widget.asset.symbol);
    if (holding == null) return const SizedBox.shrink();

    final currencySymbol = widget.asset.isIndianAsset ? '₹' : '\$';
    final currentPrice = _currentLivePrice;
    final stop = holding.stopPrice;
    final hasStop = stop != null && stop > 0;
    final pnlINR = holding.pnlINR(currentPrice, widget.provider.usdtToInrRate);
    final currentR =
        (holding.plannedRiskINR != null && holding.plannedRiskINR! > 0) ? pnlINR / holding.plannedRiskINR! : null;
    final suggestBreakeven = widget.provider.shouldSuggestBreakeven(holding, currentPrice);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('POSITION', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _riskRow('ENTRY AVG', '$currencySymbol${holding.avgBuyPriceUSDT.toStringAsFixed(2)}'),
          _riskRow('LIVE', '$currencySymbol${currentPrice.toStringAsFixed(2)}'),
          _riskRow('STOP', hasStop ? '$currencySymbol${stop.toStringAsFixed(2)}' : 'NO STOP — DEFENSE OFF'),
          _riskRow(
            'CURRENT R',
            currentR != null ? '${currentR >= 0 ? '+' : ''}${currentR.toStringAsFixed(2)}R' : '—',
            isLast: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StopQuickAction(
                  label: 'RAISE TO B/E',
                  highlighted: suggestBreakeven,
                  onTap: () => _runStopAction(() => widget.provider.raiseStopToBreakeven(widget.asset.symbol)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StopQuickAction(
                  label: 'TRAIL 5%',
                  onTap: () => _runStopAction(() => widget.provider.trailStop(widget.asset.symbol, 5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StopQuickAction(
                  label: 'TRAIL 10%',
                  onTap: () => _runStopAction(() => widget.provider.trailStop(widget.asset.symbol, 10)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StopQuickAction(
                  label: 'EDIT STOP',
                  onTap: () => showEditStopDialog(context, widget.provider, widget.asset.symbol, stop, currencySymbol),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selling a winner early? Let a trailing stop do it for you.',
            style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 9.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  void _runStopAction(TradeExecutionResult Function() action) {
    final result = action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? JweTheme.accentTeal : JweTheme.accentRed),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

    final availableUnits = widget.provider.getAvailableCoinQuantity(widget.asset.symbol);
    final availableCash = widget.provider.availableCash;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(
            color: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed,
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: JweTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Symbol & Live price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(widget.asset.icon, color: widget.asset.brandColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.asset.displaySymbol,
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: JweTheme.panel2,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: JweTheme.border),
                                    ),
                                    child: Text(
                                      widget.asset.exchange,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                widget.asset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: JweTheme.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.asset.isIndianAsset
                        ? inrFormat.format(_currentLivePrice)
                        : '\$${_currentLivePrice.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Side Selector (BUY vs SELL)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _side = OrderSide.buy),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.panel2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'BUY',
                            style: GoogleFonts.jetBrainsMono(
                              color: _side == OrderSide.buy ? Colors.white : JweTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _side = OrderSide.sell),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _side == OrderSide.sell ? JweTheme.accentRed : JweTheme.panel2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _side == OrderSide.sell ? JweTheme.accentRed : JweTheme.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'SELL',
                            style: GoogleFonts.jetBrainsMono(
                              color: _side == OrderSide.sell ? Colors.white : JweTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Order Type Selector (MARKET vs LIMIT)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        'MARKET ORDER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _orderType == TradingOrderType.market,
                      onSelected: (sel) {
                        if (sel) setState(() => _orderType = TradingOrderType.market);
                      },
                      selectedColor: JweTheme.accentCyan.withValues(alpha: 0.2),
                      backgroundColor: JweTheme.panel2,
                      side: BorderSide(
                        color: _orderType == TradingOrderType.market ? JweTheme.accentCyan : JweTheme.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        'LIMIT ORDER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _orderType == TradingOrderType.limit,
                      onSelected: (sel) {
                        if (sel) setState(() => _orderType = TradingOrderType.limit);
                      },
                      selectedColor: JweTheme.accentAmber.withValues(alpha: 0.2),
                      backgroundColor: JweTheme.panel2,
                      side: BorderSide(
                        color: _orderType == TradingOrderType.limit ? JweTheme.accentAmber : JweTheme.border,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Limit Price Input (if Limit order selected)
              if (_orderType == TradingOrderType.limit) ...[
                Text(
                  widget.asset.isIndianAsset ? 'TARGET LIMIT PRICE (INR)' : 'TARGET LIMIT PRICE (USDT)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _limitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
                  onChanged: (_) => _onAmountChanged(_amountController.text),
                  decoration: InputDecoration(
                    prefixText: widget.asset.isIndianAsset ? '₹ ' : '\$ ',
                    prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 13),
                    filled: true,
                    fillColor: JweTheme.panel2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: JweTheme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Nudge chips
                Row(
                  children: [-2.0, -1.0, 1.0, 2.0].map((pct) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 26),
                            side: BorderSide(color: JweTheme.border),
                          ),
                          onPressed: () => _adjustLimitPrice(pct),
                          child: Text(
                            '${pct > 0 ? '+' : ''}${pct.toInt()}%',
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Spend Input (INR)
              Text(
                'AMOUNT TO SPEND (INR)',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 14),
                  hintText: widget.asset.isIndianAsset ? 'e.g. 5000' : 'e.g. 10000',
                  hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: JweTheme.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quantity Input (Coin/Shares)
              Text(
                widget.asset.isIndianAsset
                    ? 'QUANTITY (SHARES - ${widget.asset.baseAsset})'
                    : 'QUANTITY (${widget.asset.baseAsset})',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMid,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !widget.asset.isIndianAsset || widget.asset.decimals > 0,
                ),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
                onChanged: _onQuantityChanged,
                decoration: InputDecoration(
                  suffixText: widget.asset.baseAsset,
                  suffixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: JweTheme.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Percentage Presets (25%, 50%, 75%, 100%)
              Row(
                children: [0.25, 0.50, 0.75, 1.0].map((frac) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => _applyPercentage(frac),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: JweTheme.panel2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: JweTheme.border),
                          ),
                          child: Center(
                            child: Text(
                              '${(frac * 100).toInt()}%',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMid,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Smart Money Protocol: BUY risk plan + gate, or SELL position box
              if (_side == OrderSide.buy) ...[
                _buildRiskPlanPanel(context),
                _buildGatePanel(context),
              ] else
                _buildSellPositionBox(context),

              // Available Balance Reference
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JweTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Cash:', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            inrFormat.format(availableCash),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Position Holding:', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${availableUnits.toStringAsFixed(widget.asset.decimals)} ${widget.asset.baseAsset}',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_side == OrderSide.buy &&
                  !widget.provider.marketService.isRealtimeActive(widget.asset.symbol)) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: JweTheme.accentAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'REALTIME FEED OFFLINE: Buying locked until a fresh live quote is verified.',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Action Button
              ListenableBuilder(
                listenable: widget.provider.marketService,
                builder: (context, _) {
                  final feedOffline = _side == OrderSide.buy &&
                      !widget.provider.marketService.isRealtimeActive(widget.asset.symbol);
                  final guardBlocked = _side == OrderSide.buy &&
                      _orderType == TradingOrderType.market &&
                      (_dailyCapBlocked || _strictRiskBlocked);
                  final isBuyLocked = feedOffline || guardBlocked;

                  final lockLabel = feedOffline
                      ? 'BUYING LOCKED (FEED OFFLINE)'
                      : _dailyCapBlocked
                          ? 'BUYING LOCKED (DAILY CAP)'
                          : _strictRiskBlocked
                              ? 'BUYING LOCKED (RISK GUARD)'
                              : 'REVIEW & PLACE ${_side.name.toUpperCase()} ORDER';

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBuyLocked
                          ? JweTheme.panel2
                          : (_side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed),
                      foregroundColor: isBuyLocked ? JweTheme.textMuted : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isBuyLocked ? BorderSide(color: JweTheme.border) : BorderSide.none,
                      ),
                    ),
                    onPressed: isBuyLocked ? null : _reviewAndConfirm,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isBuyLocked) ...[
                          Icon(Icons.lock_outline_rounded, size: 16, color: JweTheme.textMuted),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          lockLabel,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isBuyLocked ? JweTheme.textMuted : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopQuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _StopQuickAction({required this.label, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? JweTheme.accentAmber : JweTheme.textMid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? JweTheme.accentAmber.withValues(alpha: 0.14) : JweTheme.panel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: highlighted ? JweTheme.accentAmber : JweTheme.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
