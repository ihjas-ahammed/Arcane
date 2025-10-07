// lib/src/widgets/views/daily_summary_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/game_models.dart';
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
  int _hoveredEmotionRating = 0; // For emotion logging UI

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final availableDates = gameProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a)); // Sort descending
    if (_selectedDate == null && availableDates.isNotEmpty) {
      _selectedDate = availableDates.first;
    } else if (_selectedDate != null &&
        !availableDates.contains(_selectedDate)) {
      // If current selection is no longer valid (e.g. data cleared)
      _selectedDate = availableDates.isNotEmpty ? availableDates.first : null;
    }
  }

  Widget _buildEmotionLoggingRow(
      GameProvider gameProvider, String date, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final rating = index + 1;
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredEmotionRating = rating),
          onExit: (_) => setState(() => _hoveredEmotionRating = 0),
          child: GestureDetector(
            onTap: () {
              gameProvider.logEmotion(date, rating);
              setState(() => _hoveredEmotionRating = 0);
            },
            child: AnimatedScale(
              scale: _hoveredEmotionRating == rating ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getEmotionIcon(rating),
                    size: 32,
                    color: _hoveredEmotionRating >= rating
                        ? _getEmotionColor(rating, theme)
                        : AppTheme.fhTextDisabled,
                  ),
                  const SizedBox(height: 4),
                  Text(_getEmotionLabel(rating),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: _hoveredEmotionRating >= rating
                              ? _getEmotionColor(rating, theme)
                              : AppTheme.fhTextDisabled,
                          fontWeight: _hoveredEmotionRating == rating
                              ? FontWeight.bold
                              : FontWeight.normal))
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  IconData _getEmotionIcon(int rating) {
    switch (rating) {
      case 1:
        return MdiIcons.emoticonSadOutline;
      case 2:
        return MdiIcons.emoticonConfusedOutline;
      case 3:
        return MdiIcons.emoticonNeutralOutline;
      case 4:
        return MdiIcons.emoticonHappyOutline;
      case 5:
        return MdiIcons.emoticonExcitedOutline;
      default:
        return MdiIcons.emoticonOutline;
    }
  }

  String _getEmotionLabel(int rating) {
    switch (rating) {
      case 1:
        return "Awful";
      case 2:
        return "Bad";
      case 3:
        return "Okay";
      case 4:
        return "Good";
      case 5:
        return "Great";
      default:
        return "";
    }
  }

  Color _getEmotionColor(int rating, ThemeData theme) {
    // Use theme accents for consistency where appropriate
    switch (rating) {
      case 1:
        return AppTheme.fhAccentRed;
      case 2:
        return AppTheme.fhAccentOrange;
      case 3:
        return AppTheme.fhAccentGold;
      case 4:
        return AppTheme.fhAccentGreen;
      case 5:
        return theme
            .colorScheme.primary; // Use dynamic primary accent for best rating
      default:
        return AppTheme.fhTextDisabled;
    }
  }

  Widget _buildEmotionCurveChart(
      List<EmotionLog> logs, ThemeData theme, Color dynamicAccent) {
    if (logs.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
            child: Text(
          "Not enough emotion data for a trend line yet (need at least 2 logs for the day).",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
        )),
      );
    }

    // Calculate FlSpot data. X-value is hours from midnight of the log's day.
    List<FlSpot> spots = logs.map((log) {
      final DateTime logDayMidnight =
          DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      final Duration timeSinceMidnight =
          log.timestamp.difference(logDayMidnight);
      double xValue =
          timeSinceMidnight.inMinutes / 60.0; // e.g., 10.5 for 10:30 AM
      return FlSpot(xValue, log.rating.toDouble());
    }).toList();

    double minX, maxX;

    // Determine the actual min/max X values from the data points.
    // Note: logs.length is guaranteed to be >= 2 here, so spots will not be empty.
    double dataMinX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    double dataMaxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);

    if (dataMaxX == dataMinX) {
      // If all points have the same x-coordinate, create a default window (e.g., +/- 1 hour).
      minX = dataMinX - 1.0;
      maxX = dataMaxX + 1.0;
    } else {
      // Add padding (e.g., 5% of the data range) to each side.
      double range = dataMaxX - dataMinX;
      minX = dataMinX - range * 0.05;
      maxX = dataMaxX + range * 0.05;
    }

    // Clamp the calculated min/max X to the valid 24-hour range [0.0, 23.99].
    // Ensure minX doesn't go too high, allowing some space for maxX.
    minX = minX.clamp(0.0,
        23.49); // Max value for minX, allowing at least ~30min for maxX (0.5h).
    // Ensure maxX is greater than minX and within the upper boundary.
    maxX = maxX.clamp(
        minX + 0.1, 23.99); // Ensure at least a 6-minute (0.1 hour) range.

    // Fallback for very small or invalid ranges after clamping.
    if (maxX - minX < 0.2) {
      // If range is less than 12 minutes (0.2 hours).
      // Try to center a 1-hour window around the original data midpoint.
      double midDataX = (dataMinX + dataMaxX) / 2.0;
      minX = (midDataX - 0.5).clamp(0.0,
          23.0); // Clamp minX to allow a 1-hour window up to 23.99 for maxX.
      maxX = (midDataX + 0.5).clamp(minX + 0.1, 23.99); // Ensure minX < maxX.

      // If still problematic (e.g., data was at extreme edges or 1-hour window failed),
      // use the full day as a last resort.
      if (maxX <= minX) {
        minX = 0.0;
        maxX = 23.99;
      }
    }

    // --- The rest of the method uses the calculated minX and maxX ---

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0.5,
          maxY: 5.5,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            // Dynamic vertical grid based on the calculated time range
            verticalInterval: ((maxX - minX) / 5)
                .clamp(0.2, 6.0), // Allow smaller intervals for zoomed views
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
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value >= 1 && value <= 5)
                    return Text(value.toInt().toString(),
                        style: TextStyle(
                            color: AppTheme.fhTextSecondary, fontSize: 10));
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                // Dynamic bottom titles based on the calculated time range
                interval: ((maxX - minX) / 4)
                    .ceilToDouble()
                    .clamp(0.5, 6.0), // Allow smaller intervals
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
                      if (spotIndex < 0 || spotIndex >= logs.length)
                        return null; // Safety check
                      final logEntry = logs[spotIndex];
                      final DateTime time = logEntry.timestamp;

                      return LineTooltipItem(
                        '${_getEmotionLabel(touchedSpot.y.toInt())} (${touchedSpot.y.toInt()}/5) at ${DateFormat('HH:mm').format(time)}',
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
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);

    final availableDates = gameProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));

    if (_selectedDate == null && availableDates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.first);
      });
    } else if (_selectedDate != null &&
        !availableDates.contains(_selectedDate) &&
        availableDates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.first);
      });
    } else if (availableDates.isEmpty && _selectedDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = null);
      });
    }

    final summaryData = _selectedDate != null
        ? gameProvider.completedByDay[_selectedDate!]
        : null;
    final taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    final subtasksCompleted =
        summaryData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final checkpointsCompleted =
        summaryData?['checkpointsCompleted'] as List<dynamic>? ?? [];

    final List<EmotionLog> emotionLogsForSelectedDate = _selectedDate != null
        ? gameProvider.getEmotionLogsForDate(_selectedDate!)
        : [];

    final double totalMinutesToday = taskTimes.values
        .fold(0.0, (sum, time) => sum + (time as num).toDouble());

    final List<PieChartSectionData> pieChartSections = [];
    final List<Widget> legendItems = [];
    if (taskTimes.isNotEmpty) {
      taskTimes.forEach((taskId, time) {
        final task = gameProvider.mainTasks.firstWhere((t) => t.id == taskId,
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
      final dayData = gameProvider.completedByDay[dateStr];
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

      Color barColor = (gameProvider.getSelectedTask()?.taskColor ??
          AppTheme.fhAccentTealFixed);
      if (dominantTaskId != null) {
        final dominantTask = gameProvider.mainTasks.firstWhere(
            (t) => t.id == dominantTaskId,
            orElse: () => MainTask(
                id: '',
                name: '',
                description: '',
                theme: '',
                colorHex: (gameProvider.getSelectedTask()?.taskColor ??
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
            if (_selectedDate != null) ...[
              Card(
                color: AppTheme.fhBgMedium,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total Time Logged on ${DateFormat('MMMM d, yyyy').format(DateTime.parse(_selectedDate!))}: ${totalMinutesToday.toStringAsFixed(0)}m',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.fhAccentGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text("How are you feeling?",
                      style: theme.textTheme.headlineSmall)),
              const SizedBox(height: 10),
              _buildEmotionLoggingRow(gameProvider, _selectedDate!, theme),
              const SizedBox(height: 8),
              if (emotionLogsForSelectedDate.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(MdiIcons.deleteSweepOutline,
                        size: 16, color: AppTheme.fhAccentRed.withOpacity(0.7)),
                    label: Text("Delete Latest",
                        style: TextStyle(
                            color: AppTheme.fhAccentRed.withOpacity(0.7),
                            fontSize: 12)),
                    onPressed: () {
                      gameProvider.deleteLatestEmotionLog(_selectedDate!);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              if (emotionLogsForSelectedDate.isNotEmpty) ...[
                Text("Emotion Trend:", style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildEmotionCurveChart(
                    emotionLogsForSelectedDate,
                    theme,
                    gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed),
                const SizedBox(height: 30),
              ],
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
                  maxY: weeklyBarGroups
                              .map((g) => g.barRods.first.toY)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2 +
                      15,
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
                                      (gameProvider
                                              .getSelectedTask()
                                              ?.taskColor ??
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
                    horizontalInterval: (weeklyBarGroups
                                .map((g) => g.barRods.first.toY)
                                .reduce((a, b) => a > b ? a : b) /
                            5)
                        .clamp(10, 1000),
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
                          checkpointsCompleted.isEmpty &&
                          emotionLogsForSelectedDate
                              .isEmpty) // Check emotion logs too
                        Text("No specific activity recorded for this day.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.fhTextSecondary,
                                fontStyle: FontStyle.italic))
                      else ...[
                        if (emotionLogsForSelectedDate.isNotEmpty) ...[
                          Text('Emotion Logs:',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          ...emotionLogsForSelectedDate.map((log) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 3.0),
                                child: Text(
                                    '- Rated ${_getEmotionLabel(log.rating)} (${log.rating}/5) at ${DateFormat('HH:mm').format(log.timestamp.toLocal())}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: _getEmotionColor(
                                            log.rating, theme))),
                              )),
                          const SizedBox(height: 10),
                        ],
                        ...taskTimes.entries.map((entry) {
                          final task = gameProvider.mainTasks.firstWhere(
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
                            final parentTask = gameProvider.mainTasks
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
                        if (checkpointsCompleted.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Checkpoints Completed:',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          ...checkpointsCompleted.map((cpEntryMap) {
                            final cpEntry = cpEntryMap as Map<String, dynamic>;
                            final String mainTaskName =
                                cpEntry['mainTaskName'] as String? ?? 'N/A';
                            final String parentSubtaskName =
                                cpEntry['parentSubtaskName'] as String? ??
                                    'N/A';
                            final String countableInfo = (cpEntry['isCountable']
                                        as bool? ??
                                    false)
                                ? " (${cpEntry['currentCount']}/${cpEntry['targetCount']})"
                                : "";
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: 16.0, top: 3.0),
                              child: Text(
                                '- ${cpEntry['name']}$countableInfo (Sub-Mission: "$parentSubtaskName" in "$mainTaskName")',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: (gameProvider
                                                .getSelectedTask()
                                                ?.taskColor ??
                                            AppTheme.fhAccentTealFixed)
                                        .withOpacity(0.85)),
                              ),
                            );
                          }),
                        ]
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
