import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TaskProgressSnapshotView extends StatelessWidget {
  final Map<String, dynamic> taskSnapshot;
  final List<MainTask> liveTasks;

  const TaskProgressSnapshotView({
    super.key,
    required this.taskSnapshot,
    required this.liveTasks,
  });

  @override
  Widget build(BuildContext context) {
    if (taskSnapshot.isEmpty) return const SizedBox.shrink();

    // Build delta rows sorted by subtask
    final rows = <_SubTaskDeltaRow>[];
    for (final task in liveTasks) {
      if (task.isDeleted || !task.isActive) continue;
      final snap = taskSnapshot[task.id] as Map<String, dynamic>?;
      if (snap == null) continue;
      final snapSubs = snap['subtasks'] as Map<String, dynamic>? ?? {};

      for (final sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;
        if (sub.completed && !sub.isRecurring) continue; // Neglect archived subtasks

        double snapProgress = 0.0;
        int snapTime = 0;
        final snapSub = snapSubs[sub.id] as Map<String, dynamic>?;
        if (snapSub != null) {
          snapProgress = (snapSub['progress'] as num? ?? 0.0).toDouble();
          snapTime = (snapSub['time_spent'] as int? ?? 0);
        }

        double liveProgress = sub.calculateProgress();
        int liveTime = sub.currentTimeSpent;

        final checkables = sub.subSubTasks.where((sst) => sst.type != 'info').toList();
        int subCount = checkables.length;
        int completedCount = checkables.where((sst) => sst.completed).length;

        if (subCount == 0) {
          subCount = 1;
          completedCount = sub.completed ? 1 : 0;
        }

        final delta = (liveProgress - snapProgress).clamp(-1.0, 1.0);
        final timeDeltaSec = liveTime - snapTime;
        final color = Color(int.parse('0xFF${task.colorHex}'));

        if (delta == 0.0) continue; // Hide subtasks with 0% delta

        rows.add(_SubTaskDeltaRow(
          name: sub.name,
          parentTaskName: task.name,
          color: color,
          liveProgress: liveProgress,
          delta: delta,
          timeDeltaSec: timeDeltaSec,
          completedCount: completedCount,
          subCount: subCount,
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Icon(MdiIcons.progressCheck, size: 11, color: JweTheme.accentCyan),
          const SizedBox(width: 5),
          Text(
            'TASK PROGRESS SINCE STARTUP',
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
            children: List.generate(rows.length, (i) {
              final r = rows[i];
              return _ProgressRow(
                row: r,
                showDivider: i < rows.length - 1,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SubTaskDeltaRow {
  final String name;
  final String parentTaskName;
  final Color color;
  final double liveProgress;
  final double delta;
  final int timeDeltaSec;
  final int completedCount;
  final int subCount;

  _SubTaskDeltaRow({
    required this.name,
    required this.parentTaskName,
    required this.color,
    required this.liveProgress,
    required this.delta,
    required this.timeDeltaSec,
    required this.completedCount,
    required this.subCount,
  });
}

class _ProgressRow extends StatelessWidget {
  final _SubTaskDeltaRow row;
  final bool showDivider;

  const _ProgressRow({required this.row, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final deltaColor = row.delta > 0
        ? JweTheme.accentTeal
        : row.delta < 0
            ? JweTheme.accentRed
            : JweTheme.textMuted;
    final deltaStr = row.delta > 0
        ? '+${(row.delta * 100).round()}%'
        : row.delta < 0
            ? '${(row.delta * 100).round()}%'
            : '–';
    final timeMin = (row.timeDeltaSec / 60).round();
    final timeStr = timeMin > 0 ? '+${timeMin}m' : timeMin < 0 ? '${timeMin}m' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: JweTheme.lineSoft))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: row.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                row.name.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.saira(
                  color: JweTheme.textWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (deltaStr != '–')
              Text(deltaStr,
                  style: GoogleFonts.jetBrainsMono(
                    color: deltaColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  )),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(timeStr,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 9,
                  )),
            ],
          ]),
          const SizedBox(height: 5),
          HudProgressBar(
            value: (row.liveProgress * 100).clamp(0, 100),
            tone: row.liveProgress >= 1.0
                ? HudTone.teal
                : row.delta > 0
                    ? HudTone.cyan
                    : HudTone.amber,
            segments: 24,
            height: 4,
            showLabel: false,
          ),
          const SizedBox(height: 3),
          Text(
            '${row.completedCount}/${row.subCount} steps · ${(row.liveProgress * 100).round()}%',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
