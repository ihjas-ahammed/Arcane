import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/dialogs/add_category_dialog.dart';
import 'package:arcane/src/models/finance_models.dart';
import 'package:provider/provider.dart';

class AddTransactionDialog extends StatefulWidget {
  final bool isIncome;
  const AddTransactionDialog({super.key, required this.isIncome});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final categories = provider.categories.where((c) => c.isIncomeCategory == widget.isIncome).toList();
    
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: Border.all(color: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed, width: 2),
      title: Text(widget.isIncome ? "ADD INCOME" : "ADD EXPENSE", style: TextStyle(color: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono', fontSize: 24),
              decoration: const InputDecoration(prefixText: "₹ ", hintText: "0.00", hintStyle: TextStyle(color: JweTheme.textMuted)),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              dropdownColor: JweTheme.bgBase,
              decoration: const InputDecoration(labelText: "CATEGORY", labelStyle: TextStyle(color: JweTheme.textMuted)),
              items: [
                ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: Colors.white)))),
                const DropdownMenuItem(value: 'ADD_NEW', child: Text("+ Add New Category", style: TextStyle(color: JweTheme.accentAmber))),
              ],
              onChanged: (val) {
                if (val == 'ADD_NEW') {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => AddCategoryDialog(isIncome: widget.isIncome)).then((_) {
                  });
                } else {
                  setState(() => _selectedCategoryId = val);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "NOTE (Optional)", labelStyle: TextStyle(color: JweTheme.textMuted)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed, foregroundColor: Colors.black, shape: const BeveledRectangleBorder()),
          onPressed: () {
            final amt = double.tryParse(_amountController.text);
            if (amt != null && amt > 0 && _selectedCategoryId != null) {
              provider.financeActions.addTransaction(amt, widget.isIncome, _selectedCategoryId!, _noteController.text.trim(), DateTime.now());
              Navigator.pop(context);
            }
          },
          child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}