import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AddSavingsGoalDialog extends StatefulWidget {
  final SavingsGoal? goalToEdit;
  const AddSavingsGoalDialog({super.key, this.goalToEdit});

  @override
  State<AddSavingsGoalDialog> createState() => _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends State<AddSavingsGoalDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _nameController.text = widget.goalToEdit!.name;
      _amountController.text = widget.goalToEdit!.targetAmount.toStringAsFixed(0);
      _targetDate = widget.goalToEdit!.targetDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: Border.all(color: JweTheme.accentAmber, width: 2),
      title: Text(widget.goalToEdit != null ? "EDIT SAVINGS PROTOCOL" : "NEW SAVINGS PROTOCOL", style: TextStyle(color: JweTheme.accentAmber, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, style:  TextStyle(color: JweTheme.textWhite), decoration:  InputDecoration(labelText: "Goal Name", labelStyle: TextStyle(color: JweTheme.textMuted))),
            const SizedBox(height: 16),
            TextField(controller: _amountController, style:  TextStyle(color: JweTheme.textWhite, fontFamily: 'RobotoMono'), keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: "Target Amount", prefixText: "₹ ", labelStyle: TextStyle(color: JweTheme.textMuted))),
            const SizedBox(height: 16),
             Text("TARGET DATE", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, 
                  initialDate: _targetDate, 
                  firstDate: DateTime.now(), 
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: JweTheme.accentAmber,
                        onPrimary: JweTheme.onAccent,
                        surface: JweTheme.bgBase,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: JweTheme.border)),
                child: Text(DateFormat('MMM dd, yyyy').format(_targetDate), style: TextStyle(color: JweTheme.accentAmber, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child:  Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentAmber, foregroundColor: JweTheme.onAccent, shape:  BeveledRectangleBorder()),
          onPressed: () {
            final amt = double.tryParse(_amountController.text);
            if (amt != null && _nameController.text.isNotEmpty) {
              final provider = Provider.of<AppProvider>(context, listen: false);
              if (widget.goalToEdit != null) {
                provider.financeActions.updateSavingsGoal(
                  widget.goalToEdit!.id,
                  _nameController.text.trim(),
                  widget.goalToEdit!.description,
                  amt,
                  _targetDate,
                  widget.goalToEdit!.iconName,
                );
              } else {
                provider.financeActions.addSavingsGoal(_nameController.text.trim(), '', amt, _targetDate, 'target');
              }
              Navigator.pop(context);
            }
          }, 
          child: Text(widget.goalToEdit != null ? "SAVE" : "INITIALIZE", style: const TextStyle(fontWeight: FontWeight.bold))
        )
      ],
    );
  }
}