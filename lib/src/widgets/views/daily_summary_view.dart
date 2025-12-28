import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/dialogs/edit_log_dialog.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/ui/activity_log_list.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; 
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
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
  String? _selectedTaskFilter;
  String? _selectedVirtueFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final availableDates = appProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));
    if (_selectedDate == null) {
      // Default to today if available, or most recent
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedDate = availableDates.contains(today) ? today : (availableDates.isNotEmpty ? availableDates.first : today);
    }
  }

  void _navigateToReflectionEditor(BuildContext context, {ReflectionLog? initialLog}) {
    final dateStr = _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  void _showEditDialog(BuildContext context, AppProvider provider, String type, int index, dynamic currentValue) {
    if (type == 'Reflection') {
      final logId = currentValue['id'];
      final log = provider.reflectionLogs.firstWhereOrNull((l) => l.id == logId);
      if (log != null) {
        _navigateToReflectionEditor(context, initialLog: log);
      }
      return;
    }
    // Generic edit logic if needed for other types
  }

  Future<void> _pickDate(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final availableDates = appProvider.completedByDay.keys.map((d) => DateTime.tryParse(d)).whereType<DateTime>().toList();
    
    // Sort logic
    DateTime firstDate = DateTime(2023); 
    if (availableDates.isNotEmpty) {
      availableDates.sort();
      if (availableDates.first.isBefore(firstDate)) firstDate = availableDates.first;
    }

    final initialDate = _selectedDate != null ? DateTime.tryParse(_selectedDate!) ?? DateTime.now() : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.fhAccentTeal,
              onPrimary: AppTheme.fhTextPrimary,
              surface: AppTheme.fhBgDark,
              onSurface: AppTheme.fhTextPrimary,
            ),
            dialogTheme: DialogThemeData(backgroundColor: AppTheme.fhBgDeepDark),
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
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    // Prepare Data
    final chartData = ChartDataHelper.prepareWeeklyData(
      appProvider, 
      _selectedDate, 
      _selectedTaskFilter, 
      _selectedVirtueFilter
    );

    // Current Day Data
    final summaryData = _selectedDate != null ? appProvider.completedByDay[_selectedDate!] : null;

    Map<String, dynamic> taskTimes = {};
    if (_selectedDate != null && _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      final today = DateTime.now();
      for (var task in appProvider.mainTasks) {
        final val = ChartDataHelper.calculateDailyTimeFromSessions(task, today);
        if (val > 0) taskTimes[task.id] = val;
      }
    } else {
      taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    }
    
    final subtasksCompleted = summaryData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final checkpointsCompleted = summaryData?['checkpointsCompleted'] as List<dynamic>? ?? [];

    final List<ReflectionLog> reflectionsForDate = _selectedDate != null
        ? appProvider.reflectionLogs.where((l) {
            final d = DateTime.parse(_selectedDate!);
            return l.timestamp.year == d.year &&
                l.timestamp.month == d.month &&
                l.timestamp.day == d.day;
          }).toList()
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Carousel (Restored Swipe Style) ---
          ChartCarousel(
            height: 250, // Slightly taller for bar labels
            pages: [
              ChartCarouselData(
                title: "7-DAY PERFORMANCE",
                chart: WeeklyActivityBarChart(
                  weeklyData: chartData['activityData'],
                  dominantColors: chartData['activityColors'],
                ),
              ),
              ChartCarouselData(
                title: "VIRTUE GROWTH",
                chart: WeeklyVirtueBarChart(
                  weeklyXp: chartData['virtueData'],
                  dominantVirtueColors: chartData['virtueColors'],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- Date Picker (Fixed for Older Archives) ---
          InkWell(
            onTap: () => _pickDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border.all(color: AppTheme.fhBorderColor),
                borderRadius: BorderRadius.zero, // Valorant Sharp
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "INSPECT: ${_selectedDate ?? 'TODAY'}", 
                    style: const TextStyle(
                      fontFamily: AppTheme.fontDisplay, 
                      letterSpacing: 1.0, 
                      fontSize: 16,
                      color: AppTheme.fhTextSecondary
                    )
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.fhAccentTeal),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Daily Breakdown (Pie Charts) ---
          Row(
            children: [
              Expanded(
                child: ValorantCard(
                  child: Column(
                    children: [
                      const Text("MISSION FOCUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.fhTextSecondary)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: TimePieChart(
                          taskData: chartData['dailyTaskTimeData'],
                          taskColors: chartData['taskColors'],
                          selectedTask: _selectedTaskFilter,
                          onTaskSelected: (val) => setState(() => _selectedTaskFilter = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValorantCard(
                  child: Column(
                    children: [
                      const Text("VIRTUE GROWTH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.fhTextSecondary)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: VirtuePieChart(
                          logs: reflectionsForDate,
                          selectedVirtue: _selectedVirtueFilter,
                          onVirtueSelected: (val) => setState(() => _selectedVirtueFilter = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- Activity List ---
          const Text("COMBAT LOG // DETAILS", style: TextStyle(color: AppTheme.fhTextSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ActivityLogList(
            taskTimes: taskTimes,
            subtasksCompleted: subtasksCompleted,
            checkpointsCompleted: checkpointsCompleted,
            availableTasks: appProvider.mainTasks,
          ),

          const SizedBox(height: 24),

          // --- Reflections Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("REFLECTIONS", style: TextStyle(color: AppTheme.fhTextSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_box, color: AppTheme.fhAccentTeal),
                onPressed: () => _navigateToReflectionEditor(context),
              )
            ],
          ),
          if (reflectionsForDate.isEmpty)
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: Text("No entries recorded.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic)),
             )
          else
            ...reflectionsForDate.asMap().entries.map((entry) {
              final log = entry.value;
              return GestureDetector(
                onTap: () => _showEditDialog(context, appProvider, 'Reflection', entry.key, {
                  'id': log.id, 'trigger': log.trigger, 'emotion': log.emotion, 'reason': log.reason
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                    border: Border(left: BorderSide(color: AppTheme.fhAccentPurple, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.trigger.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
                      const SizedBox(height: 4),
                      Text(log.reason, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            }),
            
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}