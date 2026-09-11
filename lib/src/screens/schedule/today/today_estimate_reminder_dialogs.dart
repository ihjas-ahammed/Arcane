import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TodayEstimateReminderDialogs {
  static Future<int?> showEditEstimateDialog(BuildContext context, int currentEstimate) async {
    final controller = TextEditingController(text: currentEstimate.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'ESTIMATE',
            style: GoogleFonts.rajdhani(
              color: JweTheme.accentAmber,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [5, 15, 30, 60, 90].map((preset) {
                  return ChoiceChip(
                    label: Text('${preset}m'),
                    selected: false,
                    backgroundColor: JweTheme.bgCanvas,
                    labelStyle: TextStyle(color: JweTheme.textWhite, fontSize: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    onSelected: (_) => Navigator.pop(ctx, preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: JweTheme.textWhite),
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  labelStyle: TextStyle(color: JweTheme.textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentAmber),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? currentEstimate;
                Navigator.pop(ctx, v.clamp(0, 600));
              },
              child: Text('SET', style: TextStyle(color: JweTheme.accentAmber)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  static Future<void> showEditReminderDialog(
    BuildContext context,
    AppProvider provider,
    String compoundId,
  ) async {
    final existing = provider.plannerReminderTime(compoundId);
    if (existing != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'REMINDER',
            style: GoogleFonts.rajdhani(
              color: JweTheme.accentAmber,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Set for ${DateFormat('MMM d · hh:mm a').format(existing)}.',
            style: TextStyle(color: JweTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: Text('CLEAR', style: TextStyle(color: JweTheme.accentRed)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'change'),
              child: Text('CHANGE', style: TextStyle(color: JweTheme.accentAmber)),
            ),
          ],
        ),
      );
      if (action == 'clear') {
        await provider.setPlannerReminder(compoundId, null);
        return;
      }
      if (action != 'change') return;
    }

    if (!context.mounted) return;

    final parts = compoundId.split('|');
    SubTask? sub;
    if (parts.length >= 2) {
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
      sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    }
    final isRecurring = sub?.isRecurring ?? false;

    final base = existing ?? DateTime.now().add(const Duration(hours: 1));
    DateTime date;
    if (isRecurring) {
      date = DateTime.now();
    } else {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: base,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentAmber, surface: JweTheme.panel),
          ),
          child: child!,
        ),
      );
      if (pickedDate == null || !context.mounted) return;
      date = pickedDate;
    }
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentAmber, surface: JweTheme.panel),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    var when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isRecurring && when.isBefore(DateTime.now())) {
      when = when.add(const Duration(days: 1));
    }
    await provider.setPlannerReminder(compoundId, when);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reminder set for ${DateFormat('MMM d · hh:mm a').format(when)}'),
      backgroundColor: JweTheme.accentTeal.withValues(alpha: 0.9),
    ));
  }
}
