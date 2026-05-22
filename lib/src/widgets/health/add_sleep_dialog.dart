import 'package:flutter/material.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class AddSleepDialog extends StatefulWidget {
  final String dateStr;
  const AddSleepDialog({super.key, required this.dateStr});

  @override
  State<AddSleepDialog> createState() => _AddSleepDialogState();
}

class _AddSleepDialogState extends State<AddSleepDialog> {
  late DateTime _startDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    // Default to the currently selected date in the dashboard
    _startDate = DateTime.tryParse(widget.dateStr) ?? DateTime.now();
    // Default sleep range guess
    _startTime = const TimeOfDay(hour: 23, minute: 0);
    _endTime = const TimeOfDay(hour: 7, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpideyTheme.bgPanel,
      title: Text(
        "LOG SLEEP RECORD", 
        style: GoogleFonts.rajdhani(color: SpideyTheme.spideyCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5)
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDatePickerRow("DATE RECORDED", _startDate, (val) => setState(() => _startDate = val)),
            const SizedBox(height: 16),
            _buildTimePickerRow("BED TIME", _startTime, (val) => setState(() => _startTime = val)),
            const SizedBox(height: 16),
            _buildTimePickerRow("WAKE TIME", _endTime, (val) => setState(() => _endTime = val)),
            if (_startTime != null && _endTime != null) ...[
               const SizedBox(height: 16),
               Builder(builder: (context) {
                  final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);
                  if (end.isBefore(start)) end = end.add(const Duration(days: 1));
                  final diff = end.difference(start);
                  
                  return Row(
                    children: [
                      const Icon(Icons.info_outline, color: SpideyTheme.textMuted, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        end.day != start.day 
                          ? "Crosses midnight (${diff.inHours}h ${diff.inMinutes % 60}m)" 
                          : "Same day (${diff.inHours}h ${diff.inMinutes % 60}m)", 
                        style: const TextStyle(color: SpideyTheme.textMuted, fontSize: 12)
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
          child: const Text("CANCEL", style: TextStyle(color: SpideyTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: SpideyTheme.spideyCyan, foregroundColor: Colors.black),
          onPressed: (_startTime != null && _endTime != null)
              ? () {
                  final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);
                  
                  if (end.isBefore(start)) {
                      end = end.add(const Duration(days: 1));
                  }
                  
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  provider.addSleepLog(widget.dateStr, SleepLog(
                    id: const Uuid().v4(),
                    startTime: start,
                    endTime: end,
                  ));
                  
                  Navigator.pop(context);
                }
              : null,
          child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, Function(DateTime) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: SpideyTheme.bgElevated,
        border: Border.all(color: SpideyTheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: SpideyTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: SpideyTheme.spideyCyan,
                      onPrimary: Colors.black,
                      surface: SpideyTheme.bgPanel,
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
                color: SpideyTheme.spideyCyan
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
        color: SpideyTheme.bgElevated,
        border: Border.all(color: SpideyTheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: SpideyTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time ?? TimeOfDay.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: SpideyTheme.spideyCyan,
                      onPrimary: Colors.black,
                      surface: SpideyTheme.bgPanel,
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
                color: SpideyTheme.spideyCyan
              ),
            ),
          ),
        ],
      ),
    );
  }
}