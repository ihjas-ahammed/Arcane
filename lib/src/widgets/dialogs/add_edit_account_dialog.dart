import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:provider/provider.dart';

const _kAccountTypes = ['cash', 'wallet', 'gpay', 'bank', 'credit', 'other'];

const _kTypeIcons = {
  'cash': 'cash',
  'wallet': 'wallet',
  'gpay': 'contactless-payment',
  'bank': 'bank',
  'credit': 'credit-card',
  'other': 'circle',
};

const _kColors = ['F1C40F', '00F59B', '5DADE2', 'FF4655', '8A2BE2', 'FFFFFF'];

class AddEditAccountDialog extends StatefulWidget {
  final FinanceAccount? existing;
  const AddEditAccountDialog({super.key, this.existing});

  @override
  State<AddEditAccountDialog> createState() => _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends State<AddEditAccountDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _type = 'wallet';
  String _colorHex = 'F1C40F';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.existing!.name;
      _balanceController.text = widget.existing!.balance.toStringAsFixed(2);
      _type = widget.existing!.type;
      _colorHex = widget.existing!.colorHex;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentAmber, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        _isEditing ? 'EDIT ACCOUNT' : 'NEW ACCOUNT',
        style: GoogleFonts.saira(
          color: JweTheme.accentAmber,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          fontSize: 14,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ACCOUNT NAME',
                labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'BALANCE',
                labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
            Text('TYPE',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.6)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kAccountTypes.map((t) {
                final selected = t == _type;
                return GestureDetector(
                  onTap: () => setState(() {
                    _type = t;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? JweTheme.accentAmber.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(
                        color: selected ? JweTheme.accentAmber : JweTheme.lineSoft,
                      ),
                    ),
                    child: Text(
                      t.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: selected ? JweTheme.accentAmber : JweTheme.textMuted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('COLOR',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.6)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kColors.map((hex) {
                final color = Color(int.parse('0xFF$hex'));
                final selected = hex == _colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: Colors.black,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final name = _nameController.text.trim();
            final balance = double.tryParse(_balanceController.text) ?? 0.0;
            if (name.isEmpty) return;
            final iconName = _kTypeIcons[_type] ?? 'wallet';
            if (_isEditing) {
              provider.financeActions.changeAccountBalance(widget.existing!.id, balance);
              provider.financeActions.updateAccount(
                widget.existing!.id,
                name: name,
                type: _type,
                iconName: iconName,
                colorHex: _colorHex,
              );
            } else {
              provider.financeActions.addAccount(name, _type, balance, iconName, _colorHex);
            }
            Navigator.pop(context);
          },
          child: Text(_isEditing ? 'SAVE' : 'ADD',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
