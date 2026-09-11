import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/schedule/scheduled_reminders_screen.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class NotificationsSettingsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const NotificationsSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  String _fmtTime(int h, int m) {
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickTime(
    BuildContext ctx,
    int curH,
    int curM,
    void Function(int, int) onPick,
  ) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay(hour: curH, minute: curM),
    );
    if (picked != null) onPick(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final s = appProvider.settings;
    final accent =
        appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(MdiIcons.bellOutline, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Notifications',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
            Divider(
              height: 24,
              thickness: 0.5,
              color: AppTheme.fhBorderColor.withValues(alpha: 0.5),
            ),

            // --- Reflection reminder ---
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Reflection Reminder',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.reflectionReminderEnabled
                          ? 'Fires every day at ${_fmtTime(s.reflectionReminderHour, s.reflectionReminderMinute)}'
                          : 'Disabled',
                      style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: s.reflectionReminderEnabled,
                activeTrackColor: accent,
                onChanged: (v) {
                  appProvider.setSettings(s..reflectionReminderEnabled = v);
                  appProvider.rescheduleReminders();
                },
              ),
            ]),
            if (s.reflectionReminderEnabled) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) => OutlinedButton.icon(
                  icon: Icon(MdiIcons.clockOutline, size: 16),
                  label: Text(
                    'Change Time — ${_fmtTime(s.reflectionReminderHour, s.reflectionReminderMinute)}',
                  ),
                  onPressed: () => _pickTime(
                    ctx,
                    s.reflectionReminderHour,
                    s.reflectionReminderMinute,
                    (h, m) {
                      appProvider.setSettings(
                        s
                          ..reflectionReminderHour = h
                          ..reflectionReminderMinute = m,
                      );
                      appProvider.rescheduleReminders();
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: AppTheme.fhBorderColor),
            const SizedBox(height: 16),

            // --- Finance data reminder ---
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Finance Update Reminder',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.financeReminderEnabled
                          ? 'Fires every day at ${_fmtTime(s.financeReminderHour, s.financeReminderMinute)}'
                          : 'Disabled',
                      style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: s.financeReminderEnabled,
                activeTrackColor: accent,
                onChanged: (v) {
                  appProvider.setSettings(s..financeReminderEnabled = v);
                  appProvider.rescheduleReminders();
                },
              ),
            ]),
            if (s.financeReminderEnabled) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) => OutlinedButton.icon(
                  icon: Icon(MdiIcons.clockOutline, size: 16),
                  label: Text(
                    'Change Time — ${_fmtTime(s.financeReminderHour, s.financeReminderMinute)}',
                  ),
                  onPressed: () => _pickTime(
                    ctx,
                    s.financeReminderHour,
                    s.financeReminderMinute,
                    (h, m) {
                      appProvider.setSettings(
                        s
                          ..financeReminderHour = h
                          ..financeReminderMinute = m,
                      );
                      appProvider.rescheduleReminders();
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: AppTheme.fhBorderColor),
            const SizedBox(height: 16),

            // --- Health data reminder ---
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Health Update Reminder',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.healthReminderEnabled
                          ? 'Fires every day at ${_fmtTime(s.healthReminderHour, s.healthReminderMinute)}'
                          : 'Disabled',
                      style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: s.healthReminderEnabled,
                activeTrackColor: accent,
                onChanged: (v) {
                  appProvider.setSettings(s..healthReminderEnabled = v);
                  appProvider.rescheduleReminders();
                },
              ),
            ]),
            if (s.healthReminderEnabled) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) => OutlinedButton.icon(
                  icon: Icon(MdiIcons.clockOutline, size: 16),
                  label: Text(
                    'Change Time — ${_fmtTime(s.healthReminderHour, s.healthReminderMinute)}',
                  ),
                  onPressed: () => _pickTime(
                    ctx,
                    s.healthReminderHour,
                    s.healthReminderMinute,
                    (h, m) {
                      appProvider.setSettings(
                        s
                          ..healthReminderHour = h
                          ..healthReminderMinute = m,
                      );
                      appProvider.rescheduleReminders();
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: AppTheme.fhBorderColor),
            const SizedBox(height: 16),

            // --- Energy Check Reminders ---
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Energy Reminders',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.energyNotificationsEnabled
                          ? '${s.energyNotificationTimes.length} reminders scheduled daily'
                          : 'Disabled',
                      style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: s.energyNotificationsEnabled,
                activeTrackColor: accent,
                onChanged: (v) {
                  appProvider.setSettings(s..energyNotificationsEnabled = v);
                  appProvider.rescheduleReminders();
                },
              ),
            ]),
            if (s.energyNotificationsEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(text: s.energyNotificationTitle)
                  ..selection = TextSelection.collapsed(
                    offset: s.energyNotificationTitle.length,
                  ),
                style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  labelStyle: TextStyle(color: accent, fontSize: 11),
                  filled: true,
                  fillColor: JweTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: JweTheme.lineSoft),
                  ),
                ),
                onChanged: (val) {
                  appProvider.setSettings(s..energyNotificationTitle = val);
                  appProvider.rescheduleReminders();
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: s.energyNotificationBody)
                  ..selection = TextSelection.collapsed(
                    offset: s.energyNotificationBody.length,
                  ),
                style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notification Text / Body',
                  labelStyle: TextStyle(color: accent, fontSize: 11),
                  filled: true,
                  fillColor: JweTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: JweTheme.lineSoft),
                  ),
                ),
                onChanged: (val) {
                  appProvider.setSettings(s..energyNotificationBody = val);
                  appProvider.rescheduleReminders();
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: JweTheme.isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: JweTheme.lineSoft),
                ),
                child: Row(
                  children: [
                    Icon(Icons.watch_outlined, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct inline reply & Wearable auto-reply active ("yes" / "no" / voice). Replies are processed by AI with automatic feedback notifications.',
                        style: TextStyle(
                          fontSize: 11,
                          color: JweTheme.textMid,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'DAILY REMINDER TIMINGS (${s.energyNotificationTimes.length} Active)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: JweTheme.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < s.energyNotificationTimes.length; i++)
                    Builder(
                      builder: (ctx) {
                        final timeStr = s.energyNotificationTimes[i];
                        return Chip(
                          backgroundColor: JweTheme.bgCanvas,
                          side: BorderSide(color: accent.withValues(alpha: 0.5)),
                          avatar: Icon(
                            MdiIcons.clockOutline,
                            size: 14,
                            color: accent,
                          ),
                          label: Text(
                            timeStr,
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textWhite,
                              fontSize: 12,
                            ),
                          ),
                          onDeleted: s.energyNotificationTimes.length > 1
                              ? () {
                                  final updatedTimes = List<String>.from(
                                    s.energyNotificationTimes,
                                  )..removeAt(i);
                                  appProvider.setSettings(
                                    s..energyNotificationTimes = updatedTimes,
                                  );
                                  appProvider.rescheduleReminders();
                                }
                              : null,
                          deleteIconColor: AppTheme.fhAccentRed,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) => OutlinedButton.icon(
                  icon: Icon(MdiIcons.plus, size: 16),
                  label: const Text('ADD REMINDER TIME'),
                  onPressed: () => _pickTime(ctx, 12, 0, (h, m) {
                    final timeStr =
                        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                    if (!s.energyNotificationTimes.contains(timeStr)) {
                      final updatedTimes = List<String>.from(
                        s.energyNotificationTimes,
                      )..add(timeStr);
                      updatedTimes.sort();
                      appProvider.setSettings(
                        s..energyNotificationTimes = updatedTimes,
                      );
                      appProvider.rescheduleReminders();
                    }
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: AppTheme.fhBorderColor),
            const SizedBox(height: 16),

            // --- Manage all scheduled reminders ---
            Builder(
              builder: (ctx) => OutlinedButton.icon(
                icon: Icon(MdiIcons.bellCogOutline, size: 16),
                label: const Text('View & Edit Scheduled Reminders'),
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ScheduledRemindersScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                MdiIcons.bellCheckOutline,
                color: AppTheme.fhTextSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Set per-submission reminders by tapping the bell icon on any submission detail screen, or per-task times in the Today planner.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.fhTextSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
