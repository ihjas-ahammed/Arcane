import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:intl/intl.dart';

class AddSessionDialog extends StatefulWidget {
  final DateTime? initialDate;

  const AddSessionDialog({super.key, this.initialDate});

  @override
  State<AddSessionDialog> createState() => _AddSessionDialogState();
}

class _AddSessionDialogState extends State<AddSessionDialog> {
  late DateTime _startDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate ?? DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 1)));
    _startTime = initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("MANUAL LOG"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDatePickerRow("SESSION DATE", _startDate, (val) => setState(() => _startDate = val)),
            const SizedBox(height: 16),
            _buildTimePickerRow("START TIME", _startTime, (val) => setState(() => _startTime = val)),
            const SizedBox(height: 16),
            _buildTimePickerRow("END TIME", _endTime, (val) => setState(() => _endTime = val)),
            if (_startTime != null && _endTime != null) ...[
               const SizedBox(height: 12),
               Builder(builder: (context) {
                  final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);
                  if (end.isBefore(start)) end = end.add(const Duration(days: 1));
                  
                  return Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.fhTextSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        end.day != start.day ? "Ends Next Day" : "Same Day", 
                        style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)
                      )
                    ],
                  );
               })
            ]
          ],
        ),
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
                  final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);
                  
                  // Auto detect crossing midnight
                  if (end.isBefore(start)) {
                      end = end.add(const Duration(days: 1));
                  }
                  
                  Navigator.pop(context, {'start': start, 'end': end});
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, Function(DateTime) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
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
              DateFormat('MMM dd, yyyy').format(date).toUpperCase(),
              style: const TextStyle(
                fontFamily: "RobotoMono",
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: AppTheme.fhAccentTeal
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow(String label, TimeOfDay? time, Function(TimeOfDay) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
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
                color: AppTheme.fhAccentTeal
              ),
            ),
          ),
        ],
      ),
    );
  }
}