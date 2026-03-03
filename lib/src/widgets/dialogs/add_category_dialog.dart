import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class AddCategoryDialog extends StatefulWidget {
  final bool isIncome;
  const AddCategoryDialog({super.key, required this.isIncome});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameController = TextEditingController();
  final String _colorHex = "00F59B";
  final String _iconName = "circle";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("NEW CATEGORY"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Name")),
          // Simplicity: hardcode some values or use simple inputs for color/icon here.
          // For brevity, skipping full color picker logic inside this sub-dialog.
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Provider.of<AppProvider>(context, listen: false).financeActions.addCategory(_nameController.text.trim(), _colorHex, _iconName, widget.isIncome);
              Navigator.pop(context);
            }
          }, 
          child: const Text("ADD")
        )
      ],
    );
  }
}