import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.fhAccentTeal, onPrimary: Colors.black, surface: AppTheme.fhBgDeepDark, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        final newDt = DateTime(initial.year, initial.month, initial.day, picked.hour, picked.minute);
        if (isStart) {
          _startTime = newDt;
          if (_startTime.isAfter(_endTime)) _endTime = _startTime.add(const Duration(minutes: 15));
        } else {
          _endTime = newDt;
          if (_endTime.isBefore(_startTime)) _startTime = _endTime.subtract(const Duration(minutes: 15));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("ADJUST LOG"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeRow("START", _startTime, () => _pickTime(true)),
          const SizedBox(height: 12),
          _buildTimeRow("END", _endTime, () => _pickTime(false)),
          const SizedBox(height: 16),
          Text("DURATION: ${_endTime.difference(_startTime).inMinutes} MIN", style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, {'action': 'delete'}),
          style: TextButton.styleFrom(foregroundColor: AppTheme.fhAccentRed),
          child: const Text("DELETE"),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            const SizedBox(width: 8),
            ValorantButton(
              label: "SAVE",
              onPressed: () {
                Navigator.pop(context, {
                  'action': 'save',
                  'start': _startTime,
                  'end': _endTime,
                });
              },
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTimeRow(String label, DateTime dt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        color: AppTheme.fhBgDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
            Text(DateFormat('HH:mm').format(dt), style: const TextStyle(color: Colors.white, fontFamily: "RobotoMono", fontSize: 16)),
          ],
        ),
      ),
    );
  }
}