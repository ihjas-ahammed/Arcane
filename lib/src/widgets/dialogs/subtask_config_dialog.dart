import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';

class SubtaskConfigDialog extends StatefulWidget {
  final String initialName;
  final String initialDescription;
  final bool isRecurring;
  final bool isActive;

  const SubtaskConfigDialog({
    super.key,
    required this.initialName,
    this.initialDescription = '',
    this.isRecurring = false,
    this.isActive = true,
  });

  @override
  State<SubtaskConfigDialog> createState() => _SubtaskConfigDialogState();
}

class _SubtaskConfigDialogState extends State<SubtaskConfigDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late bool _isRecurring;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDescription);
    _isRecurring = widget.isRecurring;
    _isActive = widget.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("CONFIGURE OBJECTIVE"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("NAME", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _nameController, hint: "Objective title...", minLines: 1),
            
            const SizedBox(height: 16),
            
            const Text("BRIEFING", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _descController, hint: "Description and notes...", minLines: 3),
            
            const SizedBox(height: 24),
            
            SwitchListTile(
              title: const Text("ACTIVE STATUS", style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Suspend this objective temporarily", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
              value: _isActive,
              activeThumbColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            
            SwitchListTile(
              title: const Text("RECURRING PROTOCOL", style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Resets daily at 00:00", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
              value: _isRecurring,
              activeThumbColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isRecurring = val),
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
          label: "UPDATE",
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'description': _descController.text.trim(),
                'isRecurring': _isRecurring,
                'isActive': _isActive,
              });
            }
          },
        ),
      ],
    );
  }
}