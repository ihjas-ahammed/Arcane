import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/charts/time_pie_chart.dart';

/// Mission Focus body: time donut on the left, per-protocol time list on the right.
/// The list holds up to six rows; any protocols beyond the top five are merged into OTHER.
class MissionFocusBody extends StatelessWidget {
  static const double chartSize = 150;
  static const double rowHeight = 22;
  static const int maxRows = 6;

  final Map<String, double> taskData; // Protocol -> Minutes
  final Map<String, Color> taskColors; // Protocol -> Color
  final String? selectedTask;
  final Function(String?)? onTaskSelected;

  const MissionFocusBody({
    super.key,
    required this.taskData,
    required this.taskColors,
    this.selectedTask,
    this.onTaskSelected,
  });

  @override
  Widget build(BuildContext context) {
    final active = taskData.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (active.isEmpty) {
      return SizedBox(
        height: chartSize,
        child: TimePieChart(
          taskData: const {},
          taskColors: taskColors,
          selectedTask: selectedTask,
          onTaskSelected: onTaskSelected,
        ),
      );
    }

    // Keep at most six rows: top five plus one OTHER row for the rest.
    final rows = <MapEntry<String, double>>[];
    if (active.length > maxRows) {
      rows.addAll(active.take(maxRows - 1));
      final rest = active.skip(maxRows - 1).fold<double>(0, (sum, e) => sum + e.value);
      rows.add(MapEntry('OTHER', rest));
    } else {
      rows.addAll(active);
    }

    final data = {for (final e in rows) e.key: e.value};
    final colors = {
      for (final e in rows) e.key: e.key == 'OTHER' ? JweTheme.textMuted : (taskColors[e.key] ?? JweTheme.accentCyan),
    };

    return SizedBox(
      height: chartSize,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: chartSize,
            height: chartSize,
            child: TimePieChart(
              taskData: data,
              taskColors: colors,
              selectedTask: selectedTask,
              onTaskSelected: onTaskSelected,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: rows.length * rowHeight, color: JweTheme.border),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in rows)
                  _LegendRow(
                    name: e.key,
                    minutes: e.value,
                    color: colors[e.key]!,
                    selected: selectedTask == e.key,
                    onTap: onTaskSelected == null
                        ? null
                        : () => onTaskSelected!(selectedTask == e.key ? null : e.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String name;
  final double minutes;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _LegendRow({
    required this.name,
    required this.minutes,
    required this.color,
    required this.selected,
    this.onTap,
  });

  String _fmt(double m) {
    final total = m.round();
    if (total < 60) return '${total}m';
    final h = total ~/ 60;
    final rem = total % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: MissionFocusBody.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : null,
          border: Border(bottom: BorderSide(color: JweTheme.border, width: 1)),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rajdhani(
                  color: selected ? color : JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(minutes),
              maxLines: 1,
              style: GoogleFonts.robotoMono(
                color: JweTheme.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
