import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

// Unified Dialog for Adding/Editing Projects
class AddEditProjectDialog extends StatefulWidget {
  final String mainTaskId;
  final String? projectId; // If null, we are adding. If exists, we are editing.
  final String? initialTitle;
  final String? initialDescription;

  const AddEditProjectDialog({
    super.key,
    required this.mainTaskId,
    this.projectId,
    this.initialTitle,
    this.initialDescription,
  });

  @override
  State<AddEditProjectDialog> createState() => _AddEditProjectDialogState();
}

class _AddEditProjectDialogState extends State<AddEditProjectDialog> {
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
      title: Text(
        widget.projectId == null ? "New Project" : "Edit Project",
        style: TextStyle(color: AppTheme.fhTextPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.projectId == null,
              style: TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                labelText: "Project Title",
                hintText: "e.g., Launch Website",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                labelText: "Description",
                hintText: "Brief objectives...",
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
          child: const Text("Save"),
        )
      ],
    );
  }
}
