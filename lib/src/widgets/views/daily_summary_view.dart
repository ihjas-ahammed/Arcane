import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/dialogs/edit_log_dialog.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart'; 
import 'package:arcane/src/widgets/ui/activity_log_list.dart'; 
import 'package:arcane/src/widgets/views/stats_carousel_view.dart'; 
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart'; // for firstWhereOrNull

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
  
  void _showEditDialog(BuildContext context, AppProvider provider, String type, int index, dynamic currentValue) {
    showDialog(
      context: context,
      builder: (ctx) => EditLogDialog(
        title: "Edit ${type.capitalize()}",
        logType: type.toLowerCase(),
        initialValue: currentValue,
        onDelete: () {
          if (_selectedDate == null) return;
          // Energy log delete removed
          if (type == 'Reflection') provider.deleteReflectionLog(currentValue['id']);
        },
        onSave: (val) {
          if (_selectedDate == null) return;
          // Energy log update removed
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

  // Helper to prepare data for charts
  Map<String, dynamic> _prepareWeeklyData(AppProvider provider) {
    final today = DateTime.now();
    final Map<int, double> activityData = {};
    final Map<int, Color> activityColors = {};
    final Map<int, double> virtueData = {};
    final Map<int, Color> virtueColors = {}; // New

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
            final task = provider.mainTasks.firstWhere((t) => t.id == taskId, orElse: () => MainTask(id: '', name: '', description: '', theme: ''));
            dominantColor = task.taskColor;
          }
        });
      }
      activityData[i] = totalMins;
      activityColors[i] = dominantColor;

      // Virtue Data
      final reflections = provider.reflectionLogs.where((l) {
         return l.timestamp.year == date.year && l.timestamp.month == date.month && l.timestamp.day == date.day;
      });
      
      double totalXp = 0;
      Map<String, int> virtueTotals = {};
      for(var ref in reflections) {
        ref.xpGained.forEach((k, v) {
           virtueTotals[k] = (virtueTotals[k] ?? 0) + v;
        });
        totalXp += ref.xpGained.values.fold(0, (sum, x) => sum + x);
      }
      virtueData[i] = totalXp;
      
      // Determine Dominant Virtue Color
      Color dominantVirtueColor = AppTheme.fhAccentGold;
      if (virtueTotals.isNotEmpty) {
        var maxVirtue = virtueTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
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
        (summaryData['taskTimes'] as Map<String, dynamic>).forEach((taskId, time) {
           final task = provider.mainTasks.firstWhereOrNull((t) => t.id == taskId);
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
    } else if (_selectedDate != null && !availableDates.contains(_selectedDate)) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDate = availableDates.isNotEmpty ? availableDates.first : null);
      });
    } else if (availableDates.isEmpty) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDate != null) setState(() => _selectedDate = null);
      });
    }
    
    // Prepare chart data AFTER determining selection
    final chartData = _prepareWeeklyData(appProvider);

    final summaryData = _selectedDate != null ? appProvider.completedByDay[_selectedDate!] : null;
    final taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    final subtasksCompleted = summaryData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final checkpointsCompleted = summaryData?['checkpointsCompleted'] as List<dynamic>? ?? [];

    final List<ReflectionLog> reflectionsForDate = _selectedDate != null
        ? appProvider.reflectionLogs.where((l) {
             final d = DateTime.parse(_selectedDate!);
             return l.timestamp.year == d.year && l.timestamp.month == d.month && l.timestamp.day == d.day;
          }).toList()
        : [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- STATS CAROUSEL (Top Section) ---
              StatsCarouselView(
                activityData: chartData['activityData'],
                activityColors: chartData['activityColors'],
                virtueData: chartData['virtueData'],
                virtueColors: chartData['virtueColors'],
                dailyTaskTimeData: chartData['dailyTaskTimeData'],
                taskColors: chartData['taskColors'],
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
                DropdownButtonFormField<String>(
                  value: _selectedDate,
                  decoration:  InputDecoration(
                    labelText: 'Inspect Day',
                    prefixIcon: Icon(MdiIcons.calendarSearchOutline, color: AppTheme.fhAccentTeal)
                  ),
                  dropdownColor: AppTheme.fhBgMedium,
                  items: availableDates.map((date) {
                    return DropdownMenuItem(
                      value: date,
                      child: Text(DateFormat('MMMM d, yyyy').format(DateTime.parse(date))),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDate = value),
                ),
                
                const SizedBox(height: 24),
                
                // Responsive Layout for Charts and Logs
                if (isWideScreen) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Text("Daily Virtue Breakdown", style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 12),
                            Card(
                              color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: VirtuePieChart(logs: reflectionsForDate),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                             Text(
                                'Activity Details',
                                style: theme.textTheme.headlineSmall),
                             const SizedBox(height: 12),
                             ActivityLogList(
                               taskTimes: taskTimes,
                               subtasksCompleted: subtasksCompleted,
                               checkpointsCompleted: checkpointsCompleted,
                             ),
                          ],
                        ),
                      )
                    ],
                  )
                ] else ...[
                  // Mobile Layout (Vertical Stack)
                  Text("Daily Virtue Breakdown", style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Card(
                    color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: VirtuePieChart(logs: reflectionsForDate),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Activity Details',
                    style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ActivityLogList(
                    taskTimes: taskTimes,
                    subtasksCompleted: subtasksCompleted,
                    checkpointsCompleted: checkpointsCompleted,
                  ),
                ],

                const SizedBox(height: 30),
                
                // REFLECTIONS LIST
                 if (reflectionsForDate.isNotEmpty) ...[
                   Text("Reflections (Tap to Edit)", style: theme.textTheme.headlineSmall),
                   const SizedBox(height: 8),
                   ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reflectionsForDate.length,
                    itemBuilder: (ctx, i) {
                      final log = reflectionsForDate[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: AppTheme.fhBgDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.3))
                        ),
                        child: ListTile(
                          title: Text(log.trigger.isNotEmpty ? log.trigger : "Reflection", style: const TextStyle(fontWeight: FontWeight.w600)),
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
              ],
            ],
          ),
        );
      }
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return AppTheme.fhAccentRed;
      case 'humanity': return const Color(0xFFE91E63);
      case 'justice': return AppTheme.fhAccentGold;
      case 'temperance': return AppTheme.fhAccentTeal;
      case 'transcendence': return AppTheme.fhAccentPurple;
      default: return Colors.grey;
    }
  }
}

extension StringExtension on String {
    String capitalize() {
      return "${this[0].toUpperCase()}${this.substring(1)}";
    }
}