import 'package:missions/src/models/task_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:provider/provider.dart';

class CreateTimeLogStartDialog extends StatefulWidget {
  const CreateTimeLogStartDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CreateTimeLogStartDialog(),
    );
  }

  @override
  State<CreateTimeLogStartDialog> createState() => _CreateTimeLogStartDialogState();
}

class _CreateTimeLogStartDialogState extends State<CreateTimeLogStartDialog> {
  final Set<String> _selectedSubtaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    final todayStr = getTodayDateString();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Auto-detect subtasks worked on or checked today
    for (final task in provider.mainTasks) {
      if (task.isDeleted || !task.isActive) continue;
      for (final sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;

        bool hasActivityToday = false;

        if (sub.completedDate == todayStr) {
          hasActivityToday = true;
        } else if (sub.lastCompletedDate != null &&
            sub.lastCompletedDate!.year == now.year &&
            sub.lastCompletedDate!.month == now.month &&
            sub.lastCompletedDate!.day == now.day) {
          hasActivityToday = true;
        } else if (sub.sessions.any((s) => s.startTime.isAfter(startOfToday))) {
          hasActivityToday = true;
        } else if (sub.subSubTasks.any((sst) =>
            sst.completionTimestamp != null && sst.completionTimestamp!.startsWith(todayStr))) {
          hasActivityToday = true;
        }

        if (hasActivityToday) {
          _selectedSubtaskIds.add(sub.id);
        }
      }
    }
  }

  void _onConfirm() {
    final provider = context.read<AppProvider>();
    provider.createTimeLogStartForToday(checkedSubtaskIds: _selectedSubtaskIds);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Today's time log baseline initialized (${_selectedSubtaskIds.length} tasks registered).",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Icon(MdiIcons.clockStart, color: JweTheme.accentAmber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CREATE TIME LOG START",
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "Calibrate Today's Task Progress Baseline",
                  style: TextStyle(
                    color: JweTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JweTheme.accentAmber.withValues(alpha: 0.08),
                border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Select which tasks or subtasks you worked on or checked today. Arcane will set their baseline to the start of today so your newday task progress reflects everything accomplished today.",
                style: TextStyle(color: JweTheme.textWhite, fontSize: 11.5, height: 1.35),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_selectedSubtaskIds.length} TASKS SELECTED",
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedSubtaskIds.isNotEmpty) {
                        _selectedSubtaskIds.clear();
                      } else {
                        for (var t in provider.mainTasks) {
                          if (t.isDeleted || !t.isActive) continue;
                          for (var s in t.subTasks) {
                            if (s.isPickable) _selectedSubtaskIds.add(s.id);
                          }
                        }
                      }
                    });
                  },
                  child: Text(
                    _selectedSubtaskIds.isNotEmpty ? "CLEAR ALL" : "SELECT ALL",
                    style: TextStyle(color: JweTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.mainTasks.where((t) => !t.isDeleted && t.isActive).length,
                itemBuilder: (context, i) {
                  final activeTasks = provider.mainTasks.where((t) => !t.isDeleted && t.isActive).toList();
                  final task = activeTasks[i];
                  final subtasks = task.subTasks.where((s) => s.isPickable).toList();
                  if (subtasks.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, color: task.taskColor),
                            const SizedBox(width: 6),
                            Text(
                              task.name.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...subtasks.map((sub) {
                        final isChecked = _selectedSubtaskIds.contains(sub.id);
                        final progressPct = (sub.calculateProgress() * 100).toInt();
                        final mins = (sub.currentTimeSpent / 60).toInt();

                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: JweTheme.accentCyan,
                          checkColor: JweTheme.onAccent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          dense: true,
                          title: Text(
                            sub.name,
                            style: TextStyle(
                              color: JweTheme.textWhite,
                              fontSize: 13,
                              fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            "$progressPct% completed · ${mins}m spent",
                            style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSubtaskIds.add(sub.id);
                              } else {
                                _selectedSubtaskIds.remove(sub.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentCyan,
            foregroundColor: JweTheme.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _onConfirm,
          child: Text(
            "INITIALIZE TODAY'S PROGRESS",
            style: GoogleFonts.rajdhani(
              color: JweTheme.onAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
