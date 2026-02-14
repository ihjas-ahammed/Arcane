import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; 
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/cards/tactical_briefing_card.dart';
import 'package:arcane/src/widgets/dialogs/weekly_report_dialog.dart';
import 'package:arcane/src/screens/neural_archive_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/cards/start_day_report_card.dart'; 
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
  bool _isGeneratingWeeklyReport = false;
  bool _isGeneratingStartDay = false;
  
  Map<String, dynamic>? _tempGeneratedBriefing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedDate == null) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
    final Set<String> validDates = {};
    validDates.addAll(appProvider.completedByDay.keys);
    
    for (var log in appProvider.reflectionLogs) {
      validDates.add(DateFormat('yyyy-MM-dd').format(log.timestamp));
    }
    
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
        _tempGeneratedBriefing = null; 
      });
    }
  }

  Future<void> _generateTacticalBriefing(AppProvider provider, List<ReflectionLog> logs) async {
    if (_selectedDate == null) return;
    
    setState(() => _isGeneratingSummary = true);
    
    try {
      final briefingData = await provider.generateTacticalBriefing(_selectedDate!, logs);
      
      setState(() {
        _tempGeneratedBriefing = briefingData;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate briefing: $e")));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  Future<void> _generateWeeklyReport(AppProvider provider) async {
    setState(() => _isGeneratingWeeklyReport = true);
    try {
      final data = provider.getLast7DaysData();
      final aiService = provider.aiService;
      
      final result = await aiService.generateWeeklyReport(
        logsText: data['logs'] as String,
        timeStatsText: data['times'] as String,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => WeeklyReportDialog(reportData: result),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Report gen failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingWeeklyReport = false);
    }
  }

  Future<void> _generateStartDayReport(AppProvider provider) async {
    setState(() => _isGeneratingStartDay = true);
    try {
      await provider.generateStartDayReport();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Start Day Report failed: $e")));
    } finally {
      if (mounted) setState(() => _isGeneratingStartDay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    final chartData = ChartDataHelper.prepareWeeklyData(
      appProvider, 
      _selectedDate, 
      _selectedTaskFilter, 
      _selectedVirtueFilter
    );

    final savedBriefing = _selectedDate != null ? appProvider.getTacticalBriefing(_selectedDate!) : null;
    final displayBriefing = savedBriefing ?? _tempGeneratedBriefing;
    
    final startDayReport = _selectedDate != null ? appProvider.getStartDayReport(_selectedDate!) : null;
    final isToday = _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ANALYTICS", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.fhTextSecondary, fontFamily: AppTheme.fontDisplay)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(MdiIcons.archiveSearchOutline, size: 20, color: AppTheme.fhAccentPurple),
                    tooltip: "NEURAL ARCHIVE",
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NeuralArchiveScreen())),
                  ),
                  TextButton.icon(
                    icon: _isGeneratingWeeklyReport 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(MdiIcons.fileChartOutline, size: 16),
                    label: const Text("WEEKLY REPORT", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.fhAccentGold),
                    onPressed: _isGeneratingWeeklyReport ? null : () => _generateWeeklyReport(appProvider),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
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
          
          InkWell(
            onTap: () => _pickDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border.all(color: AppTheme.fhBorderColor),
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

          // START DAY REPORT
          if (startDayReport != null)
            StartDayReportCard(
              report: startDayReport,
              isRegenerating: _isGeneratingStartDay,
              onRegenerate: () => _generateStartDayReport(appProvider),
            )
          else if (isToday)
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: _isGeneratingStartDay ? "INITIALIZING..." : "SYSTEM STARTUP REPORT",
                icon: MdiIcons.power,
                isPrimary: true,
                color: AppTheme.fhAccentTeal,
                onPressed: _isGeneratingStartDay ? null : () => _generateStartDayReport(appProvider),
              ),
            ),

          const SizedBox(height: 24),

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

          // TACTICAL BRIEFING SECTION
          if (displayBriefing != null)
            TacticalBriefingCard(
              briefingData: displayBriefing,
              isSaved: savedBriefing != null,
              onSave: savedBriefing == null 
                ? () {
                    appProvider.saveTacticalBriefing(_selectedDate!, displayBriefing);
                    setState(() {});
                  } 
                : null,
            )
          else
            ValorantCard(
              borderColor: AppTheme.fhBorderColor.withValues(alpha: 0.2),
              child: Column(
                children: [
                  const Text("NO BRIEFING INTEL", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ValorantButton(
                      label: _isGeneratingSummary ? "ANALYZING..." : "GENERATE BRIEFING",
                      isPrimary: false,
                      color: AppTheme.fhAccentPurple.withValues(alpha: 0.2),
                      onPressed: _isGeneratingSummary ? null : () => _generateTacticalBriefing(appProvider, reflectionsForDate),
                    ),
                  )
                ],
              ),
            ),

          const SizedBox(height: 24),
          
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