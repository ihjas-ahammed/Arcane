import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

class AddSleepDialog extends StatefulWidget {
  final String dateStr;
  final bool isNapDefault;
  const AddSleepDialog({super.key, required this.dateStr, this.isNapDefault = false});

  @override
  State<AddSleepDialog> createState() => _AddSleepDialogState();
}

class _AddSleepDialogState extends State<AddSleepDialog> {
  late DateTime _startDate;
  late bool _isNap;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.tryParse(widget.dateStr) ?? DateTime.now();
    _isNap = widget.isNapDefault;
    if (_isNap) {
      final now = TimeOfDay.now();
      _startTime = now;
      _endTime = TimeOfDay(
        hour: (now.hour + (now.minute + 20) ~/ 60) % 24,
        minute: (now.minute + 20) % 60,
      );
    } else {
      _startTime = const TimeOfDay(hour: 23, minute: 0);
      _endTime = const TimeOfDay(hour: 7, minute: 0);
    }
  }

  void _applyPreset(int mins) {
    if (_startTime == null) return;
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
    final end = start.add(Duration(minutes: mins));
    setState(() {
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = _isNap ? JweTheme.accentAmber : JweTheme.accentCyan;

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: activeAccent, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      title: Row(
        children: [
          Icon(
            _isNap ? MdiIcons.batteryChargingOutline : MdiIcons.weatherNight,
            size: 20,
            color: activeAccent,
          ),
          const SizedBox(width: 8),
          Text(
            _isNap ? "LOG POWER NAP" : "LOG SLEEP RECORD",
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Selector
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isNap = false;
                        _startTime = const TimeOfDay(hour: 23, minute: 0);
                        _endTime = const TimeOfDay(hour: 7, minute: 0);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isNap ? JweTheme.accentCyan.withValues(alpha: 0.2) : JweTheme.bgCanvas.withValues(alpha: 0.3),
                        border: Border.all(
                          color: !_isNap ? JweTheme.accentCyan : JweTheme.border,
                          width: !_isNap ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'NIGHT SLEEP',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: !_isNap ? JweTheme.accentCyan : JweTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isNap = true;
                        final current = TimeOfDay.now();
                        _startTime = current;
                        _endTime = TimeOfDay(
                          hour: (current.hour + (current.minute + 20) ~/ 60) % 24,
                          minute: (current.minute + 20) % 60,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isNap ? JweTheme.accentAmber.withValues(alpha: 0.2) : JweTheme.bgCanvas.withValues(alpha: 0.3),
                        border: Border.all(
                          color: _isNap ? JweTheme.accentAmber : JweTheme.border,
                          width: _isNap ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'POWER NAP',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isNap ? JweTheme.accentAmber : JweTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isNap) ...[
              Text(
                'QUICK DURATION PRESETS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JweTheme.accentAmber,
                        side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: const BeveledRectangleBorder(),
                      ),
                      onPressed: () => _applyPreset(20),
                      child: Text('20M (NASA)', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JweTheme.accentAmber,
                        side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: const BeveledRectangleBorder(),
                      ),
                      onPressed: () => _applyPreset(30),
                      child: Text('30M (REST)', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JweTheme.accentAmber,
                        side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: const BeveledRectangleBorder(),
                      ),
                      onPressed: () => _applyPreset(90),
                      child: Text('90M (CYCLE)', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            _buildDatePickerRow("DATE RECORDED", _startDate, (val) => setState(() => _startDate = val), activeAccent),
            const SizedBox(height: 12),
            _buildTimePickerRow(_isNap ? "NAP START" : "BED TIME", _startTime, (val) => setState(() => _startTime = val), activeAccent),
            const SizedBox(height: 12),
            _buildTimePickerRow(_isNap ? "NAP END" : "WAKE TIME", _endTime, (val) => setState(() => _endTime = val), activeAccent),
            if (_startTime != null && _endTime != null) ...[
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);
                if (end.isBefore(start)) end = end.add(const Duration(days: 1));
                final diff = end.difference(start);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: activeAccent.withValues(alpha: 0.1),
                    border: Border.all(color: activeAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isNap ? MdiIcons.batteryChargingOutline : Icons.info_outline,
                        color: activeAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isNap
                              ? "Power Nap • ${diff.inHours > 0 ? '${diff.inHours}h ' : ''}${diff.inMinutes % 60}m duration"
                              : (end.day != start.day
                                  ? "Crosses midnight (${diff.inHours}h ${diff.inMinutes % 60}m)"
                                  : "Same day (${diff.inHours}h ${diff.inMinutes % 60}m)"),
                          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("CANCEL", style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: JweTheme.onAccent,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: (_startTime != null && _endTime != null)
              ? () {
                  final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime!.hour, _startTime!.minute);
                  var end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime!.hour, _endTime!.minute);

                  if (end.isBefore(start)) {
                    end = end.add(const Duration(days: 1));
                  }

                  final targetDate = DateFormat('yyyy-MM-dd').format(_startDate);
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  provider.addSleepLog(
                    targetDate,
                    SleepLog(
                      id: const Uuid().v4(),
                      startTime: start,
                      endTime: end,
                      isNapExplicit: _isNap,
                    ),
                  );

                  Navigator.pop(context);
                }
              : null,
          child: Text(_isNap ? "LOG NAP" : "SAVE", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, Function(DateTime) onSelect, Color accent) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2023),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: JweTheme.pickerScheme(
                accent: accent,
                surface: JweTheme.panel,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: JweTheme.bgCanvas.withValues(alpha: 0.35),
          border: Border.all(color: JweTheme.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(
              DateFormat('MMM dd, yyyy').format(date).toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerRow(String label, TimeOfDay? time, Function(TimeOfDay) onSelect, Color accent) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: JweTheme.pickerScheme(
                accent: accent,
                surface: JweTheme.panel,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: JweTheme.bgCanvas.withValues(alpha: 0.35),
          border: Border.all(color: JweTheme.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(
              time?.format(context) ?? "--:--",
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}