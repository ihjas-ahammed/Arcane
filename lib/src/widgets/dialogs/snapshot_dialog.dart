import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class SnapshotDialog extends StatefulWidget {
  final int totalSeconds;
  final double progress;
  final String? initialNote;
  final bool isEditing;

  const SnapshotDialog({
    super.key,
    required this.totalSeconds,
    required this.progress,
    this.initialNote,
    this.isEditing = false,
  });

  @override
  State<SnapshotDialog> createState() => _SnapshotDialogState();
}

class _SnapshotDialogState extends State<SnapshotDialog> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: Text(
        widget.isEditing ? "EDIT SNAPSHOT" : "LOG PROGRESS",
        style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat("PROGRESS", "${(widget.progress * 100).toInt()}%"),
                  _buildStat("TIME", helper.formatTime(widget.totalSeconds.toDouble())),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("NOTE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.fhBgDark.withOpacity(0.5),
                hintText: "Optional milestone note...",
                hintStyle: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (widget.isEditing)
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'delete'}),
            child: const Text("DELETE", style: TextStyle(color: AppTheme.fhAccentRed)),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),

        ValorantButton(
          label: "CONFIRM",
          onPressed: () {
            Navigator.pop(context, {
              'action': 'save',
              'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            });
          },
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: AppTheme.fhAccentTeal, fontSize: 16, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)),
      ],
    );
  }
}