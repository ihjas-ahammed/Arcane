import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddSessionDialog extends StatefulWidget {
  const AddSessionDialog({super.key});

  @override
  State<AddSessionDialog> createState() => _AddSessionDialogState();
}

class _AddSessionDialogState extends State<AddSessionDialog> {
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Add Session", style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimePickerRow("Start Time", _startTime, (val) => setState(() => _startTime = val)),
          const SizedBox(height: 16),
          _buildTimePickerRow("End Time", _endTime, (val) => setState(() => _endTime = val)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: (_startTime != null && _endTime != null)
              ? () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);
                  
                  // Handle overnight? Assuming same day for now as per simple log
                  if (end.isBefore(start)) {
                     end = end.add(const Duration(days: 1));
                  }

                  Navigator.pop(context, {'start': start, 'end': end});
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
          child: const Text("Add"),
        ),
      ],
    );
  }

  Widget _buildTimePickerRow(String label, TimeOfDay? time, Function(TimeOfDay) onSelect) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary)),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay.now(),
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
            if (picked != null) onSelect(picked);
          },
          child: Text(
            time?.format(context) ?? "Select",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}