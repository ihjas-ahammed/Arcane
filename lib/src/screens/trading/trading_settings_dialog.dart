import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TradingSettingsDialog extends StatefulWidget {
  final PaperTradingProvider provider;

  const TradingSettingsDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, PaperTradingProvider provider) {
    return showDialog(
      context: context,
      builder: (_) => TradingSettingsDialog(provider: provider),
    );
  }

  @override
  State<TradingSettingsDialog> createState() => _TradingSettingsDialogState();
}

class _TradingSettingsDialogState extends State<TradingSettingsDialog> {
  late TextEditingController _balanceController;
  late TextEditingController _rateController;

  // ── Smart Money Protocol: risk rules ──────────────────────────────
  late double _baseRiskPercent;
  late double _maxRiskPercent;
  late bool _strictRiskGuard;
  late TextEditingController _defaultStopController;
  late TextEditingController _dailyCapController;
  late bool _requireChecklist;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.provider.cashBalance.toStringAsFixed(0),
    );
    _rateController = TextEditingController(
      text: widget.provider.usdtToInrRate.toStringAsFixed(2),
    );

    final riskSettings = widget.provider.riskSettings;
    _baseRiskPercent = riskSettings.baseRiskPercent;
    _maxRiskPercent = riskSettings.maxRiskPercent;
    _strictRiskGuard = riskSettings.strictRiskGuard;
    _defaultStopController = TextEditingController(text: riskSettings.defaultStopPercent.toStringAsFixed(1));
    _dailyCapController = TextEditingController(text: riskSettings.dailyTradeCap.toString());
    _requireChecklist = riskSettings.requireChecklist;
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _rateController.dispose();
    _defaultStopController.dispose();
    _dailyCapController.dispose();
    super.dispose();
  }

  void _applyPreset(double amount) {
    setState(() {
      _balanceController.text = amount.toStringAsFixed(0);
    });
  }

  String _fmtRiskPct(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentCyan, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Icon(Icons.tune_rounded, color: JweTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'SIMULATION PARAMETERS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Configure your virtual paper balance and currency exchange rate.',
              style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11.5, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Cash Balance Field
            Text(
              'VIRTUAL STARTING CASH (INR)',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 14),
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

            // Quick preset chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [50000.0, 100000.0, 500000.0, 1000000.0].map((preset) {
                return InkWell(
                  onTap: () => _applyPreset(preset),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JweTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: JweTheme.border),
                    ),
                    child: Text(
                      currencyFormatter.format(preset),
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMid,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // USDT/INR Exchange Rate
            Text(
              'USDT TO INR CONVERSION RATE (1 USDT = ₹)',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                prefixText: '1 USDT = ₹ ',
                prefixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 13),
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
            const SizedBox(height: 20),

            // Smart Money Protocol: risk rules
            Container(
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
                        'RISK RULES',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BASE RISK % PER IDEA',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0.25, 0.5, 0.75, 1.0, 2.0].map((pct) {
                      final isSelected = (_baseRiskPercent - pct).abs() < 0.001;
                      return _RiskChoiceChip(
                        label: '${_fmtRiskPct(pct)}%',
                        selected: isSelected,
                        onTap: () => setState(() => _baseRiskPercent = pct),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MAX RISK % (STRICT GUARD THRESHOLD)',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0.5, 1.0, 2.0, 5.0].map((pct) {
                      final isSelected = (_maxRiskPercent - pct).abs() < 0.001;
                      return _RiskChoiceChip(
                        label: '${_fmtRiskPct(pct)}%',
                        selected: isSelected,
                        onTap: () => setState(() => _maxRiskPercent = pct),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      value: _strictRiskGuard,
                      onChanged: (v) => setState(() => _strictRiskGuard = v),
                      activeThumbColor: JweTheme.accentAmber,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Strict risk guard (refuse buys above max)',
                        style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 11.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DEFAULT STOP %',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _defaultStopController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12.5),
                              decoration: InputDecoration(
                                suffixText: '%',
                                suffixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                                filled: true,
                                fillColor: JweTheme.panel2,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5), borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAILY TRADE CAP (0 = OFF)',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _dailyCapController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12.5),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: JweTheme.panel2,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border), borderRadius: BorderRadius.circular(6)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5), borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      value: _requireChecklist,
                      onChanged: (v) => setState(() => _requireChecklist = v),
                      activeThumbColor: JweTheme.accentAmber,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Require the gate (≥3/5 checks) to buy',
                        style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reset Portfolio Button
            OutlinedButton.icon(
              icon: Icon(Icons.restart_alt_rounded, color: JweTheme.accentRed, size: 16),
              label: Text(
                'RESET PORTFOLIO & WIPED HISTORY',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentRed,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: JweTheme.panel,
                    title: Text(
                      'RESET SIMULATION?',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 13),
                    ),
                    content: Text(
                      'This will clear all active holdings, pending orders, and order history, resetting cash balance to default ₹1,00,000.',
                      style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('RESET', style: GoogleFonts.jetBrainsMono(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await widget.provider.resetPortfolio();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentCyan,
            foregroundColor: JweTheme.isLight ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () async {
            final parsedBalance = double.tryParse(_balanceController.text.replaceAll(',', ''));
            final parsedRate = double.tryParse(_rateController.text);

            if (parsedBalance != null && parsedBalance >= 0) {
              await widget.provider.setCashBalance(parsedBalance);
            }
            if (parsedRate != null && parsedRate > 0) {
              await widget.provider.setUsdtToInrRate(parsedRate);
            }

            final parsedDefaultStop = double.tryParse(_defaultStopController.text);
            final parsedDailyCap = int.tryParse(_dailyCapController.text);
            await widget.provider.updateRiskSettings(
              widget.provider.riskSettings.copyWith(
                baseRiskPercent: _baseRiskPercent,
                maxRiskPercent: _maxRiskPercent,
                strictRiskGuard: _strictRiskGuard,
                defaultStopPercent: (parsedDefaultStop != null && parsedDefaultStop > 0)
                    ? parsedDefaultStop
                    : null,
                dailyTradeCap: (parsedDailyCap != null && parsedDailyCap >= 0) ? parsedDailyCap : null,
                requireChecklist: _requireChecklist,
              ),
            );

            if (context.mounted) Navigator.pop(context);
          },
          child: Text(
            'SAVE PARAMETERS',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _RiskChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RiskChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? JweTheme.accentAmber.withValues(alpha: 0.18) : JweTheme.panel2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: selected ? JweTheme.accentAmber : JweTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: selected ? JweTheme.accentAmber : JweTheme.textMid,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
