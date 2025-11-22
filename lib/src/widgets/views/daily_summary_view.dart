import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/emotion_models.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/dialogs/edit_log_dialog.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart'; // New
import 'package:arcane/src/widgets/ui/activity_log_list.dart'; // New
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DailySummaryView extends StatefulWidget {
  const DailySummaryView({super.key});

  @override
  State<DailySummaryView> createState() => _DailySummaryViewState();
}

class _DailySummaryViewState extends State<DailySummaryView> {
  String? _selectedDate;
  double _currentEnergyLevel = 50.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final availableDates = appProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));
    if (_selectedDate == null && availableDates.isNotEmpty) {
      _selectedDate = availableDates.first;
    } else if (_selectedDate != null &&
        !availableDates.contains(_selectedDate)) {
      _selectedDate = availableDates.isNotEmpty ? availableDates.first : null;
    }
  }
  
  void _showEditDialog(BuildContext context, AppProvider provider, String type, int index, dynamic currentValue) {
    showDialog(
      context: context,
      builder: (ctx) => EditLogDialog(
        title: "Edit ${type.capitalize()}",
        logType: type.toLowerCase(),
        initialValue: currentValue,
        onDelete: () {
          if (_selectedDate == null) return;
          if (type == 'Energy') provider.deleteEnergyLog(_selectedDate!, index);
          if (type == 'Reflection') provider.deleteReflectionLog(currentValue['id']);
        },
        onSave: (val) {
          if (_selectedDate == null) return;
          if (type == 'Energy') provider.updateEnergyLog(_selectedDate!, index, val);
          if (type == 'Reflection') {
             provider.updateReflectionLog(
               currentValue['id'], 
               trigger: val['trigger'], 
               emotion: val['emotion'], 
               reason: val['reason']
             );
          }
        },
      )
    );
  }

  Widget _buildEnergyLoggingRow(
      AppProvider appProvider, String date, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("What's your energy level?",
                style: theme.textTheme.headlineSmall),
            Text("${_currentEnergyLevel.toInt()}%",
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: (appProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed))),
          ],
        ),
        const SizedBox(height: 8),
        Slider.adaptive(
          value: _currentEnergyLevel,
          min: 0,
          max: 100,
          divisions: 10,
          label: "${_currentEnergyLevel.round()}%",
          onChanged: (double value) {
            setState(() {
              _currentEnergyLevel = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: Icon(MdiIcons.lightningBoltOutline, size: 18),
              label: const Text('LOG ENERGY'),
              onPressed: () {
                appProvider.logEnergy(date, _currentEnergyLevel.toInt());
              },
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTrendCurveChart<T>(
      {required List<T> logs,
      required ThemeData theme,
      required Color dynamicAccent,
      required double Function(T) getX,
      required double Function(T) getY,
      required String Function(T) getTooltipLabel,
      required double minY,
      required double maxY,
      String? yAxisSuffix}) {
    if (logs.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
            child: Text(
          "Not enough data for a trend line yet (need at least 2 logs for the day).",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
        )),
      );
    }

    List<FlSpot> spots =
        logs.map((log) => FlSpot(getX(log), getY(log))).toList();

    double dataMinX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    double dataMaxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    double minX, maxX;

    if (dataMaxX == dataMinX) {
      minX = dataMinX - 1.0;
      maxX = dataMaxX + 1.0;
    } else {
      double range = dataMaxX - dataMinX;
      minX = dataMinX - range * 0.05;
      maxX = dataMaxX + range * 0.05;
    }

    minX = minX.clamp(0.0, 23.49);
    maxX = maxX.clamp(minX + 0.1, 23.99);

    if (maxX - minX < 0.2) {
      double midDataX = (dataMinX + dataMaxX) / 2.0;
      minX = (midDataX - 0.5).clamp(0.0, 23.0);
      maxX = (midDataX + 0.5).clamp(minX + 0.1, 23.99);
      if (maxX <= minX) {
        minX = 0.0;
        maxX = 23.99;
      }
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: (maxY - minY) / 5,
            verticalInterval: ((maxX - minX) / 5).clamp(0.2, 6.0),
            getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.fhBorderColor.withOpacity(0.1),
                strokeWidth: 0.8),
            getDrawingVerticalLine: (value) => FlLine(
                color: AppTheme.fhBorderColor.withOpacity(0.1),
                strokeWidth: 0.8),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY - minY) / 5,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  return Text(
                      '${value.toInt()}${yAxisSuffix ?? ''}',
                      style: TextStyle(
                          color: AppTheme.fhTextSecondary, fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: ((maxX - minX) / 4).ceilToDouble().clamp(0.5, 6.0),
                getTitlesWidget: (value, meta) {
                  final hour = value.truncate().clamp(0, 23);
                  final minute = ((value - hour) * 60).round().clamp(0, 59);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        DateFormat('HH:mm')
                            .format(DateTime(2000, 1, 1, hour, minute)),
                        style: TextStyle(
                            color: AppTheme.fhTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
              show: true,
              border:
                  Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2))),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: dynamicAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                        radius: 4,
                        color: dynamicAccent.withOpacity(0.8),
                        strokeWidth: 1.5,
                        strokeColor: AppTheme.fhBgMedium),
              ),
              belowBarData: BarAreaData(
                  show: true, color: dynamicAccent.withOpacity(0.1)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppTheme.fhBgMedium,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots
                    .map((LineBarSpot touchedSpot) {
                      final spotIndex = touchedSpot.spotIndex;
                      if (spotIndex < 0 || spotIndex >= logs.length) return null;
                      return LineTooltipItem(
                        getTooltipLabel(logs[spotIndex]),
                        TextStyle(
                            color: dynamicAccent,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontDisplay),
                      );
                    })
                    .where((item) => item != null)
                    .map((item) => item!)
                    .toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    final availableDates = appProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));

    if (_selectedDate == null && availableDates.isNotEmpty) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.first);
      });
    } else if (_selectedDate != null && !availableDates.contains(_selectedDate)) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.isNotEmpty ? availableDates.first : null);
      });
    } else if (availableDates.isEmpty) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDate != null) setState(() => _selectedDate = null);
      });
    }

    final summaryData = _selectedDate != null ? appProvider.completedByDay[_selectedDate!] : null;
    final taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    final subtasksCompleted = summaryData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final checkpointsCompleted = summaryData?['checkpointsCompleted'] as List<dynamic>? ?? [];

    final List<EnergyLog> energyLogsForSelectedDate = _selectedDate != null
        ? appProvider.getEnergyLogsForDate(_selectedDate!)
        : [];
    
    final List<ReflectionLog> reflectionsForDate = _selectedDate != null
        ? appProvider.reflectionLogs.where((l) {
             final d = DateTime.parse(_selectedDate!);
             return l.timestamp.year == d.year && l.timestamp.month == d.month && l.timestamp.day == d.day;
          }).toList()
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availableDates.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Text("No mission logs recorded yet.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.fhTextSecondary,
                      fontStyle: FontStyle.italic)),
            ))
          else ...[
            DropdownButtonFormField<String>(
              value: _selectedDate,
              decoration: const InputDecoration(labelText: 'Select Date'),
              dropdownColor: AppTheme.fhBgMedium,
              items: availableDates.map((date) {
                return DropdownMenuItem(
                  value: date,
                  child: Text(DateFormat('MMMM d, yyyy (EEEE)')
                      .format(DateTime.parse(date))),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedDate = value),
            ),
            
            const SizedBox(height: 24),
            
            // --- VIRTUE PIE CHART SECTION ---
            Text("Daily Virtue Breakdown:", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.fhBgMedium.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: VirtuePieChart(logs: reflectionsForDate),
              ),
            ),
            const SizedBox(height: 30),

            // --- ENERGY SECTION ---
            _buildEnergyLoggingRow(appProvider, _selectedDate!, theme),
            const SizedBox(height: 16),
            if (energyLogsForSelectedDate.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Energy Logs (Tap to Edit):", style: theme.textTheme.titleMedium),
                  TextButton.icon(
                    icon: Icon(MdiIcons.deleteSweepOutline, size: 16, color: AppTheme.fhAccentRed.withOpacity(0.7)),
                    label: Text("Clear Latest", style: TextStyle(color: AppTheme.fhAccentRed.withOpacity(0.7), fontSize: 12)),
                    onPressed: () => appProvider.deleteLatestEnergyLog(_selectedDate!),
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: energyLogsForSelectedDate.length,
                itemBuilder: (ctx, i) {
                  final log = energyLogsForSelectedDate[i];
                  return ListTile(
                    title: Text("${log.level}% Energy"),
                    subtitle: Text(DateFormat('HH:mm').format(log.timestamp)),
                    leading: Icon(MdiIcons.lightningBolt, color: AppTheme.fhAccentGold),
                    trailing:  Icon(MdiIcons.pencilOutline, size: 16),
                    onTap: () => _showEditDialog(context, appProvider, 'Energy', i, log.level),
                  );
                }
              ),
              const SizedBox(height: 16),
              Text("Energy Trend:", style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
               _buildTrendCurveChart<EnergyLog>(
                  logs: energyLogsForSelectedDate,
                  theme: theme,
                  dynamicAccent: AppTheme.fhAccentGold,
                  getX: (log) {
                    final logDayMidnight = DateTime(log.timestamp.year,
                        log.timestamp.month, log.timestamp.day);
                    return log.timestamp
                            .difference(logDayMidnight)
                            .inMinutes /
                        60.0;
                  },
                  getY: (log) => log.level.toDouble(),
                  getTooltipLabel: (log) =>
                      '${log.level}% at ${DateFormat('HH:mm').format(log.timestamp.toLocal())}',
                  minY: -5,
                  maxY: 105,
                  yAxisSuffix: "%",
                ),
              const SizedBox(height: 30),
            ],
            
            // --- REFLECTIONS SECTION ---
             if (reflectionsForDate.isNotEmpty) ...[
               Text("Reflections (Tap to Edit):", style: theme.textTheme.titleMedium),
               ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reflectionsForDate.length,
                itemBuilder: (ctx, i) {
                  final log = reflectionsForDate[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(log.trigger.isNotEmpty ? log.trigger : "Reflection"),
                      subtitle: Text("Emotion: ${log.emotion} | XP: +${log.xpGained.values.fold(0, (a,b)=>a+b)}"),
                      leading:  Icon(MdiIcons.notebookOutline, color: AppTheme.fhAccentPurple),
                      trailing:  Icon(MdiIcons.pencilOutline, size: 16),
                      onTap: () => _showEditDialog(context, appProvider, 'Reflection', i, {
                        'id': log.id,
                        'trigger': log.trigger,
                        'emotion': log.emotion,
                        'reason': log.reason
                      }),
                    ),
                  );
                }
              ),
              const SizedBox(height: 30),
             ],

             // --- ACTIVITY LOG LIST SECTION ---
             Text(
                  'Activity Details for ${DateFormat('MMMM d').format(DateTime.parse(_selectedDate!))}:',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                color: AppTheme.fhBgMedium,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ActivityLogList(
                    taskTimes: taskTimes,
                    subtasksCompleted: subtasksCompleted,
                    checkpointsCompleted: checkpointsCompleted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      return "${this[0].toUpperCase()}${this.substring(1)}";
    }
}