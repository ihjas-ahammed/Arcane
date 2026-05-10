import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';

class EditSubtaskDialog extends StatefulWidget {
  final String initialName;

  const EditSubtaskDialog({super.key, required this.initialName});

  @override
  State<EditSubtaskDialog> createState() => _EditSubtaskDialogState();
}

class _EditSubtaskDialogState extends State<EditSubtaskDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("EDIT OBJECTIVE"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "MISSION NAME",
                filled: true,
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL"),
        ),
        ValorantButton(
          label: "UPDATE",
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      Navigator.pop(context, _controller.text.trim());
    }
  }
}