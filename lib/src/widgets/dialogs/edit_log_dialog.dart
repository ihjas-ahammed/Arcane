// lib/src/widgets/dialogs/edit_log_dialog.dart
import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EditLogDialog extends StatefulWidget {
  final String title;
  final dynamic initialValue; // int for Energy, Map for Reflection
  final String logType; // 'reflection' (Energy removed)
  final Function(dynamic) onSave;
  final Function() onDelete;

  const EditLogDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.logType,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<EditLogDialog> {
  final _triggerController = TextEditingController();
  final _emotionController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.logType == 'reflection') {
      final data = widget.initialValue as Map<String, String>;
      _triggerController.text = data['trigger'] ?? '';
      _emotionController.text = data['emotion'] ?? '';
      _reasonController.text = data['reason'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: Row(
        children: [
         Icon(MdiIcons.pencilOutline, color: AppTheme.fhAccentTeal),
          const SizedBox(width: 10),
          Text(widget.title, style: const TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.logType == 'reflection') ...[
              TextField(controller: _triggerController, decoration: const InputDecoration(labelText: 'Trigger')),
              const SizedBox(height: 8),
              TextField(controller: _emotionController, decoration: const InputDecoration(labelText: 'Emotion')),
              const SizedBox(height: 8),
              TextField(controller: _reasonController, decoration: const InputDecoration(labelText: 'Reason')),
            ]
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          icon:  Icon(MdiIcons.deleteForever, size: 18),
          label: const Text("DELETE", style: TextStyle(color: AppTheme.fhAccentRed)),
          onPressed: () async {
             final confirm = await showDialog<bool>(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text("Delete Log?"),
                 content: const Text("This action cannot be undone."),
                 actions: [
                   TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("Cancel")),
                   ElevatedButton(onPressed: ()=>Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed), child: const Text("Confirm")),
                 ],
               )
             );
             if (confirm == true) {
               widget.onDelete();
               if (mounted) Navigator.pop(context);
             }
          },
          style: TextButton.styleFrom(foregroundColor: AppTheme.fhAccentRed),
        ),
        Row(
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (widget.logType == 'reflection') {
                  widget.onSave({
                    'trigger': _triggerController.text,
                    'emotion': _emotionController.text,
                    'reason': _reasonController.text
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        )
      ],
    );
  }
}