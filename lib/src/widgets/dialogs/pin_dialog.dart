import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

class PinDialog extends StatefulWidget {
  final bool isSetupMode;
  final String? expectedPin;

  const PinDialog({
    super.key,
    required this.isSetupMode,
    this.expectedPin,
  });

  /// Shows the dialog and returns the new PIN if setup mode, or boolean if verification.
  static Future<dynamic> show({
    required BuildContext context,
    required bool isSetupMode,
    String? expectedPin,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(
        isSetupMode: isSetupMode,
        expectedPin: expectedPin,
      ),
    );
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = '');
    final pin = _pinController.text;

    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }

    if (widget.isSetupMode) {
      final confirm = _confirmController.text;
      if (pin != confirm) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
      Navigator.pop(context, pin); // Return new pin
    } else {
      if (pin == widget.expectedPin) {
        Navigator.pop(context, true); // Authorized
      } else {
        setState(() {
          _error = 'INCORRECT PIN.';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgDeepDark,
      title: Text(
        widget.isSetupMode ? "SETUP SECURITY PIN" : "AUTH REQUIRED",
        style: const TextStyle(
          color: AppTheme.fhTextPrimary, 
          fontFamily: AppTheme.fontDisplay, 
          letterSpacing: 1.5
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isSetupMode 
                ? "This PIN protects your Reflection Logs and Nora AI." 
                : "Enter your classified access PIN.",
              style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: AppTheme.fhAccentTeal, fontSize: 24, letterSpacing: 8.0, fontFamily: 'RobotoMono'),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.fhBgDark,
                hintText: "****",
                hintStyle: TextStyle(color: AppTheme.fhTextDisabled.withOpacity(0.5)),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => !widget.isSetupMode ? _submit() : null,
              autofocus: true,
            ),
            if (widget.isSetupMode) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: const TextStyle(color: AppTheme.fhAccentTeal, fontSize: 24, letterSpacing: 8.0, fontFamily: 'RobotoMono'),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.fhBgDark,
                  hintText: "CONFIRM",
                  hintStyle: TextStyle(color: AppTheme.fhTextDisabled.withOpacity(0.5), fontSize: 12, letterSpacing: 2.0),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(_error, style: const TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, widget.isSetupMode ? null : false), 
          child: const Text("CANCEL")
        ),
        ValorantButton(
          label: widget.isSetupMode ? "SET PIN" : "ACCESS",
          onPressed: _submit,
        )
      ],
    );
  }
}