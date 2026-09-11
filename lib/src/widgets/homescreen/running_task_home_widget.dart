import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'running_task_checkable_list.dart';
import 'running_task_multitask_widget.dart';
import 'running_task_single_widget.dart';

class RunningTaskHomeWidget extends StatelessWidget {
  final bool hasTask;
  final String title;
  final String subtitle;
  final bool isRunning;
  final bool isCheckpoint;
  final int accumulatedSeconds;
  final double progress; // 0..1 — mirrors the missions screen subtask progress
  final bool isPhoenix; // Deprecated - Phoenix protocol removed
  final String capacity; // e.g. "2h40 / 4h30"; empty hides the readout
  final bool dayPlannerWidgetCheckable;
  final List<ResolvedDayPlanItem> topFiveTasks;
  final List<ResolvedDayPlanItem> multitaskTasks;

  static Color get _neonCyan => JweTheme.isLight ? JweTheme.accentCyan : const Color(0xFF00F0FF);
  static Color get _neonRed => JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B);
  static Color get _textMuted => JweTheme.textMuted;

  const RunningTaskHomeWidget({
    super.key,
    required this.hasTask,
    required this.title,
    required this.subtitle,
    required this.isRunning,
    required this.isCheckpoint,
    required this.accumulatedSeconds,
    this.progress = 0.0,
    this.isPhoenix = false,
    this.capacity = '',
    this.dayPlannerWidgetCheckable = false,
    this.topFiveTasks = const [],
    this.multitaskTasks = const [],
  });

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan || c == _neonCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed || c == _neonRed) return HudTone.red;
    return HudTone.amber;
  }

  String _ringLabel(double sec) {
    final s = sec.floor();
    if (s < 3600) {
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$m:$ss';
    }
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    if (dayPlannerWidgetCheckable) {
      return RunningTaskCheckableList(
        topFiveTasks: topFiveTasks,
        capacity: capacity,
        neonCyan: _neonCyan,
        textMuted: _textMuted,
      );
    }

    if (multitaskTasks.length > 1) {
      return RunningTaskMultitaskWidget(
        multitaskTasks: multitaskTasks,
        isRunning: isRunning,
        capacity: capacity,
        neonCyan: _neonCyan,
        neonRed: _neonRed,
        toneFor: _toneFor,
      );
    }

    return RunningTaskSingleWidget(
      hasTask: hasTask,
      isCheckpoint: isCheckpoint,
      isRunning: isRunning,
      accumulatedSeconds: accumulatedSeconds,
      title: title,
      subtitle: subtitle,
      capacity: capacity,
      neonCyan: _neonCyan,
      neonRed: _neonRed,
      toneFor: _toneFor,
      ringLabel: _ringLabel,
    );
  }
}
