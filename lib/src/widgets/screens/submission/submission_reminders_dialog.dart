import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class SubmissionRemindersDialog {
  static bool hasReminder(AppProvider provider, SubTask sub) {
    return provider.getSubtaskReminders(sub.id).any((r) => r.isActive);
  }

  static void show(
    BuildContext context,
    AppProvider provider,
    String parentTaskId,
    SubTask sub,
    VoidCallback onStateChanged,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rems = provider.getSubtaskReminders(sub.id);
            return AlertDialog(
              backgroundColor: JweTheme.panel,
              title: Text(
                "MISSION REMINDERS",
                style: GoogleFonts.rajdhani(
                  color: JweTheme.accentCyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No active reminders set.",
                          style: TextStyle(color: JweTheme.textMuted, fontSize: 13),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: rems.length,
                          separatorBuilder: (_, __) => Divider(color: JweTheme.line, height: 1),
                          itemBuilder: (ctx2, i) {
                            final r = rems[i];
                            final displayTime = r.repeat == 'daily'
                                ? DateTime(2000, 1, 1, r.hour, r.minute)
                                : (r.time ?? DateTime(2000, 1, 1, r.hour, r.minute));
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    r.repeat == 'daily'
                                        ? MdiIcons.calendarSync
                                        : MdiIcons.bellOutline,
                                    size: 16,
                                    color: JweTheme.accentAmber,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('hh:mm a').format(displayTime),
                                          style: GoogleFonts.rajdhani(
                                            color: JweTheme.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          r.repeat == 'daily'
                                              ? 'DAILY PROTOCOL'
                                              : (r.time != null ? DateFormat('EEE, MMM d, yyyy').format(r.time!) : 'ONCE'),
                                          style: TextStyle(
                                            color: JweTheme.textMuted,
                                            fontSize: 10,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 18),
                                    onPressed: () {
                                      provider.deleteReminder(r.id);
                                      setDialogState(() {});
                                      onStateChanged();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(MdiIcons.plus, size: 16),
                      label: const Text("ADD REMINDER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JweTheme.accentCyan,
                        foregroundColor: JweTheme.onAccent,
                        shape: const BeveledRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final repeat = await showDialog<String>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            backgroundColor: JweTheme.panel,
                            title: Text("REPEAT OPTION", style: TextStyle(color: JweTheme.textWhite)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text("ONCE", style: TextStyle(color: JweTheme.textWhite)),
                                  onTap: () => Navigator.pop(ctx2, 'once'),
                                ),
                                ListTile(
                                  title: Text("DAILY", style: TextStyle(color: JweTheme.textWhite)),
                                  onTap: () => Navigator.pop(ctx2, 'daily'),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (repeat == null) return;

                        final now = DateTime.now();
                        DateTime date = now;
                        if (repeat == 'once') {
                          if (!ctx.mounted) return;
                          final pickedDate = await showDatePicker(
                            context: ctx,
                            initialDate: now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: JweTheme.accentAmber,
                                  surface: JweTheme.panel,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (pickedDate == null) return;
                          date = pickedDate;
                        }

                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(now),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: JweTheme.accentAmber,
                                surface: JweTheme.panel,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (time == null) return;

                        var scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        if (repeat == 'daily' && scheduled.isBefore(now)) {
                          scheduled = scheduled.add(const Duration(days: 1));
                        }

                        await provider.addSubtaskReminder(parentTaskId, sub.id, scheduled, repeat);
                        setDialogState(() {});
                        onStateChanged();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("CLOSE", style: TextStyle(color: JweTheme.textMuted)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
