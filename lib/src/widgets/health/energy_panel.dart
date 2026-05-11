import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/widgets/health/spidey_panel.dart';

class EnergyPanel extends StatelessWidget {
  final String dateStr;
  const EnergyPanel({super.key, required this.dateStr});

  void _showLogDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => _EnergyLogDialog(dateStr: dateStr, provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);
    final entries = List<EnergyLog>.from(log.energyLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final avg = entries.isEmpty
        ? 0.0
        : entries.fold<int>(0, (s, e) => s + e.level) / entries.length;
    final latest = entries.isNotEmpty ? entries.last.level : null;

    return SpideyPanel(
      title: "ENERGY LOG",
      accentColor: SpideyTheme.spideyCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("LATEST",
                      style: GoogleFonts.rajdhani(
                          color: SpideyTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  Text(latest == null ? "—" : "$latest / 10",
                      style: GoogleFonts.rajdhani(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: latest == null
                              ? SpideyTheme.textGrey
                              : _levelColor(latest.toDouble()))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("DAY AVG",
                      style: GoogleFonts.rajdhani(
                          color: SpideyTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  Text(entries.isEmpty ? "—" : avg.toStringAsFixed(1),
                      style: GoogleFonts.rajdhani(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: SpideyTheme.spideyCyan)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 160,
            child: entries.isEmpty
                ? const Center(
                    child: Text("No energy logs for this cycle. Tap LOG ENERGY.",
                        style: TextStyle(color: SpideyTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                  )
                : _EnergyChart(entries: entries),
          ),

          const SizedBox(height: 12),

          if (entries.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entries.map((e) {
                final c = _levelColor(e.level.toDouble());
                return InkWell(
                  onLongPress: () => provider.deleteEnergyLog(dateStr, e.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.08),
                      border: Border.all(color: c.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${e.level}",
                            style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'RobotoMono')),
                        const SizedBox(width: 6),
                        Text(DateFormat('HH:mm').format(e.timestamp),
                            style: const TextStyle(color: SpideyTheme.textGrey, fontSize: 10, fontFamily: 'RobotoMono')),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text("LOG ENERGY",
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            style: OutlinedButton.styleFrom(
              foregroundColor: SpideyTheme.spideyRed,
              side: const BorderSide(color: SpideyTheme.spideyRed),
              shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6))),
            ),
            onPressed: () => _showLogDialog(context, provider),
          ),
        ],
      ),
    );
  }

  static Color _levelColor(double v) {
    if (v <= 3) return SpideyTheme.spideyRed;
    if (v <= 6) return SpideyTheme.spideyGold;
    return SpideyTheme.spideyCyan;
  }
}

class _EnergyChart extends StatelessWidget {
  final List<EnergyLog> entries;
  const _EnergyChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = entries.map((e) {
      final hour = e.timestamp.hour + e.timestamp.minute / 60.0;
      return FlSpot(hour, e.level.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 24,
        minY: 0,
        maxY: 10,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 2,
          verticalInterval: 6,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: SpideyTheme.borderSoft, strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              const FlLine(color: SpideyTheme.borderSoft, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                if (v == 0 || v == 10 || v % 2 != 0) {
                  if (v != 0 && v != 10) return const SizedBox.shrink();
                }
                return Text("${v.toInt()}",
                    style: const TextStyle(color: SpideyTheme.textMuted, fontSize: 9, fontFamily: 'RobotoMono'));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                if (v < 0 || v > 24) return const SizedBox.shrink();
                final h = v.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text("${h.toString().padLeft(2, '0')}h",
                      style: const TextStyle(color: SpideyTheme.textMuted, fontSize: 9, fontFamily: 'RobotoMono')),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => SpideyTheme.bgElevated,
            getTooltipItems: (touched) => touched
                .map((s) => LineTooltipItem(
                      "${s.y.toInt()} @ ${s.x.toInt().toString().padLeft(2, '0')}:${(((s.x - s.x.toInt()) * 60).round()).toString().padLeft(2, '0')}",
                      const TextStyle(color: SpideyTheme.spideyCyan, fontSize: 11, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: SpideyTheme.spideyCyan,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: EnergyPanel._levelColor(spot.y),
                strokeWidth: 1.5,
                strokeColor: SpideyTheme.bgPanel,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SpideyTheme.spideyCyan.withOpacity(0.25),
                  SpideyTheme.spideyCyan.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyLogDialog extends StatefulWidget {
  final String dateStr;
  final AppProvider provider;
  const _EnergyLogDialog({required this.dateStr, required this.provider});

  @override
  State<_EnergyLogDialog> createState() => _EnergyLogDialogState();
}

class _EnergyLogDialogState extends State<_EnergyLogDialog> {
  double _level = 5;
  late DateTime _timestamp;

  @override
  void initState() {
    super.initState();
    final parsed = DateTime.tryParse(widget.dateStr) ?? DateTime.now();
    final now = DateTime.now();
    if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
      _timestamp = now;
    } else {
      _timestamp = DateTime(parsed.year, parsed.month, parsed.day, now.hour, now.minute);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      builder: (c, ch) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: SpideyTheme.spideyCyan,
            onPrimary: Colors.black,
            surface: SpideyTheme.bgPanel,
            onSurface: SpideyTheme.textWhite,
          ),
        ),
        child: ch!,
      ),
    );
    if (t == null) return;
    setState(() {
      _timestamp = DateTime(_timestamp.year, _timestamp.month, _timestamp.day, t.hour, t.minute);
    });
  }

  Color _levelColor(double v) {
    if (v <= 3) return SpideyTheme.spideyRed;
    if (v <= 6) return SpideyTheme.spideyGold;
    return SpideyTheme.spideyCyan;
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(_level);
    return AlertDialog(
      backgroundColor: SpideyTheme.bgPanel,
      shape: BeveledRectangleBorder(
        side: BorderSide(color: SpideyTheme.spideyRed.withOpacity(0.6)),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      title: Row(
        children: [
          Container(width: 3, height: 16, color: SpideyTheme.spideyRed),
          const SizedBox(width: 8),
          Text("LOG ENERGY",
              style: GoogleFonts.rajdhani(
                  color: SpideyTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.8)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("${_level.round()} / 10",
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(color: color, fontSize: 42, fontWeight: FontWeight.bold)),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _level,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _level = v),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SpideyTheme.bgElevated,
                border: Border.all(color: SpideyTheme.border),
              ),
              child: Row(
                children: [
                  Icon(MdiIcons.clockOutline, color: SpideyTheme.spideyCyan, size: 16),
                  const SizedBox(width: 8),
                  Text(DateFormat('MMM dd - HH:mm').format(_timestamp),
                      style: const TextStyle(color: SpideyTheme.textWhite, fontFamily: 'RobotoMono')),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: SpideyTheme.textGrey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: SpideyTheme.spideyRed,
            foregroundColor: Colors.white,
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
            ),
          ),
          onPressed: () {
            widget.provider.addEnergyLog(
              widget.dateStr,
              EnergyLog(
                id: const Uuid().v4(),
                level: _level.round(),
                timestamp: _timestamp,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ],
    );
  }
}
