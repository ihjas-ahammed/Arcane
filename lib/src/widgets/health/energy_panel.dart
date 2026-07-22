import 'dart:math' as math;
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
import 'package:missions/src/theme/jwe_theme.dart';

class EnergyPanel extends StatelessWidget {
  final String dateStr;
  const EnergyPanel({super.key, required this.dateStr});

  void _showLowEnergyDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => LogLowEnergyDialog(dateStr: dateStr, provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);
    final entries = List<EnergyLog>.from(log.energyLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final peakHoursStr = _calculatePeakWindows(entries);

    return SpideyPanel(
      title: "ENERGY WAVE",
      accentColor: SpideyTheme.spideyCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle / Inferred Peak Hours Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: JweTheme.accentCyan.withValues(alpha: 0.08),
              border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(MdiIcons.sineWave, size: 16, color: JweTheme.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "INFERRED PEAK WINDOWS",
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        peakHoursStr,
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entries.isEmpty
                        ? JweTheme.accentAmber.withValues(alpha: 0.15)
                        : JweTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    "${entries.length} DIPS",
                    style: GoogleFonts.jetBrainsMono(
                      color: entries.isEmpty ? JweTheme.accentAmber : JweTheme.accentRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 24h Wave Chart
          SizedBox(
            height: 170,
            child: _EnergyWaveChart(entries: entries),
          ),

          const SizedBox(height: 12),

          // Logged Low Energy Dips chips
          if (entries.isNotEmpty) ...[
            Text(
              "LOGGED LOW ENERGY POINTS (TROUGHS)",
              style: GoogleFonts.rajdhani(
                color: SpideyTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entries.map((e) {
                return InkWell(
                  onTap: () => provider.deleteEnergyLog(dateStr, e.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpideyTheme.spideyRed.withValues(alpha: 0.1),
                      border: Border.all(color: SpideyTheme.spideyRed.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.batteryAlert, size: 12, color: SpideyTheme.spideyRed),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(e.timestamp),
                          style: TextStyle(
                            color: SpideyTheme.spideyRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        if (e.note != null && e.note!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            "(${e.note})",
                            style: TextStyle(
                              color: SpideyTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 12, color: Colors.white54),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                "No fatigue points logged today. Tap below when you feel tired.",
                style: TextStyle(color: SpideyTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Log Low Energy Button
          OutlinedButton.icon(
            icon: Icon(MdiIcons.flashOff, size: 16),
            label: Text(
              "LOG LOW ENERGY",
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.4),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: SpideyTheme.spideyRed,
              side: BorderSide(color: SpideyTheme.spideyRed),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _showLowEnergyDialog(context, provider),
          ),
        ],
      ),
    );
  }

  String _calculatePeakWindows(List<EnergyLog> logs) {
    final spots = _generateWaveSpotsStatic(logs);
    final peakHours = <int>[];
    for (final s in spots) {
      if (s.y >= 70) {
        peakHours.add(s.x.round());
      }
    }
    if (peakHours.isEmpty) return "09:00 - 12:00, 18:00 - 20:00";

    peakHours.sort();
    final uniqueHours = peakHours.toSet().toList();
    final intervals = <String>[];
    int? start;
    int? prev;
    for (final h in uniqueHours) {
      if (start == null) {
        start = h;
        prev = h;
      } else if (h == prev! + 1) {
        prev = h;
      } else {
        intervals.add('${start.toString().padLeft(2, '0')}:00–${(prev + 1).toString().padLeft(2, '0')}:00');
        start = h;
        prev = h;
      }
    }
    if (start != null && prev != null) {
      intervals.add('${start.toString().padLeft(2, '0')}:00–${(prev + 1).toString().padLeft(2, '0')}:00');
    }
    return intervals.take(2).join(', ');
  }

  static List<FlSpot> _generateWaveSpotsStatic(List<EnergyLog> logs) {
    final lowHours = logs.map((e) => e.timestamp.hour + e.timestamp.minute / 60.0).toList();
    final spots = <FlSpot>[];

    for (double hour = 0; hour <= 24; hour += 0.25) {
      double base;
      if (hour < 6) {
        base = 0.25 + 0.1 * math.sin((hour / 6) * math.pi / 2);
      } else if (hour <= 12) {
        base = 0.35 + 0.5 * math.sin(((hour - 6) / 6) * math.pi / 2);
      } else if (hour <= 16) {
        base = 0.85 - 0.25 * math.sin(((hour - 12) / 4) * math.pi);
      } else if (hour <= 21) {
        base = 0.6 + 0.25 * math.sin(((hour - 16) / 5) * math.pi / 2);
      } else {
        base = 0.85 - 0.65 * ((hour - 21) / 3);
      }

      double dipFactor = 1.0;
      for (final lowH in lowHours) {
        final diff = (hour - lowH).abs();
        if (diff < 2.5) {
          final dip = math.exp(-(diff * diff) / 1.2);
          dipFactor *= (1.0 - 0.75 * dip);
        }
      }

      double finalVal = (base * dipFactor).clamp(0.1, 1.0) * 100.0;
      spots.add(FlSpot(hour, finalVal));
    }
    return spots;
  }
}

class _EnergyWaveChart extends StatelessWidget {
  final List<EnergyLog> entries;
  const _EnergyWaveChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = EnergyPanel._generateWaveSpotsStatic(entries);

    final lowEnergySpots = entries.map((e) {
      final hour = e.timestamp.hour + e.timestamp.minute / 60.0;
      final spot = spots.firstWhere(
        (s) => (s.x - hour).abs() < 0.3,
        orElse: () => FlSpot(hour, 15.0),
      );
      return FlSpot(hour, spot.y);
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 24,
        minY: 0,
        maxY: 100,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: 6,
          getDrawingHorizontalLine: (_) => FlLine(color: JweTheme.border.withValues(alpha: 0.3), strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: JweTheme.border.withValues(alpha: 0.3), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox.shrink();
                return Text('${v.toInt()}%', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              reservedSize: 20,
              getTitlesWidget: (v, _) {
                if (v < 0 || v > 24) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${v.toInt().toString().padLeft(2, '0')}h',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => JweTheme.panel,
            getTooltipItems: (touched) => touched.map((s) {
              final h = s.x.toInt();
              final m = (((s.x - h) * 60).round());
              final isPeak = s.y >= 70;
              final isTrough = s.y <= 35;
              final stateStr = isTrough ? 'TROUGH (Low Energy)' : (isPeak ? 'PEAK (High Energy)' : 'MODERATE');
              return LineTooltipItem(
                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} — ${s.y.round()}%\n$stateStr',
                GoogleFonts.jetBrainsMono(
                  color: isTrough ? JweTheme.accentRed : (isPeak ? JweTheme.accentCyan : JweTheme.textWhite),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: JweTheme.accentCyan,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, data) {
                return lowEnergySpots.any((l) => (l.x - spot.x).abs() < 0.2);
              },
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4.5,
                color: JweTheme.accentRed,
                strokeWidth: 2,
                strokeColor: JweTheme.bgDeep,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  JweTheme.accentCyan.withValues(alpha: 0.25),
                  JweTheme.accentCyan.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogLowEnergyDialog extends StatefulWidget {
  final String dateStr;
  final AppProvider provider;
  const LogLowEnergyDialog({super.key, required this.dateStr, required this.provider});

  @override
  State<LogLowEnergyDialog> createState() => _LogLowEnergyDialogState();
}

class _LogLowEnergyDialogState extends State<LogLowEnergyDialog> {
  late DateTime _timestamp;
  final _noteController = TextEditingController();

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _quickSetTime(Duration offset) {
    setState(() {
      _timestamp = DateTime.now().subtract(offset);
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      builder: (c, ch) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: ColorScheme.dark(
            primary: SpideyTheme.spideyCyan,
            onPrimary: JweTheme.onAccent,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpideyTheme.bgPanel,
      shape: BeveledRectangleBorder(
        side: BorderSide(color: SpideyTheme.spideyRed.withValues(alpha: 0.6)),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      title: Row(
        children: [
          Container(width: 3, height: 16, color: SpideyTheme.spideyRed),
          const SizedBox(width: 8),
          Text(
            "LOG LOW ENERGY / FATIGUE",
            style: GoogleFonts.rajdhani(
              color: SpideyTheme.textWhite,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "WHEN DID YOU FEEL TIRED?",
              style: GoogleFonts.rajdhani(color: SpideyTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _quickTimeChip("RIGHT NOW", Duration.zero),
                _quickTimeChip("30M AGO", const Duration(minutes: 30)),
                _quickTimeChip("1H AGO", const Duration(hours: 1)),
                _quickTimeChip("2H AGO", const Duration(hours: 2)),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: SpideyTheme.bgElevated,
                  border: Border.all(color: SpideyTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.clockOutline, color: SpideyTheme.spideyCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd — HH:mm').format(_timestamp),
                      style: TextStyle(color: SpideyTheme.textWhite, fontFamily: 'RobotoMono', fontSize: 13),
                    ),
                    const Spacer(),
                    Text("CHANGE", style: TextStyle(color: SpideyTheme.spideyCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: TextStyle(color: SpideyTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'STATUS NOTE (OPTIONAL)',
                labelStyle: GoogleFonts.rajdhani(color: SpideyTheme.textMuted, fontSize: 11),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: SpideyTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: SpideyTheme.spideyRed)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("CANCEL", style: TextStyle(color: SpideyTheme.textGrey)),
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
                level: 1,
                timestamp: _timestamp,
                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              ),
            );
            Navigator.pop(context);
          },
          child: const Text("RECORD FATIGUE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ],
    );
  }

  Widget _quickTimeChip(String label, Duration offset) {
    final targetTime = DateTime.now().subtract(offset);
    final isSelected = (_timestamp.difference(targetTime).inMinutes).abs() < 5;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: SpideyTheme.spideyRed,
      backgroundColor: SpideyTheme.bgElevated,
      labelStyle: TextStyle(color: isSelected ? Colors.white : SpideyTheme.textWhite),
      onSelected: (_) => _quickSetTime(offset),
    );
  }
}
