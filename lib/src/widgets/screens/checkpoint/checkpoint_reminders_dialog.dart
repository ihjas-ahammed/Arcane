import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class CheckpointRemindersDialog {
  static bool hasReminder(AppProvider provider, SubSubTask cp) {
    return provider.getCheckpointReminders(cp.id).any((r) => r.isActive);
  }

  static void show({
    required BuildContext context,
    required AppProvider provider,
    required String mainTaskId,
    required String parentSubTaskId,
    required SubSubTask checkpoint,
    required VoidCallback onStateChanged,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rems = provider.getCheckpointReminders(checkpoint.id);
            return AlertDialog(
              backgroundColor: JweTheme.panel,
              title: Text(
                "OBJECTIVE REMINDERS",
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No reminders configured.",
                          style: TextStyle(
                            color: JweTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: rems.length,
                          itemBuilder: (context, index) {
                            final r = rems[index];
                            String timeStr = '';
                            if (r.repeat == 'daily') {
                              timeStr =
                                  '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')} (Daily)';
                            } else if (r.time != null) {
                              timeStr =
                                  '${DateFormat('MMM d, HH:mm').format(r.time!)} (Once)';
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: JweTheme.bgCanvas,
                                border: Border.all(color: JweTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(MdiIcons.bellRing,
                                      color: JweTheme.accentCyan, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      timeStr,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textWhite,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      MdiIcons.deleteOutline,
                                      color: JweTheme.accentRed,
                                      size: 18,
                                    ),
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
                            title: Text(
                              "REPEAT OPTION",
                              style: TextStyle(color: JweTheme.textWhite),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text("ONCE",
                                      style:
                                          TextStyle(color: JweTheme.textWhite)),
                                  onTap: () => Navigator.pop(ctx2, 'once'),
                                ),
                                ListTile(
                                  title: Text("DAILY",
                                      style:
                                          TextStyle(color: JweTheme.textWhite)),
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
                                colorScheme: JweTheme.isLight
                                    ? ColorScheme.light(
                                        primary: JweTheme.accentCyan,
                                        surface: JweTheme.panel,
                                      )
                                    : ColorScheme.dark(
                                        primary: JweTheme.accentCyan,
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
                              colorScheme: JweTheme.isLight
                                  ? ColorScheme.light(
                                      primary: JweTheme.accentCyan,
                                      surface: JweTheme.panel,
                                    )
                                  : ColorScheme.dark(
                                      primary: JweTheme.accentCyan,
                                      surface: JweTheme.panel,
                                    ),
                            ),
                            child: child!,
                          ),
                        );
                        if (time == null) return;

                        var scheduled = DateTime(date.year, date.month,
                            date.day, time.hour, time.minute);
                        if (repeat == 'daily' && scheduled.isBefore(now)) {
                          scheduled = scheduled.add(const Duration(days: 1));
                        }

                        await provider.addCheckpointReminder(
                          mainTaskId,
                          parentSubTaskId,
                          checkpoint.id,
                          scheduled,
                          repeat,
                        );
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
                  child:
                      Text("CLOSE", style: TextStyle(color: JweTheme.textMuted)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
