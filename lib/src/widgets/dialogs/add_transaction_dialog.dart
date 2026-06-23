import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/dialogs/add_category_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_edit_account_dialog.dart';
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
  String? _selectedAccountId;

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
    final accounts = provider.accounts;

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: Border.all(color: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed, width: 2),
      title: Text(
        widget.isIncome ? "ADD INCOME" : "ADD EXPENSE",
        style: TextStyle(
          color: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono', fontSize: 24),
              decoration: const InputDecoration(
                prefixText: "₹ ",
                hintText: "0.00",
                hintStyle: TextStyle(color: JweTheme.textMuted),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              dropdownColor: JweTheme.bgBase,
              decoration: const InputDecoration(
                labelText: "CATEGORY",
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
              items: [
                ...categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, style: const TextStyle(color: Colors.white)),
                    )),
                 DropdownMenuItem(
                  value: 'ADD_NEW',
                  child: Text("+ Add New Category", style: TextStyle(color: JweTheme.accentAmber)),
                ),
              ],
              onChanged: (val) {
                if (val == 'ADD_NEW') {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AddCategoryDialog(isIncome: widget.isIncome),
                  );
                } else {
                  setState(() => _selectedCategoryId = val);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              dropdownColor: JweTheme.bgBase,
              decoration: const InputDecoration(
                labelText: "ACCOUNT",
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
              items: [
                ...accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, style: const TextStyle(color: Colors.white)),
                    )),
                DropdownMenuItem(
                  value: 'ADD_NEW_ACCOUNT',
                  child: Text("+ Add New Account", style: TextStyle(color: JweTheme.accentAmber)),
                ),
              ],
              onChanged: (val) {
                if (val == 'ADD_NEW_ACCOUNT') {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => const AddEditAccountDialog(),
                  );
                } else {
                  setState(() => _selectedAccountId = val);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "NOTE (Optional)",
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isIncome ? JweTheme.accentCyan : JweTheme.accentRed,
            foregroundColor: Colors.black,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final amt = double.tryParse(_amountController.text);
            if (amt == null || amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid amount')),
              );
              return;
            }
            if (_selectedCategoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a category')),
              );
              return;
            }
            if (_selectedAccountId == null || _selectedAccountId == 'ADD_NEW_ACCOUNT') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select an account')),
              );
              return;
            }

            provider.financeActions.addTransaction(
              amt,
              widget.isIncome,
              _selectedCategoryId!,
              _noteController.text.trim(),
              DateTime.now(),
              accountId: _selectedAccountId,
            );
            Navigator.pop(context);
          },
          child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
