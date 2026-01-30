import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/wallet_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AddTransactionDialog extends StatefulWidget {
  final TransactionType? initialType;
  final WalletTransaction? transaction;

  const AddTransactionDialog({super.key, this.initialType, this.transaction});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = 'General';
  String _feeling = 'Neutral';
  DateTime _date = DateTime.now();
  bool _isFuture = false;
  
  // Custom Category Handling
  bool _isAddingCategory = false;
  final _newCategoryController = TextEditingController();

  final List<String> _feelings = ['Good', 'Bad', 'Neutral', 'Necessary', 'Regret'];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _noteController.text = widget.transaction!.note;
      _type = widget.transaction!.type;
      _category = widget.transaction!.category;
      _feeling = widget.transaction!.feeling;
      _date = widget.transaction!.date;
      _isFuture = widget.transaction!.isFuture;
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
    }
  }

  void _save() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Save new category if needed
    if (_isAddingCategory && _newCategoryController.text.trim().isNotEmpty) {
      _category = _newCategoryController.text.trim();
      provider.addWalletCategory(_category);
    }

    final t = WalletTransaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      amount: amount,
      type: _type,
      category: _category,
      note: _noteController.text,
      date: _date,
      feeling: _feeling,
      isFuture: _isFuture,
    );

    if (widget.transaction != null) {
      provider.updateWalletTransaction(t);
    } else {
      provider.addWalletTransaction(t);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final categories = List<String>.from(provider.settings.walletCategories);
    if (!categories.contains('General')) categories.add('General');

    return AlertDialog(
      title: Text(widget.transaction == null ? "NEW TRANSACTION" : "EDIT TRANSACTION"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<TransactionType>(
                    title: const Text("Expense"),
                    value: TransactionType.expense,
                    groupValue: _type,
                    onChanged: (val) => setState(() => _type = val!),
                    activeColor: AppTheme.fhAccentRed,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<TransactionType>(
                    title: const Text("Income"),
                    value: TransactionType.income,
                    groupValue: _type,
                    onChanged: (val) => setState(() => _type = val!),
                    activeColor: AppTheme.fhAccentGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: 'RobotoMono', fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: "AMOUNT",
                prefixText: "\$ ",
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isAddingCategory)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: "NEW CATEGORY"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _isAddingCategory = false),
                  )
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: categories.contains(_category) ? _category : categories.first,
                      decoration: const InputDecoration(labelText: "CATEGORY"),
                      dropdownColor: AppTheme.fhBgDark,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: "Add Category",
                    onPressed: () => setState(() => _isAddingCategory = true),
                  )
                ],
              ),
            
            const SizedBox(height: 16),

            if (_type == TransactionType.expense) ...[
              DropdownButtonFormField<String>(
                value: _feeling,
                decoration: const InputDecoration(labelText: "FEELING"),
                dropdownColor: AppTheme.fhBgDark,
                items: _feelings.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => setState(() => _feeling = val!),
              ),
              const SizedBox(height: 16),
            ],

            const Text("NOTES", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _noteController, hint: "Details...", minLines: 2),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Planned / Future"),
              value: _isFuture,
              activeColor: AppTheme.fhAccentPurple,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isFuture = val),
            ),

            if (_isFuture) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(primary: AppTheme.fhAccentTeal, onPrimary: Colors.black, surface: AppTheme.fhBgDeepDark, onSurface: Colors.white),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "DATE"),
                  child: Text(DateFormat('MMM dd, yyyy').format(_date), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ValorantButton(label: "SAVE", onPressed: _save),
      ],
    );
  }
}