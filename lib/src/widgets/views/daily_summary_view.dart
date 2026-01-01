import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/ui/activity_log_list.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; 
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
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
  bool _isGeneratingSummary = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to today if no date is selected
    if (_selectedDate == null) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Even if today has no data yet, it's the logical starting point
      _selectedDate = today;
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
  }

  Future<void> _pickDate(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // Create a Set of valid dates for O(1) lookup
    // We only want dates that have either task activity or reflection logs
    final Set<String> validDates = {};
    
    // 1. From Task Completion / Time Data
    validDates.addAll(appProvider.completedByDay.keys);
    
    // 2. From Reflection Logs
    for (var log in appProvider.reflectionLogs) {
      validDates.add(DateFormat('yyyy-MM-dd').format(log.timestamp));
    }
    
    // 3. Always include Today and Tomorrow (for planning context)
    final today = DateTime.now();
    validDates.add(DateFormat('yyyy-MM-dd').format(today));
    validDates.add(DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 1))));

    final initialDate = _selectedDate != null ? DateTime.tryParse(_selectedDate!) ?? DateTime.now() : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      selectableDayPredicate: (DateTime date) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        return validDates.contains(dateStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.fhAccentTeal,
              onPrimary: AppTheme.fhTextPrimary,
              surface: AppTheme.fhBgDark,
              onSurface: AppTheme.fhTextPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppTheme.fhBgDeepDark),
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

  Future<void> _generateDailySummary(AppProvider provider, List<ReflectionLog> logs) async {
    if (_selectedDate == null) return;
    
    setState(() => _isGeneratingSummary = true);
    
    try {
      final aiService = AIService();
      final summary = await aiService.generateDailySummary(
        reflections: logs.map((l) => {
          'trigger': l.trigger,
          'emotion': l.emotion,
          'reason': l.reason,
        }).toList(),
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKey: provider.settings.customApiKey,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
      );
      
      // Save summary to provider
      provider.saveDailySummary(_selectedDate!, summary);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate summary: $e")));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    // Prepare Data
    final chartData = ChartDataHelper.prepareWeeklyData(
      appProvider, 
      _selectedDate, 
      _selectedTaskFilter, 
      _selectedVirtueFilter
    );

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
    
    // Retrieve AI Summary from provider
    final String? aiDailySummary = _selectedDate != null ? appProvider.getDailySummary(_selectedDate!) : null;

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
          // --- Carousel ---
          ChartCarousel(
            height: 250,
            pages: [
              ChartCarouselData(
                title: "7-DAY PERFORMANCE",
                chart: WeeklyActivityBarChart(
                  weeklyData: chartData['activityData'],
                  dominantColors: chartData['activityColors'],
                  isVirtue: false,
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

          // --- Date Picker with Valorant Style ---
          InkWell(
            onTap: () => _pickDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border.all(color: AppTheme.fhBorderColor),
                // No border radius or very small for Valorant style
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "INSPECT DATE", 
                        style: TextStyle(
                          color: AppTheme.fhTextSecondary, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2
                        )
                      ),
                      Text(
                        _selectedDate ?? 'TODAY', 
                        style: const TextStyle(
                          fontFamily: AppTheme.fontDisplay, 
                          letterSpacing: 1.0, 
                          fontSize: 18,
                          color: AppTheme.fhTextPrimary,
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ],
                  ),
                  const Icon(Icons.calendar_today, color: AppTheme.fhAccentTeal, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- AI Daily Briefing Section ---
          // Always show card, content depends on if summary exists
          

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
ValorantCard(
            borderColor: AppTheme.fhAccentPurple.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.robotExcitedOutline, color: AppTheme.fhAccentPurple, size: 20),
                        const SizedBox(width: 8),
                        const Text("TACTICAL BRIEFING", style: TextStyle(
                          fontFamily: AppTheme.fontDisplay, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.fhTextPrimary
                        )),
                      ],
                    ),
                    if (aiDailySummary != null)
                      IconButton(
                        icon: Icon(MdiIcons.deleteOutline, size: 18, color: AppTheme.fhTextSecondary),
                        onPressed: () => appProvider.deleteDailySummary(_selectedDate!),
                        tooltip: "Delete Briefing",
                      )
                  ],
                ),
                const SizedBox(height: 12),
                if (aiDailySummary != null)
                  Text(
                    aiDailySummary,
                    style: const TextStyle(color: AppTheme.fhTextSecondary, height: 1.4, fontSize: 13),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "No briefing intel available for this date.",
                        style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Generate an AI analysis of logs to reveal hidden patterns and actionable intel.",
                        style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (aiDailySummary == null)
                  SizedBox(
                    width: double.infinity,
                    child: ValorantButton(
                      label: _isGeneratingSummary ? "ANALYZING..." : "GENERATE BRIEFING",
                      isPrimary: false,
                      color: AppTheme.fhAccentPurple.withOpacity(0.2),
                      onPressed: _isGeneratingSummary ? null : () => _generateDailySummary(appProvider, reflectionsForDate),
                    ),
                  )
              ],
            ),
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