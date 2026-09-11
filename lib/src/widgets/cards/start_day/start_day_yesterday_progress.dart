import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StartDayYesterdayProgress extends StatelessWidget {
  final AppProvider provider;
  final String yesterdayStr;

  const StartDayYesterdayProgress({
    super.key,
    required this.provider,
    required this.yesterdayStr,
  });

  @override
  Widget build(BuildContext context) {
    final yesterdayData = provider.completedByDay[yesterdayStr];
    final completedSubs = yesterdayData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final taskTimes = yesterdayData?['taskTimes'] as Map<dynamic, dynamic>? ?? {};

    final bool hasAnyTime = taskTimes.values.any((v) => (v as num) > 0);

    if (completedSubs.isEmpty && !hasAnyTime) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentCyan),
            const SizedBox(width: 8),
            Icon(MdiIcons.history, size: 11, color: JweTheme.accentCyan),
            const SizedBox(width: 5),
            Text(
              'YESTERDAY\'S TASK PROGRESS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No task activity recorded yesterday.',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    // Prepare active time rows
    final timeRows = <Widget>[];
    taskTimes.forEach((taskId, timeSec) {
      final secs = (timeSec as num).toInt();
      if (secs <= 0) return;
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == taskId.toString());
      if (mainTask == null) return;

      final mins = secs ~/ 60;
      final timeStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m';
      final color = Color(int.parse('0xFF${mainTask.colorHex}'));

      timeRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            children: [
              Container(width: 4, height: 10, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mainTask.name.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: GoogleFonts.robotoMono(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    });

    // Prepare completed subtasks rows
    final subtaskRows = <Widget>[];
    for (final entry in completedSubs) {
      final name = entry['name'] as String? ?? 'Unnamed Objective';
      final parentTaskId = entry['parentTaskId'] as String? ?? '';
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parentTaskId);
      final color = mainTask != null ? Color(int.parse('0xFF${mainTask.colorHex}')) : JweTheme.accentCyan;

      subtaskRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(MdiIcons.checkboxMarkedCircleOutline, size: 13, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    color: JweTheme.textMid,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              if (mainTask != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    mainTask.name.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Icon(MdiIcons.history, size: 11, color: JweTheme.accentCyan),
          const SizedBox(width: 5),
          Text(
            'YESTERDAY\'S TASK PROGRESS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentCyan,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
                  child: Text(
                    'ACTIVE TIME LOGGED',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...timeRows,
                const SizedBox(height: 6),
              ],
              if (timeRows.isNotEmpty && subtaskRows.isNotEmpty)
                Divider(color: JweTheme.lineSoft, height: 1),
              if (subtaskRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
                  child: Text(
                    'COMPLETED OBJECTIVES',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...subtaskRows,
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
