import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';

class InitializeActionPlanDialog extends StatefulWidget {
  const InitializeActionPlanDialog({super.key});

  @override
  State<InitializeActionPlanDialog> createState() => _InitializeActionPlanDialogState();
}

class _InitializeActionPlanDialogState extends State<InitializeActionPlanDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("INITIATE ACTION PLAN"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CODENAME", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _nameController, hint: "Plan Name...", minLines: 1),
            
            const SizedBox(height: 16),
            
            const Text("STRATEGIC INTENT (WHY)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _whyController, hint: "Why is this action required?", minLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ValorantButton(
          label: "INITIALIZE",
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'why': _whyController.text.trim(),
              });
            }
          },
        ),
      ],
    );
  }
}