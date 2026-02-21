import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AddSavingsGoalDialog extends StatefulWidget {
  const AddSavingsGoalDialog({super.key});

  @override
  State<AddSavingsGoalDialog> createState() => _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends State<AddSavingsGoalDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("NEW SAVINGS PROTOCOL", style: TextStyle(fontFamily: AppTheme.fontDisplay, color: AppTheme.fhTextPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Goal Name")),
            const SizedBox(height: 16),
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Target Amount", prefixText: "₹ ")),
            const SizedBox(height: 16),
            const Text("TARGET DATE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _targetDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.fhBorderColor)),
                child: Text(DateFormat('MMM dd, yyyy').format(_targetDate), style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple, foregroundColor: Colors.white),
          onPressed: () {
            final amt = double.tryParse(_amountController.text);
            if (amt != null && _nameController.text.isNotEmpty) {
              Provider.of<AppProvider>(context, listen: false).financeActions.addSavingsGoal(_nameController.text.trim(), '', amt, _targetDate, 'target');
              Navigator.pop(context);
            }
          }, 
          child: const Text("INITIALIZE")
        )
      ],
    );
  }
}