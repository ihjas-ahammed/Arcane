import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TradingOrderSheet extends StatefulWidget {
  final CryptoSymbol symbol;
  final PaperTradingProvider provider;
  final OrderSide initialSide;

  const TradingOrderSheet({
    super.key,
    required this.symbol,
    required this.provider,
    this.initialSide = OrderSide.buy,
  });

  static Future<void> show({
    required BuildContext context,
    required CryptoSymbol symbol,
    required PaperTradingProvider provider,
    OrderSide initialSide = OrderSide.buy,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TradingOrderSheet(
        symbol: symbol,
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

  bool _isEditingQuantity = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;

    final tick = widget.provider.marketService.getTick(widget.symbol.rawSymbol);
    final initialPrice = tick?.price ?? 1000.0;
    _limitPriceController.text = initialPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _quantityController.dispose();
    _limitPriceController.dispose();
    super.dispose();
  }

  double get _effectivePriceUSDT {
    if (_orderType == TradingOrderType.limit) {
      return double.tryParse(_limitPriceController.text) ?? _currentLivePriceUSDT;
    }
    return _currentLivePriceUSDT;
  }

  double get _currentLivePriceUSDT {
    final tick = widget.provider.marketService.getTick(widget.symbol.rawSymbol);
    return tick?.price ?? 0.0;
  }

  double get _priceInINR => _effectivePriceUSDT * widget.provider.usdtToInrRate;

  void _onAmountChanged(String val) {
    if (_isEditingQuantity) return;
    final inr = double.tryParse(val) ?? 0.0;
    if (_priceInINR > 0) {
      final qty = inr / _priceInINR;
      _quantityController.text = qty.toStringAsFixed(widget.symbol.decimals);
    } else {
      _quantityController.text = '0';
    }
    setState(() {});
  }

  void _onQuantityChanged(String val) {
    _isEditingQuantity = true;
    final qty = double.tryParse(val) ?? 0.0;
    final inr = qty * _priceInINR;
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
      final availableCoins = widget.provider.getAvailableCoinQuantity(widget.symbol.rawSymbol);
      final targetQty = availableCoins * fraction;
      _quantityController.text = targetQty.toStringAsFixed(widget.symbol.decimals);
      _onQuantityChanged(_quantityController.text);
    }
  }

  void _adjustLimitPrice(double percentChange) {
    final current = double.tryParse(_limitPriceController.text) ?? _currentLivePriceUSDT;
    final updated = current * (1.0 + (percentChange / 100.0));
    _limitPriceController.text = updated.toStringAsFixed(2);
    _onAmountChanged(_amountController.text);
  }

  Future<void> _reviewAndConfirm() async {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final priceUSDT = _effectivePriceUSDT;
    final totalINR = qty * priceUSDT * widget.provider.usdtToInrRate;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity or spend amount.')),
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
      final availableQty = widget.provider.getAvailableCoinQuantity(widget.symbol.rawSymbol);
      if (qty > availableQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient coin balance. Available: ${availableQty.toStringAsFixed(4)} ${widget.symbol.baseAsset}')),
        );
        return;
      }
    }

    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

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
            _buildReviewRow('Asset', widget.symbol.pairLabel),
            _buildReviewRow('Quantity', '${qty.toStringAsFixed(widget.symbol.decimals)} ${widget.symbol.baseAsset}'),
            _buildReviewRow('Unit Price', '\$${priceUSDT.toStringAsFixed(2)} (~${inrFormat.format(priceUSDT * widget.provider.usdtToInrRate)})'),
            const Divider(height: 16),
            _buildReviewRow('Estimated Total', '${inrFormat.format(totalINR)} (\$${(totalINR / widget.provider.usdtToInrRate).toStringAsFixed(2)})', isHighlight: true),
            const SizedBox(height: 10),
            Text(
              _orderType == TradingOrderType.market
                  ? 'Fills immediately with simulated market liquidity.'
                  : 'Order will sit pending until live market reaches target price.',
              style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11),
            ),
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
      if (_orderType == TradingOrderType.market) {
        final result = widget.provider.executeMarketOrder(
          symbol: widget.symbol.rawSymbol,
          side: _side,
          quantity: qty,
          currentPriceUSDT: priceUSDT,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? JweTheme.accentTeal : JweTheme.accentRed,
          ),
        );
      } else {
        final result = widget.provider.createLimitOrder(
          symbol: widget.symbol.rawSymbol,
          side: _side,
          quantity: qty,
          targetPriceUSDT: priceUSDT,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final inrFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    final availableCoins = widget.provider.getAvailableCoinQuantity(widget.symbol.rawSymbol);
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
                  Row(
                    children: [
                      Icon(widget.symbol.icon, color: widget.symbol.brandColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        widget.symbol.pairLabel,
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${_currentLivePriceUSDT.toStringAsFixed(2)}',
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
                  'TARGET LIMIT PRICE (USDT)',
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
                    prefixText: '\$ ',
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
                  hintText: 'e.g. 10000',
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

              // Quantity Input (Coin)
              Text(
                'QUANTITY (${widget.symbol.baseAsset})',
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
                onChanged: _onQuantityChanged,
                decoration: InputDecoration(
                  suffixText: widget.symbol.baseAsset,
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
                        Text(inrFormat.format(availableCash), style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Holding Balance:', style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11)),
                        Text('${availableCoins.toStringAsFixed(4)} ${widget.symbol.baseAsset}', style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _side == OrderSide.buy ? JweTheme.accentTeal : JweTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _reviewAndConfirm,
                child: Text(
                  'REVIEW & PLACE ${_side.name.toUpperCase()} ORDER',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
