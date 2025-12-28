import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

import 'package:arcane/src/widgets/valorant/valorant_button.dart';

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
      title: const Text("MANUAL LOG"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimePickerRow("START TIME", _startTime,
              (val) => setState(() => _startTime = val)),
          const SizedBox(height: 16),
          _buildTimePickerRow(
              "END TIME", _endTime, (val) => setState(() => _endTime = val)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ValorantButton(
          label: "CONFIRM",
          onPressed: (_startTime != null && _endTime != null)
              ? () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day,
                      _startTime!.hour, _startTime!.minute);
                  var end = DateTime(now.year, now.month, now.day,
                      _endTime!.hour, _endTime!.minute);
                  if (end.isBefore(start))
                    end = end.add(const Duration(days: 1));
                  Navigator.pop(context, {'start': start, 'end': end});
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTimePickerRow(
      String label, TimeOfDay? time, Function(TimeOfDay) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border:
            Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time ?? TimeOfDay.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppTheme.fhAccentTeal,
                      onPrimary: Colors.black,
                      surface: AppTheme.fhBgDeepDark,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onSelect(picked);
            },
            child: Text(
              time?.format(context) ?? "--:--",
              style: const TextStyle(
                  fontFamily: "RobotoMono",
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.fhAccentTeal),
            ),
          ),
        ],
      ),
    );
  }
}
