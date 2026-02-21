import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class AddSavingsLogDialog extends StatefulWidget {
  final String goalId;
  const AddSavingsLogDialog({super.key, required this.goalId});

  @override
  State<AddSavingsLogDialog> createState() => _AddSavingsLogDialogState();
}

class _AddSavingsLogDialogState extends State<AddSavingsLogDialog> {
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final bal = provider.financeActions.currentBalance;

    return AlertDialog(
      title: const Text("ALLOCATE FUNDS"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Available Balance: ₹${bal.toStringAsFixed(2)}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'RobotoMono'),
            decoration: const InputDecoration(prefixText: "₹ "),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple, foregroundColor: Colors.white),
          onPressed: () {
            final amt = double.tryParse(_amountController.text);
            if (amt != null && amt > 0) {
              if (amt > bal) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient balance.")));
                return;
              }
              provider.financeActions.addSavingsLog(widget.goalId, amt);
              Navigator.pop(context);
            }
          }, 
          child: const Text("CONFIRM")
        )
      ],
    );
  }
}