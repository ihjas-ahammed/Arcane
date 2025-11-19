// lib/src/widgets/reflection_dialog.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ReflectionDialog extends StatefulWidget {
  const ReflectionDialog({super.key});

  @override
  State<ReflectionDialog> createState() => _ReflectionDialogState();
}

class _ReflectionDialogState extends State<ReflectionDialog> {
  final _triggerController = TextEditingController();
  final _emotionController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgDark,
      title: Row(
        children: [
          Icon(MdiIcons.brain, color: AppTheme.fhAccentPurple),
          const SizedBox(width: 10),
          const Text("Log Reflection"),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _triggerController,
              decoration: InputDecoration(
                labelText: "What happened?",
                hintText: "Describe the event...",
                prefixIcon: Icon(MdiIcons.flashOutline),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emotionController,
              decoration: InputDecoration(
                labelText: "How did you feel?",
                hintText: "Angry, elated, anxious...",
                prefixIcon: Icon(MdiIcons.emoticonOutline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: "Why did you feel that way?",
                hintText: "Root cause analysis...",
                prefixIcon: Icon(MdiIcons.helpCircleOutline),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting 
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text("Analyze & Submit"),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_triggerController.text.isEmpty || _emotionController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final provider = Provider.of<AppProvider>(context, listen: false);
    try {
      await provider.processReflection(
        trigger: _triggerController.text,
        emotion: _emotionController.text,
        reason: _reasonController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Reflection logged! Virtues updated."),
            backgroundColor: AppTheme.fhAccentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.fhAccentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}