import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SessionEditDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const SessionEditDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<SessionEditDialog> {
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStart;
    _endTime = widget.initialEnd;
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.fhAccentTeal,
              onPrimary: AppTheme.fhBgDeepDark,
              surface: AppTheme.fhBgDark,
              onSurface: AppTheme.fhTextPrimary,
            ),
            dialogBackgroundColor: AppTheme.fhBgDark,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final newDt = DateTime(
          initial.year,
          initial.month,
          initial.day,
          picked.hour,
          picked.minute,
        );

        if (isStart) {
          _startTime = newDt;
          // Auto-adjust end if start moves past it
          if (_startTime.isAfter(_endTime)) {
            _endTime = _startTime.add(const Duration(minutes: 15));
          }
        } else {
          _endTime = newDt;
          // Validation: End must be after start
          if (_endTime.isBefore(_startTime)) {
             _startTime = _endTime.subtract(const Duration(minutes: 15));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Edit Time Log", style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeRow("Start", _startTime, () => _pickTime(true)),
          const SizedBox(height: 16),
          _buildTimeRow("End", _endTime, () => _pickTime(false)),
          const SizedBox(height: 16),
          Text(
            "Duration: ${_endTime.difference(_startTime).inMinutes} min",
            style: const TextStyle(color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
          )
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, {'action': 'delete'}),
          style: TextButton.styleFrom(foregroundColor: AppTheme.fhAccentRed),
          child: const Text("Delete"),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'action': 'save',
                  'start': _startTime,
                  'end': _endTime,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
              child: const Text("Save"),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTimeRow(String label, DateTime dt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary)),
            Text(
              DateFormat('hh:mm a').format(dt),
              style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}