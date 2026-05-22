import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class AddCategoryDialog extends StatefulWidget {
  final bool isIncome;
  const AddCategoryDialog({super.key, required this.isIncome});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameController = TextEditingController();
  final String _colorHex = "00E5FF"; // Cyan default for JWE
  final String _iconName = "circle";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      title: const Text("NEW CATEGORY", style: TextStyle(color: JweTheme.textWhite)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController, 
            style: const TextStyle(color: JweTheme.textWhite),
            decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: JweTheme.textMuted)),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: Colors.black, shape: const BeveledRectangleBorder()),
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Provider.of<AppProvider>(context, listen: false).financeActions.addCategory(_nameController.text.trim(), _colorHex, _iconName, widget.isIncome);
              Navigator.pop(context);
            }
          }, 
          child: const Text("ADD", style: TextStyle(fontWeight: FontWeight.bold))
        )
      ],
    );
  }
}