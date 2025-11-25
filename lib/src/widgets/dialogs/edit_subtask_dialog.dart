import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

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
      backgroundColor: AppTheme.fhBgMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text("Edit Sub-Mission",
          style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: false, // Prevents keyboard layout issues on some mobile devices
              style: const TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                labelText: "Mission Name",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fhAccentTeal,
            foregroundColor: AppTheme.fhBgDeepDark,
          ),
          child: const Text("Save"),
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