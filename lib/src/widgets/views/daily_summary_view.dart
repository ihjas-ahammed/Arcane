import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/dialogs/edit_log_dialog.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/ui/activity_log_list.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class DailySummaryView extends StatefulWidget {
  const DailySummaryView({super.key});

  @override
  State<DailySummaryView> createState() => _DailySummaryViewState();
}

class _DailySummaryViewState extends State<DailySummaryView> {
  String? _selectedDate;

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

  void _navigateToReflectionEditor(BuildContext context,
      {ReflectionLog? initialLog}) {
    // If we have a selected date, pass it. Otherwise use today.
    final dateStr =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReflectionEditorScreen(
          initialLog: initialLog,
          dateStr: dateStr,
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppProvider provider, String type,
      int index, dynamic currentValue) {
    if (type == 'Reflection') {
      final logId = currentValue['id'];
      final log =
          provider.reflectionLogs.firstWhereOrNull((l) => l.id == logId);
      if (log != null) {
        _navigateToReflectionEditor(context, initialLog: log);
      }
      return;
    }

    showDialog(
        context: context,
        builder: (ctx) => EditLogDialog(
              title: "Edit ${type.capitalize()}",
              logType: type.toLowerCase(),
              initialValue: currentValue,
              onDelete: () {
                if (_selectedDate == null) return;
                // Deletion for reflection is handled (or not) via editor or we could keep it here
                // But for now, since we redirect reflections, this block won't run for reflections.
              },
              onSave: (val) {
                if (_selectedDate == null) return;
                // Update implementation
              },
            ));
  }

  // Helper to prepare data for charts
  Map<String, dynamic> _prepareWeeklyData(AppProvider provider) {
    final today = DateTime.now();
    final Map<int, double> activityData = {};
    final Map<int, Color> activityColors = {};
    final Map<int, double> virtueData = {};
    final Map<int, Color> virtueColors = {};

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Activity Data
      final dayData = provider.completedByDay[dateStr];
      double totalMins = 0;
      Color dominantColor = AppTheme.fhBgLight;
      double maxMinsForTask = 0;

      if (dayData != null && dayData['taskTimes'] != null) {
        final taskTimes = dayData['taskTimes'] as Map<String, dynamic>;
        taskTimes.forEach((taskId, time) {
          final mins = (time as num).toDouble();
          totalMins += mins;
          if (mins > maxMinsForTask) {
            maxMinsForTask = mins;
            final task = provider.mainTasks.firstWhere((t) => t.id == taskId,
                orElse: () =>
                    MainTask(id: '', name: '', description: '', theme: ''));
            dominantColor = task.taskColor;
          }
        });
      }
      activityData[i] = totalMins;
      activityColors[i] = dominantColor;

      // Virtue Data
      final reflections = provider.reflectionLogs.where((l) {
        return l.timestamp.year == date.year &&
            l.timestamp.month == date.month &&
            l.timestamp.day == date.day;
      });

      double totalXp = 0;
      Map<String, int> virtueTotals = {};
      for (var ref in reflections) {
        ref.xpGained.forEach((k, v) {
          virtueTotals[k] = (virtueTotals[k] ?? 0) + v;
        });
        totalXp += ref.xpGained.values.fold(0, (sum, x) => sum + x);
      }
      virtueData[i] = totalXp;

      // Determine Dominant Virtue Color
      Color dominantVirtueColor = AppTheme.fhAccentGold;
      if (virtueTotals.isNotEmpty) {
        var maxVirtue =
            virtueTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        dominantVirtueColor = _getVirtueColor(maxVirtue.key);
      }
      virtueColors[i] = dominantVirtueColor;
    }

    // Prepare Daily Time Data for Pie Chart
    Map<String, double> dailyTaskTimeData = {};
    Map<String, Color> taskColors = {};
    if (_selectedDate != null) {
      final summaryData = provider.completedByDay[_selectedDate!];
      if (summaryData != null && summaryData['taskTimes'] != null) {
        (summaryData['taskTimes'] as Map<String, dynamic>)
            .forEach((taskId, time) {
          final task =
              provider.mainTasks.firstWhereOrNull((t) => t.id == taskId);
          final String name = task?.name ?? "Unknown";
          dailyTaskTimeData[name] = (time as num).toDouble();
          taskColors[name] = task?.taskColor ?? AppTheme.fhAccentTeal;
        });
      }
    }

    return {
      'activityData': activityData,
      'activityColors': activityColors,
      'virtueData': virtueData,
      'virtueColors': virtueColors,
      'dailyTaskTimeData': dailyTaskTimeData,
      'taskColors': taskColors,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    final availableDates = appProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));

