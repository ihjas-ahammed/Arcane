// lib/src/widgets/views/daily_summary_view.dart
import 'package:arcane/src/models/skill_models.dart';
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/emotion_models.dart'; // Only EnergyLog is used now
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/widgets/dialogs/edit_log_dialog.dart';
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
  int _touchedPieIndex = -1;
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

  // --- Virtue Graph Widget ---
  Widget _buildVirtueGraph(AppProvider appProvider, ThemeData theme) {
    // Filter logs for selected date
    if (_selectedDate == null) return SizedBox.shrink();
    
    final dateStart = DateTime.parse(_selectedDate!);
    final dateEnd = dateStart.add(Duration(days: 1));

    final relevantLogs = appProvider.reflectionLogs.where((log) => 
      log.timestamp.isAfter(dateStart) && log.timestamp.isBefore(dateEnd)
    ).toList();

    if (relevantLogs.isEmpty) {
      return Center(child: Text("No reflections logged today.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic)));
    }
    
    relevantLogs.sort((a,b) => a.timestamp.compareTo(b.timestamp));

    // Build accumulation map
    Map<String, List<FlSpot>> spots = {
      'Wisdom': [FlSpot(0, 0)],
      'Courage': [FlSpot(0, 0)],
      'Humanity': [FlSpot(0, 0)],
      'Justice': [FlSpot(0, 0)],
      'Temperance': [FlSpot(0, 0)],
      'Transcendence': [FlSpot(0, 0)],
    };

    Map<String, double> currentTotals = {
      'Wisdom': 0, 'Courage': 0, 'Humanity': 0, 'Justice': 0, 'Temperance': 0, 'Transcendence': 0
    };

    for (var log in relevantLogs) {
      double timeOfDay = log.timestamp.hour + (log.timestamp.minute / 60.0);
      log.xpGained.forEach((virtue, xp) {
         if (currentTotals.containsKey(virtue)) {
           currentTotals[virtue] = currentTotals[virtue]! + xp;
           spots[virtue]!.add(FlSpot(timeOfDay, currentTotals[virtue]!));
         }
      });
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0, maxX: 24,
          minY: 0,
          lineBarsData: spots.entries.map((entry) {
             return LineChartBarData(
               spots: entry.value,
               isCurved: true,
               color: _getVirtueColor(entry.key),
               barWidth: 2,
               dotData: FlDotData(show: false),
             );
          }).toList(),
          titlesData: FlTitlesData(
             bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 4, getTitlesWidget: (val, meta) => Text("${val.toInt()}:00", style: TextStyle(fontSize: 10, color: AppTheme.fhTextSecondary)))),
             leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: TextStyle(fontSize: 10, color: AppTheme.fhTextSecondary)))),
             rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
             topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
          borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2))),
        )
      ),
    );
  }
  
  Color _getVirtueColor(String name) {
    switch (name) {
      case 'Wisdom': return Colors.blueAccent;
      case 'Courage': return Colors.redAccent;
      case 'Humanity': return Colors.pinkAccent;
      case 'Justice': return Colors.amber;
      case 'Temperance': return Colors.tealAccent;
      case 'Transcendence': return Colors.purpleAccent;
      default: return Colors.grey;
    }
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

    final double totalMinutesToday = taskTimes.values
        .fold(0.0, (sum, time) => sum + (time as num).toDouble());

    final List<PieChartSectionData> pieChartSections = [];
    final List<Widget> legendItems = [];
    if (taskTimes.isNotEmpty) {
      taskTimes.forEach((taskId, time) {
        final task = appProvider.mainTasks.firstWhere((t) => t.id == taskId,
            orElse: () => MainTask(
                id: '',
                name: 'Unknown Quest',
                description: '',
                theme: '',
                colorHex: AppTheme.fhTextDisabled.value
                    .toRadixString(16)
                    .substring(2)));
        final taskColor = task.taskColor;

        if (task.id != '') {
          final isTouched = pieChartSections.length == _touchedPieIndex;
          final fontSize = isTouched ? 13.0 : 11.0;
          final radius = isTouched ? 65.0 : 55.0;
          final titlePercentage = totalMinutesToday > 0
              ? ((time as num).toDouble() / totalMinutesToday * 100)
              : 0.0;

          pieChartSections.add(PieChartSectionData(
            color: taskColor,
            value: (time).toDouble(),
            title: '${titlePercentage.toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhBgDark,
                fontFamily: AppTheme.fontDisplay,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 2)]),
            titlePositionPercentageOffset: 0.6,
          ));
          legendItems.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: taskColor,
                        border: Border.all(
                            color: AppTheme.fhBorderColor.withOpacity(0.5),
                            width: 0.5))),
                const SizedBox(width: 8),
                Text(task.name.split(' ')[0],
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.fhTextSecondary,
                        fontFamily: AppTheme.fontBody)),
              ],
            ),
          ));
        }
      });
    }

    final List<BarChartGroupData> weeklyBarGroups = [];
    final today = DateTime.now();
    final List<String> last7DaysFormatted = [];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final dayData = appProvider.completedByDay[dateStr];
      final Map<String, dynamic> dailyTaskTimes =
          dayData != null && dayData['taskTimes'] != null
              ? dayData['taskTimes'] as Map<String, dynamic>
              : {};

      double dailyTotalMins = 0;
      String? dominantTaskId;
      int maxTime = 0;

      dailyTaskTimes.forEach((taskId, time) {
        final int currentTime = (time as num).toInt();
        dailyTotalMins += currentTime;
        if (currentTime > maxTime) {
          maxTime = currentTime;
          dominantTaskId = taskId;
        }
      });

      Color barColor = (appProvider.getSelectedTask()?.taskColor ??
          AppTheme.fhAccentTealFixed);
      if (dominantTaskId != null) {
        final dominantTask = appProvider.mainTasks.firstWhere(
            (t) => t.id == dominantTaskId,
            orElse: () => MainTask(
                id: '',
                name: '',
                description: '',
                theme: '',
                colorHex: (appProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed)
                    .value
                    .toRadixString(16)
                    .substring(2)));
        barColor = dominantTask.taskColor;
      }

      weeklyBarGroups.add(BarChartGroupData(
        x: 6 - i,
        barRods: [
          BarChartRodData(
              toY: dailyTotalMins,
              color: barColor.withOpacity(0.85),
              width: 18,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3), topRight: Radius.circular(3)))
        ],
      ));
      last7DaysFormatted.add(DateFormat('EEE, MMM d').format(d));
    }

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
            
            // --- VIRTUE GRAPH SECTION ---
            Text("Daily Virtue Growth:", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.fhBgMedium.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildVirtueGraph(appProvider, theme),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ["Wisdom", "Courage", "Humanity", "Justice", "Temperance", "Transcendence"].map((v) => 
                         Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Container(width: 8, height: 8, color: _getVirtueColor(v)),
                             const SizedBox(width: 4),
                             Text(v, style: TextStyle(fontSize: 10, color: AppTheme.fhTextSecondary))
                           ],
                         )
                      ).toList(),
                    )
                  ],
                ),
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
                physics: NeverScrollableScrollPhysics(),
                itemCount: energyLogsForSelectedDate.length,
                itemBuilder: (ctx, i) {
                  final log = energyLogsForSelectedDate[i];
                  return ListTile(
                    title: Text("${log.level}% Energy"),
                    subtitle: Text(DateFormat('HH:mm').format(log.timestamp)),
                    leading: Icon(MdiIcons.lightningBolt, color: AppTheme.fhAccentGold),
                    trailing: Icon(MdiIcons.pencilOutline, size: 16),
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
                physics: NeverScrollableScrollPhysics(),
                itemCount: reflectionsForDate.length,
                itemBuilder: (ctx, i) {
                  final log = reflectionsForDate[i];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(log.trigger.isNotEmpty ? log.trigger : "Reflection"),
                      subtitle: Text("Emotion: ${log.emotion} | XP: +${log.xpGained.values.fold(0, (a,b)=>a+b)}"),
                      leading: Icon(MdiIcons.notebookOutline, color: AppTheme.fhAccentPurple),
                      trailing: Icon(MdiIcons.pencilOutline, size: 16),
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

            if (pieChartSections.isNotEmpty) ...[
              Text("Time Distribution by Mission:",
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedPieIndex = -1;
                                  return;
                                }
                                _touchedPieIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: pieChartSections,
                        ),
                      ),
                    ),
                  ),
                  if (legendItems.isNotEmpty)
                    Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: legendItems,
                          ),
                        ))
                ],
              ),
              const SizedBox(height: 30),
            ],

            Text("Last 7 Days Activity (Total Minutes):",
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: weeklyBarGroups.isEmpty 
                      ? 10 
                      : weeklyBarGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2 + 15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (BarChartGroupData group) =>
                          AppTheme.fhBgMedium,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${last7DaysFormatted[group.x]}\n',
                          TextStyle(
                              color: AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppTheme.fontDisplay),
                          children: <TextSpan>[
                            TextSpan(
                              text: '${rod.toY.toStringAsFixed(0)} min',
                              style: TextStyle(
                                  color: rod.color ??
                                      (appProvider.getSelectedTask()?.taskColor ??
                                          AppTheme.fhAccentTealFixed),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: AppTheme.fontBody),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value < 0 || value >= last7DaysFormatted.length) return SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            space: 10.0,
                            child: Text(
                                last7DaysFormatted[value.toInt()]
                                    .substring(0, 3)
                                    .toUpperCase(),
                                style: TextStyle(
                                    color: AppTheme.fhTextSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    fontFamily: AppTheme.fontDisplay)),
                          );
                        },
                        reservedSize: 38,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value == meta.max ||
                                (value == 0 && meta.max > 20)) {
                              return SideTitleWidget(
                                  meta: meta, child: Container());
                            }
                            return SideTitleWidget(
                                meta: meta,
                                child: Text('${value.toInt()}',
                                    style: TextStyle(
                                        color: AppTheme.fhTextSecondary,
                                        fontSize: 11,
                                        fontFamily: AppTheme.fontBody)));
                          }),
                    ),
                  ),
                  borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                          color: AppTheme.fhBorderColor.withOpacity(0.2),
                          width: 1)),
                  barGroups: weeklyBarGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    verticalInterval: 1,
                    horizontalInterval: weeklyBarGroups.isEmpty 
                        ? 1 
                        : (weeklyBarGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) / 5).clamp(10, 1000),
                    getDrawingHorizontalLine: (value) => FlLine(
                        color: AppTheme.fhBorderColor.withOpacity(0.1),
                        strokeWidth: 0.8),
                    getDrawingVerticalLine: (value) => FlLine(
                        color: AppTheme.fhBorderColor.withOpacity(0.1),
                        strokeWidth: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

             if (_selectedDate != null) ...[
              Text(
                  'Activity Details for ${DateFormat('MMMM d').format(DateTime.parse(_selectedDate!))}:',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                color: AppTheme.fhBgMedium,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (taskTimes.isEmpty &&
                          subtasksCompleted.isEmpty &&
                          checkpointsCompleted.isEmpty)
                        Text("No specific task activity recorded for this day.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.fhTextSecondary,
                                fontStyle: FontStyle.italic))
                      else ...[
                        ...taskTimes.entries.map((entry) {
                          final task = appProvider.mainTasks.firstWhere(
                              (t) => t.id == entry.key,
                              orElse: () => MainTask(
                                  id: '',
                                  name: 'Unknown Task',
                                  description: '',
                                  theme: '',
                                  colorHex: AppTheme.fhTextDisabled.value
                                      .toRadixString(16)
                                      .substring(2)));
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Text('${task.name}: ${entry.value}m',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: task.taskColor)),
                          );
                        }),
                        if (subtasksCompleted.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Sub-Missions Completed:',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          ...subtasksCompleted.map((subEntryMap) {
                            final subEntry =
                                subEntryMap as Map<String, dynamic>;
                            final parentTask = appProvider.mainTasks
                                .firstWhere(
                                    (t) => t.id == subEntry['parentTaskId'],
                                    orElse: () => MainTask(
                                        id: '',
                                        name: 'Unknown Task',
                                        description: '',
                                        theme: ''));
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: 16.0, top: 3.0),
                              child: Text(
                                '- ${subEntry['name']} (for ${parentTask.name}) - Logged: ${subEntry['timeLogged']}m, Count: ${subEntry['currentCount']}/${subEntry['targetCount']}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.fhTextSecondary),
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
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