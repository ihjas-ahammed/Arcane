import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/widgets/charts/wellbeing_pie_chart.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart';
import 'package:arcane/src/widgets/charts/weekly_line_charts.dart';
import 'package:arcane/src/widgets/ui/chart_carousel.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; 
import 'package:arcane/src/widgets/cards/tactical_briefing_card.dart';
import 'package:arcane/src/widgets/dialogs/weekly_report_dialog.dart';
import 'package:arcane/src/screens/nora_ai_screen.dart';
import 'package:arcane/src/screens/reflections_archive_screen.dart';
import 'package:arcane/src/screens/journaling/advanced_tools_screen.dart';
import 'package:arcane/src/screens/journaling/archived_reports_screen.dart';
import 'package:arcane/src/widgets/cards/start_day_report_card.dart'; 
import 'package:arcane/src/widgets/analytics/jwe_date_selector.dart';
import 'package:arcane/src/widgets/analytics/jwe_reflection_progress.dart';
import 'package:arcane/src/widgets/analytics/jwe_quick_access_grid.dart';
import 'package:arcane/src/widgets/dialogs/pin_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
    
    if (provider.settings.journalPin == null || provider.settings.journalPin!.isEmpty) {
      final newPin = await PinDialog.show(context: context, isSetupMode: true);
      if (newPin != null && newPin is String) {
        provider.setJournalPin(newPin);
        if (mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      }
    } else {
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
              primary: JweTheme.accentCyan,
              onPrimary: Colors.black,
              surface: JweTheme.panel,
              onSurface: JweTheme.textWhite,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: JweTheme.bgBase),
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
      final wellbeingDiff = provider.getWeeklyWellbeingComparison();
      final aiService = provider.aiService;
      
      final result = await aiService.generateWeeklyReport(
        logsText: data['logs'] as String,
        timeStatsText: data['times'] as String,
        wellbeingStatsText: wellbeingDiff,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => WeeklyReportDialog(
            reportData: result,
            onSave: () async {
              final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              await provider.saveWeeklyReport(dateStr, result);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weekly Report Saved to Archive!")));
                Navigator.pop(ctx);
              }
            },
          ),
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
        :[];

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                Text("DATABANKS", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                Row(
                  children:[
                    IconButton(
                      icon:  Icon(MdiIcons.archiveSearchOutline, color: JweTheme.accentCyan),
                      tooltip: "Archived Reports",
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedReportsScreen()));
                      },
                    ),
                    TextButton.icon(
                      icon: _isGeneratingWeeklyReport 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: JweTheme.accentAmber))
                        :  Icon(MdiIcons.fileChartOutline, size: 16),
                      label: const Text("WEEKLY REPORT", style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: JweTheme.accentAmber),
                      onPressed: _isGeneratingWeeklyReport ? null : () => _generateWeeklyReport(appProvider),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 1. 7-DAY PERFORMANCE (ChartCarousel)
            ChartCarousel(
              height: 250,
              pages:[
                ChartCarouselData(
                  title: "7-DAY PERFORMANCE",
                  chart: WeeklyActivityLineChart(
                    weeklyData: chartData['activityData'],
                    dominantColors: chartData['activityColors'],
                    isVirtue: false,
                  ),
                ),
                ChartCarouselData(
                  title: "WELL-BEING GROWTH",
                  chart: WeeklyVirtueLineChart(
                    weeklyXp: chartData['virtueData'],
                    dominantVirtueColors: chartData['virtueColors'],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            // 2. MISSION FOCUS & VIRTUE GROWTH PIE CHARTS
            Row(
              children:[
                Expanded(
                  child: JwePanel(
                    title: "MISSION FOCUS",
                    accentColor: JweTheme.accentCyan,
                    child: SizedBox(
                      height: 150,
                      child: TimePieChart(
                        taskData: chartData['dailyTaskTimeData'],
                        taskColors: chartData['taskColors'],
                        selectedTask: _selectedTaskFilter,
                        onTaskSelected: (val) => setState(() => _selectedTaskFilter = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: JwePanel(
                    title: "WELL-BEING",
                    accentColor: JweTheme.accentAmber,
                    child: SizedBox(
                      height: 150,
                      child: WellbeingPieChart(
                        logs: reflectionsForDate,
                        selectedVirtue: _selectedVirtueFilter,
                        onVirtueSelected: (val) => setState(() => _selectedVirtueFilter = val),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 3. INSPECT DATE
            JweDateSelector(
              dateStr: _selectedDate ?? 'TODAY',
              onTap: () => _pickDate(context)
            ),

            const SizedBox(height: 16),

            // 4. REFLECTION PROGRESS WIDGET
            JweReflectionProgress(
              logs: reflectionsForDate,
              dateStr: _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
            ),

            const SizedBox(height: 16),

            // 5. SYSTEM STARTUP REPORT
            if (startDayReport != null)
              StartDayReportCard(
                report: startDayReport,
                isRegenerating: _isGeneratingStartDay,
                onRegenerate: () => _generateStartDayReport(appProvider),
              )
            else if (isToday)
              ElevatedButton.icon(
                icon: _isGeneratingStartDay 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  :  Icon(MdiIcons.power, size: 18),
                label: Text("SYSTEM STARTUP REPORT", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JweTheme.accentCyan,
                  foregroundColor: Colors.black,
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isGeneratingStartDay ? null : () => _generateStartDayReport(appProvider),
              ),

            const SizedBox(height: 16),

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
              JwePanel(
                title: "TACTICAL BRIEFING",
                accentColor: JweTheme.accentAmber,
                child: Column(
                  children:[
                    const Text("NO BRIEFING INTEL AVAILABLE.", style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isGeneratingSummary 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: JweTheme.accentAmber, strokeWidth: 2))
                          :  Icon(MdiIcons.brain, size: 18),
                        label: Text(_isGeneratingSummary ? "ANALYZING..." : "GENERATE BRIEFING", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: JweTheme.accentAmber,
                          side: const BorderSide(color: JweTheme.accentAmber),
                          shape: const BeveledRectangleBorder(),
                        ),
                        onPressed: _isGeneratingSummary ? null : () => _generateTacticalBriefing(appProvider, reflectionsForDate),
                      ),
                    )
                  ],
                ),
              ),

            const SizedBox(height: 16),
            
            // 7. CLASSIFIED LOGS / QUICK ACCESS
            JweQuickAccessGrid(
              onArchive: () => _checkPinAndNavigate(context, const ReflectionsArchiveScreen()),
              onNora: () => _checkPinAndNavigate(context, const NoraAiScreen()),
              onAdvanced: () => _checkPinAndNavigate(context, const AdvancedToolsScreen()),
            ),
              
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}