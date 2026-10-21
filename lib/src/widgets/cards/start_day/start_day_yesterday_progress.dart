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
    final subtasksRaw = yesterdayData?['subtasksCompleted'];
    final completedSubs = subtasksRaw is List ? subtasksRaw : const [];
    final checkpointsRaw = yesterdayData?['checkpointsCompleted'];
    final completedCheckpoints = checkpointsRaw is List ? checkpointsRaw : const [];
    final taskTimesRaw = yesterdayData?['taskTimes'];
    final taskTimes = taskTimesRaw is Map ? taskTimesRaw : const {};

    final bool hasAnyTime = taskTimes.values.any((v) => v is num && v > 0);

    if (completedSubs.isEmpty && completedCheckpoints.isEmpty && !hasAnyTime) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'YESTERDAY\'S TASK PROGRESS'),
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

    // Inactive or deleted tasks and subtasks keep their old history entries, but they
    // should not appear in daily progress.
    bool isLiveTask(String id) {
      final t = provider.mainTasks.firstWhereOrNull((t) => t.id == id);
      return t == null || (t.isActive && !t.isDeleted);
    }

    bool isLiveSubtask(String id) {
      if (id.isEmpty) return true;
      final s = provider.mainTasks
          .expand((t) => t.subTasks)
          .firstWhereOrNull((s) => s.id == id);
      return s == null || (s.isActive && !s.isDeleted);
    }

    // Active time rows
    final timeRows = <Widget>[];
    taskTimes.forEach((taskId, timeSec) {
      final secs = timeSec is num ? timeSec.toInt() : 0;
      if (secs <= 0) return;
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == taskId.toString());
      if (mainTask == null || !isLiveTask(mainTask.id)) return;

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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

    // Completed objectives
    final subtaskRows = <Widget>[];
    for (final entry in completedSubs) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString() ?? entry['subtaskName']?.toString() ?? 'Unnamed Objective';
      final parentTaskId = entry['parentTaskId']?.toString() ?? entry['taskId']?.toString() ?? '';
      final subtaskId = entry['subtaskId']?.toString() ?? entry['parentSubTaskId']?.toString() ?? '';
      if (!isLiveTask(parentTaskId) || !isLiveSubtask(subtaskId)) continue;
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parentTaskId);
      final color = mainTask != null ? Color(int.parse('0xFF${mainTask.colorHex}')) : JweTheme.accentCyan;

      subtaskRows.add(_EntryRow(
        icon: MdiIcons.checkboxMarkedCircleOutline,
        color: color,
        title: name,
        tag: mainTask?.name,
      ));
    }

    // Completed checkpoints
    final checkpointRows = <Widget>[];
    for (final entry in completedCheckpoints) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString() ?? 'Checkpoint';
      final parentTaskId = entry['parentTaskId']?.toString() ?? entry['taskId']?.toString() ?? '';
      final parentSubtaskId = entry['parentSubTaskId']?.toString() ?? entry['subtaskId']?.toString() ?? '';
      final parentSubtaskName = entry['parentSubtaskName']?.toString() ?? '';
      if (!isLiveTask(parentTaskId) || !isLiveSubtask(parentSubtaskId)) continue;
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parentTaskId);
      final color = mainTask != null ? Color(int.parse('0xFF${mainTask.colorHex}')) : JweTheme.accentCyan;

      checkpointRows.add(_EntryRow(
        icon: MdiIcons.rhombusOutline,
        color: color,
        title: name,
        detail: parentSubtaskName,
        tag: mainTask?.name,
        isCheckpoint: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'YESTERDAY\'S TASK PROGRESS'),
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
                _GroupLabel(label: 'ACTIVE TIME LOGGED'),
                ...timeRows,
                const SizedBox(height: 6),
              ],
              if (timeRows.isNotEmpty && (subtaskRows.isNotEmpty || checkpointRows.isNotEmpty))
                Divider(color: JweTheme.lineSoft, height: 1),
              if (subtaskRows.isNotEmpty) ...[
                _GroupLabel(label: 'COMPLETED OBJECTIVES'),
                ...subtaskRows,
                const SizedBox(height: 10),
              ],
              if (subtaskRows.isNotEmpty && checkpointRows.isNotEmpty)
                Divider(color: JweTheme.lineSoft, height: 1),
              if (checkpointRows.isNotEmpty) ...[
                _GroupLabel(label: 'COMPLETED CHECKPOINTS'),
                ...checkpointRows,
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 10, color: JweTheme.accentCyan),
      const SizedBox(width: 8),
      Icon(MdiIcons.history, size: 11, color: JweTheme.accentCyan),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentCyan,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ),
    ]);
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: JweTheme.textMuted,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// One completed objective or checkpoint. The title takes the full row width.
/// Detail and tag wrap onto their own line, so a long name never gets squeezed.
class _EntryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
  final String? tag;
  final bool isCheckpoint;

  const _EntryRow({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    this.tag,
    this.isCheckpoint = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDetail = detail != null && detail!.isNotEmpty;
    final hasTag = tag != null && tag!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCheckpoint ? 4 : 5, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: isCheckpoint ? 12 : 13, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: JweTheme.textMid,
                    fontSize: isCheckpoint ? 11.5 : 12,
                    height: 1.3,
                  ),
                ),
                if (hasDetail || hasTag) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (hasDetail)
                        Text(
                          detail!,
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      if (hasTag)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            tag!.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
