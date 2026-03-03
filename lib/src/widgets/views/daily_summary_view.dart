import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/charts/virtue_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; 
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/cards/tactical_briefing_card.dart';
import 'package:arcane/src/widgets/dialogs/weekly_report_dialog.dart';
import 'package:arcane/src/screens/nora_ai_screen.dart';
import 'package:arcane/src/screens/reflections_archive_screen.dart';
import 'package:arcane/src/screens/journaling/advanced_tools_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/cards/start_day_report_card.dart'; 
import 'package:arcane/src/widgets/ui/reflection_progress_widget.dart';
import 'package:arcane/src/widgets/dialogs/pin_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

  Future<void> _checkPinAndNavigate(BuildContext context, Widget screen) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // If PIN is not set, prompt setup
    if (provider.settings.journalPin == null || provider.settings.journalPin!.isEmpty) {
      final newPin = await PinDialog.show(context: context, isSetupMode: true);
      if (newPin != null && newPin is String) {
        provider.setJournalPin(newPin);
        if (mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      }
    } else {
      // Verify PIN
      final success = await PinDialog.show(context: context, isSetupMode: false, expectedPin: provider.settings.journalPin);
      if (success == true && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      }
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
      await provider.reportActions.generateStartDayReport();
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
              TextButton.icon(
                icon: _isGeneratingWeeklyReport 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(MdiIcons.fileChartOutline, size: 16),
                label: const Text("WEEKLY REPORT", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.fhAccentGold),
                onPressed: _isGeneratingWeeklyReport ? null : () => _generateWeeklyReport(appProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 1. 7-DAY PERFORMANCE (ChartCarousel)
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
          
          // 2. MISSION FOCUS & VIRTUE GROWTH PIE CHARTS
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

          // 3. INSPECT DATE
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

          // 4. REFLECTION PROGRESS WIDGET
          ReflectionProgressWidget(
            logs: reflectionsForDate,
            dateStr: _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ),

          const SizedBox(height: 24),

          // 5. SYSTEM STARTUP REPORT
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

          // 6. TACTICAL BRIEFING SECTION
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
          
          // 7. CLASSIFIED LOGS
          const Text("CLASSIFIED LOGS", style: TextStyle(color: AppTheme.fhTextSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(
                 child: ValorantButton(
                   label: "ARCHIVE",
                   icon: MdiIcons.lockOutline,
                   isPrimary: false,
                   color: AppTheme.fhAccentTeal.withOpacity(0.3),
                   onPressed: () => _checkPinAndNavigate(context, const ReflectionsArchiveScreen()),
                 )
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: ValorantButton(
                   label: "NORA AI",
                   icon: MdiIcons.brain,
                   isPrimary: false,
                   color: AppTheme.fhAccentPurple.withOpacity(0.3),
                   onPressed: () => _checkPinAndNavigate(context, const NoraAiScreen()),
                 )
               ),
            ],
          ),
          
          const SizedBox(height: 12),
          SizedBox(
             width: double.infinity,
             child: ValorantButton(
               label: "ADVANCED PROTOCOLS",
               icon: MdiIcons.hexagonMultipleOutline,
               isPrimary: false,
               color: AppTheme.fhAccentPurple.withOpacity(0.1),
               onPressed: () => _checkPinAndNavigate(context, const AdvancedToolsScreen()),
             )
           ),
            
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}