    // Handle date selection logic safely
    if (_selectedDate == null && availableDates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.first);
      });
    } else if (_selectedDate != null &&
        !availableDates.contains(_selectedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedDate =
              availableDates.isNotEmpty ? availableDates.first : null);
        }
      });
    } else if (availableDates.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDate != null)
          setState(() => _selectedDate = null);
      });
    }

    // Prepare chart data
    final chartData = _prepareWeeklyData(appProvider);

    final summaryData = _selectedDate != null
        ? appProvider.completedByDay[_selectedDate!]
        : null;
    final taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    final subtasksCompleted =
        summaryData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final checkpointsCompleted =
        summaryData?['checkpointsCompleted'] as List<dynamic>? ?? [];

    final List<ReflectionLog> reflectionsForDate = _selectedDate != null
        ? appProvider.reflectionLogs.where((l) {
            final d = DateTime.parse(_selectedDate!);
            return l.timestamp.year == d.year &&
                l.timestamp.month == d.month &&
                l.timestamp.day == d.day;
          }).toList()
        : [];

    return LayoutBuilder(builder: (context, constraints) {
      final bool isWideScreen = constraints.maxWidth > 800;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- WEEKLY STATS CAROUSEL ---
            ChartCarousel(
              height: 250,
              pages: [
                ChartCarouselData(
                  title: "Last 7 Days Activity",
                  chart: WeeklyActivityBarChart(
                    weeklyData: chartData['activityData'],
                    dominantColors: chartData['activityColors'],
                  ),
                ),
                ChartCarouselData(
                  title: "Last 7 Days Growth",
                  chart: WeeklyVirtueBarChart(
                    weeklyXp: chartData['virtueData'],
                    dominantVirtueColors: chartData['virtueColors'],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),

            if (availableDates.isEmpty)
              Center(
                  child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text("No detailed logs recorded yet.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.fhTextSecondary,
                        fontStyle: FontStyle.italic)),
              ))
            else ...[
              // --- DAILY DETAIL SELECTOR ---
              InkWell(
                onTap: () async {
                  if (availableDates.isEmpty) return;

                  // Parse dates to find range
                  final dates =
                      availableDates.map((d) => DateTime.parse(d)).toList();
                  dates.sort();
                  final firstDate = dates.first;

                  final initialDate = _selectedDate != null
                      ? DateTime.parse(_selectedDate!)
                      : dates.last;

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: firstDate.subtract(
                        const Duration(days: 365)), // Allow looking back
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    selectableDayPredicate: (day) {
                      final dateStr = DateFormat('yyyy-MM-dd').format(day);
                      return availableDates.contains(dateStr);
                    },
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppTheme.fhAccentTeal,
                            onPrimary: AppTheme.fhTextPrimary,
                            surface: AppTheme.fhBgMedium,
                            onSurface: AppTheme.fhTextPrimary,
                          ),
                          // ignore: deprecated_member_use
                          dialogBackgroundColor: AppTheme.fhBgDark,
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (picked != null) {
                    setState(() {
                      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Inspect Day',
                    prefixIcon: Icon(MdiIcons.calendarSearchOutline,
                        color: AppTheme.fhAccentTeal),
                    suffixIcon: const Icon(Icons.arrow_drop_down,
                        color: AppTheme.fhTextSecondary),
                    filled: true,
                    fillColor: AppTheme.fhBgMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('MMMM d, yyyy')
                            .format(DateTime.parse(_selectedDate!))
                        : 'Select a date',
                    style: const TextStyle(color: AppTheme.fhTextPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- DAILY STATS CAROUSEL (Mixed Focus & Virtue) ---
              ChartCarousel(
                height: 320,
                pages: [
                  ChartCarouselData(
                    title: "Daily Virtue Breakdown",
                    chart: VirtuePieChart(logs: reflectionsForDate),
                  ),
                  ChartCarouselData(
                    title: "Today's Mission Focus",
                    chart: TimePieChart(
                      taskData: chartData['dailyTaskTimeData'],
                      taskColors: chartData['taskColors'],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              if (isWideScreen) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildActivitySection(theme, appProvider,
                          taskTimes, subtasksCompleted, checkpointsCompleted),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: _buildReflectionsSection(
                          context, theme, appProvider, reflectionsForDate),
                    )
                  ],
                )
              ] else ...[
                // Mobile Layout (Vertical Stack)
                _buildActivitySection(theme, appProvider, taskTimes,
                    subtasksCompleted, checkpointsCompleted),
                const SizedBox(height: 30),
                _buildReflectionsSection(
                    context, theme, appProvider, reflectionsForDate),
              ],
            ],
          ],
        ),
      );
    });
  }

  Widget _buildActivitySection(
      ThemeData theme,
      AppProvider provider,
      Map<String, dynamic> taskTimes,
      List<dynamic> subtasksCompleted,
      List<dynamic> checkpointsCompleted) {
    return Column(
      children: [
        Text('Activity Details', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        ActivityLogList(
          taskTimes: taskTimes,
          subtasksCompleted: subtasksCompleted,
          checkpointsCompleted: checkpointsCompleted,
          availableTasks: provider.mainTasks,
        ),
      ],
    );
  }

  Widget _buildReflectionsSection(BuildContext context, ThemeData theme,
      AppProvider provider, List<ReflectionLog> reflections) {
    return Column(
      children: [
        if (reflections.isNotEmpty) ...[
          Text("Reflections (Tap to Edit)",
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reflections.length,
              itemBuilder: (ctx, i) {
                final log = reflections[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: AppTheme.fhBgDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color:
                              AppTheme.fhBorderColor.withValues(alpha: 0.3))),
                  child: ListTile(
                    title: Text(
                        log.trigger.isNotEmpty ? log.trigger : "Reflection",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        "Emotion: ${log.emotion} | XP: +${log.xpGained.values.fold(0, (a, b) => a + b)}"),
                    leading: Icon(MdiIcons.notebookOutline,
                        color: AppTheme.fhAccentPurple),
                    trailing: Icon(MdiIcons.pencilOutline, size: 16),
                    onTap: () =>
                        _showEditDialog(context, provider, 'Reflection', i, {
                      'id': log.id,
                      'trigger': log.trigger,
                      'emotion': log.emotion,
                      'reason': log.reason
                    }),
                  ),
                );
              }),
        ],
        // Add a primary button to add a new reflection if none exist or just as an option
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: ElevatedButton.icon(
            onPressed: () => _navigateToReflectionEditor(context),
            icon: const Icon(Icons.add),
            label: const Text("Add Reflection"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fhAccentPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return Colors.blueAccent;
      case 'courage':
        return AppTheme.fhAccentRed;
      case 'humanity':
        return const Color(0xFFE91E63);
      case 'justice':
        return AppTheme.fhAccentGold;
      case 'temperance':
        return AppTheme.fhAccentTeal;
      case 'transcendence':
        return AppTheme.fhAccentPurple;
      default:
        return Colors.grey;
    }
  }
}
