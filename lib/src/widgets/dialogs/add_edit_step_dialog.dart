import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// Unified Dialog for Adding/Editing Steps
class AddEditStepDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final bool isEditing;

  const AddEditStepDialog({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.isEditing = false,
  });

  @override
  State<AddEditStepDialog> createState() => _AddEditStepDialogState();
}

class _AddEditStepDialogState extends State<AddEditStepDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: Row(
        children: [
          Icon(
            widget.isEditing ? MdiIcons.pencilOutline : MdiIcons.plus,
            color: AppTheme.fhAccentTeal,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isEditing ? "Edit Step" : "Add Step",
            style: TextStyle(color: AppTheme.fhTextPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                labelText: "Step Title",
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                labelText: "Description / Notes (Optional)",
                filled: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text.trim(),
                'desc': _descController.text.trim(),
              });
            }
          },
          child: Text(widget.isEditing ? "Update" : "Add"),
        )
      ],
    );
  }
}
