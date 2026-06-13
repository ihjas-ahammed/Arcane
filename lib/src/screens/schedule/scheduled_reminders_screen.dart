import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/app_state_models.dart';

/// Single place to see (and manage) everything that has been scheduled to
/// fire a notification: the daily reflection reminder plus all task / planner /
/// custom reminders. Solves "I set a reminder but couldn't tell it was set".
class ScheduledRemindersScreen extends StatelessWidget {
  const ScheduledRemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final s = provider.settings;
    final reminders = List<ScheduledReminder>.from(provider.scheduledReminders)
      ..sort((a, b) {
        final at = a.nextFire;
        final bt = b.nextFire;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text('REMINDERS',
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhAccentTeal,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.fhTextPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.fhAccentTeal,
        icon: const Icon(Icons.add, color: AppTheme.fhBgDeepDark),
        label: Text('CUSTOM',
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhBgDeepDark,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        onPressed: () => _addCustomReminder(context, provider),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            _sectionLabel('SYSTEM'),
            _ReflectionReminderRow(provider: provider, settings: s),
            const SizedBox(height: 16),
            _sectionLabel('SCHEDULED'),
            if (reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(MdiIcons.bellSleepOutline,
                        size: 44, color: AppTheme.fhTextDisabled),
                    const SizedBox(height: 12),
                    Text('NO REMINDERS SET',
                        style: GoogleFonts.rajdhani(
                            color: AppTheme.fhTextDisabled,
                            fontSize: 14,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Add a reminder time on a submission or a planned task,\nor tap CUSTOM below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.fhTextDisabled, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...reminders.map((r) => _ReminderRow(provider: provider, reminder: r)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      );

  Future<void> _addCustomReminder(
      BuildContext context, AppProvider provider) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('NEW REMINDER',
            style: GoogleFonts.rajdhani(
                color: AppTheme.fhAccentTeal,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.fhTextPrimary),
          decoration: const InputDecoration(
            hintText: 'What should I remind you about?',
            hintStyle: TextStyle(color: AppTheme.fhTextDisabled),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.fhBorderColor)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppTheme.fhTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('NEXT',
                  style: TextStyle(color: AppTheme.fhAccentTeal))),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !context.mounted) return;

    final when = await _pickDateTime(context, DateTime.now().add(const Duration(hours: 1)));
    if (when == null) return;

    provider.upsertReminder(ScheduledReminder(
      id: 'custom_${const Uuid().v4()}',
      title: '⏰ $title',
      body: 'Custom reminder',
      type: 'custom',
      repeat: 'once',
      time: when,
    ));
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _ReflectionReminderRow extends StatelessWidget {
  final AppProvider provider;
  final AppSettings settings;
  const _ReflectionReminderRow({required this.provider, required this.settings});

  @override
  Widget build(BuildContext context) {
    final enabled = settings.reflectionReminderEnabled;
    final timeStr = DateFormat('hh:mm a').format(
        DateTime(2000, 1, 1, settings.reflectionReminderHour,
            settings.reflectionReminderMinute));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(left: BorderSide(color: AppTheme.fhAccentGold, width: 3)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.notebookEditOutline,
              color: AppTheme.fhAccentGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Reflection',
                    style: TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text(enabled ? 'Every day · $timeStr' : 'Disabled',
                    style: const TextStyle(
                        color: AppTheme.fhTextSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (enabled)
            TextButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: settings.reflectionReminderHour,
                      minute: settings.reflectionReminderMinute),
                );
                if (picked != null) {
                  provider.setSettings(settings
                    ..reflectionReminderHour = picked.hour
                    ..reflectionReminderMinute = picked.minute);
                  provider.rescheduleReminders();
                }
              },
              child: Text(timeStr,
                  style: const TextStyle(color: AppTheme.fhAccentTeal)),
            ),
          Switch.adaptive(
            value: enabled,
            activeTrackColor: AppTheme.fhAccentGold,
            onChanged: (v) {
              provider.setSettings(settings..reflectionReminderEnabled = v);
              provider.rescheduleReminders();
            },
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final AppProvider provider;
  final ScheduledReminder reminder;
  const _ReminderRow({required this.provider, required this.reminder});

  Color get _typeColor {
    switch (reminder.type) {
      case 'task':
        return AppTheme.fhAccentTeal;
      case 'planner':
        return AppTheme.fhAccentGreen;
      default:
        return AppTheme.fhAccentGold;
    }
  }

  String get _whenLabel {
    final next = reminder.nextFire;
    if (next == null) return 'No time set';
    if (reminder.repeat == 'daily') {
      return 'Every day · ${DateFormat('hh:mm a').format(next)}';
    }
    final stale = next.isBefore(DateTime.now());
    final fmt = DateFormat('MMM d · hh:mm a').format(next);
    return stale ? 'Passed · $fmt' : fmt;
  }

  @override
  Widget build(BuildContext context) {
    final active = reminder.isActive;
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.fhAccentRed.withValues(alpha: 0.8),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteReminder(reminder.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border(
              left: BorderSide(
                  color: active ? _typeColor : AppTheme.fhTextDisabled,
                  width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(reminder.type.toUpperCase(),
                            style: TextStyle(
                                color: _typeColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                      Expanded(
                        child: Text(reminder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_whenLabel,
                      style: TextStyle(
                          color: active
                              ? AppTheme.fhTextSecondary
                              : AppTheme.fhTextDisabled,
                          fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(MdiIcons.clockEditOutline,
                  size: 18, color: AppTheme.fhTextSecondary),
              splashRadius: 18,
              onPressed: () => _editTime(context),
            ),
            Switch.adaptive(
              value: reminder.enabled,
              activeTrackColor: _typeColor,
              onChanged: (v) => provider.setReminderEnabled(reminder.id, v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTime(BuildContext context) async {
    if (reminder.repeat == 'daily') {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
      );
      if (picked != null) {
        provider.upsertReminder(reminder.copyWith(
            hour: picked.hour, minute: picked.minute, enabled: true));
      }
      return;
    }
    final when = await _pickDateTime(
        context, reminder.time ?? DateTime.now().add(const Duration(hours: 1)));
    if (when != null) {
      provider.upsertReminder(reminder.copyWith(time: when, enabled: true));
    }
  }
}
