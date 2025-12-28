import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';

class LinkSubmissionDialog extends StatefulWidget {
  final String initialName;
  final List<SubTask> availableSubmissions;

  const LinkSubmissionDialog({
    super.key,
    required this.initialName,
    required this.availableSubmissions,
  });

  @override
  State<LinkSubmissionDialog> createState() => _LinkSubmissionDialogState();
}

class _LinkSubmissionDialogState extends State<LinkSubmissionDialog> {
  final _nameController = TextEditingController();
  String _type = 'submission'; // 'submission' or 'checkpoint'
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    if (widget.availableSubmissions.isNotEmpty) {
      _selectedParentId = widget.availableSubmissions.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no submissions exist, force "submission" type or handle gracefully
    // But logically, if we select 'checkpoint', we MUST have a parent.
    final canBeCheckpoint = widget.availableSubmissions.isNotEmpty;

    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Link to Submission",
          style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: AppTheme.fhTextSecondary),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.fhBorderColor)),
              ),
              style: const TextStyle(color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 16),
            const Text("Type:",
                style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontWeight: FontWeight.bold)),
            Row(
              children: [
                Radio<String>(
                  value: 'submission',
                  groupValue: _type,
                  onChanged: (val) => setState(() => _type = val!),
                  activeColor: AppTheme.fhAccentTeal,
                ),
                const Text("Task",
                    style: TextStyle(color: AppTheme.fhTextPrimary)),
                if (canBeCheckpoint) ...[
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'checkpoint',
                    groupValue: _type,
                    onChanged: (val) => setState(() => _type = val!),
                    activeColor: AppTheme.fhAccentTeal,
                  ),
                  const Text("Step",
                      style: TextStyle(color: AppTheme.fhTextPrimary)),
                ],
              ],
            ),
            if (_type == 'checkpoint' && canBeCheckpoint) ...[
              const SizedBox(height: 16),
              const Text("Parent Sub-Mission:",
                  style: TextStyle(
                      color: AppTheme.fhTextSecondary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedParentId,
                dropdownColor: AppTheme.fhBgDeepDark,
                isExpanded: true,
                style: const TextStyle(color: AppTheme.fhTextPrimary),
                items: widget.availableSubmissions.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub.id,
                    child: Text(sub.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedParentId = val);
                },
              ),
            ] else if (_type == 'checkpoint' && !canBeCheckpoint) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "No Sub-Missions available to add a checkpoint to. Please create a Sub-Mission first.",
                  style: TextStyle(color: AppTheme.fhAccentRed, fontSize: 12),
                ),
              )
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;

            final result = {
              'name': _nameController.text.trim(),
              'type': _type,
            };

            if (_type == 'checkpoint') {
              if (_selectedParentId == null && canBeCheckpoint) {
                // Should select a parent
                _selectedParentId = widget.availableSubmissions.first.id;
              }

              if (_selectedParentId != null) {
                result['parentId'] = _selectedParentId!;
              } else {
                // Cannot proceed as checkpoint without parent
                return;
              }
            }

            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fhAccentTeal,
            foregroundColor: AppTheme.fhBgDeepDark,
          ),
          child: const Text("Create Link"),
        ),
      ],
    );
  }
}
