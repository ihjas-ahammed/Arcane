import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

class AiGenerationPromptDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String actionLabel;

  const AiGenerationPromptDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.actionLabel,
  });

  @override
  State<AiGenerationPromptDialog> createState() => _AiGenerationPromptDialogState();
}

class _AiGenerationPromptDialogState extends State<AiGenerationPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title.toUpperCase(), style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.fhTextPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontSize: 13),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ValorantButton(
          label: widget.actionLabel,
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context, _controller.text);
            }
          },
        ),
      ],
    );
  }
}