import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/widgets/charts/wellbeing_pie_chart.dart';
import 'package:missions/src/widgets/charts/time_pie_chart.dart';
import 'package:missions/src/widgets/charts/weekly_line_charts.dart';
import 'package:missions/src/widgets/ui/chart_carousel.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/chart_data_helper.dart'; 
import 'package:missions/src/widgets/cards/tactical_briefing_card.dart';
import 'package:missions/src/screens/journaling/weekly_review_screen.dart';
import 'package:missions/src/screens/journaling/monthly_review_screen.dart';
import 'package:missions/src/screens/reflections_archive_screen.dart';
import 'package:missions/src/screens/journaling/advanced_tools_screen.dart';
import 'package:missions/src/screens/journaling/archived_reports_screen.dart';
import 'package:missions/src/widgets/cards/start_day_report_card.dart'; 
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:missions/src/widgets/analytics/jwe_date_selector.dart';
import 'package:missions/src/widgets/analytics/jwe_reflection_progress.dart';
import 'package:missions/src/widgets/analytics/jwe_quick_access_grid.dart';
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
  bool _isGeneratingMonthlyReport = false;
  bool _isGeneratingStartDay = false;
  
  String? _briefingStatus;
  String? _briefingError;
  String? _startupStatus;
  String? _startupError;
  String? _weeklyStatus;
  String? _monthlyStatus;
  
  Map<String, dynamic>? _tempGeneratedBriefing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedDate == null) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedDate = today;
    }
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
            colorScheme:   ColorScheme.dark(
              primary: JweTheme.accentCyan,
              onPrimary: JweTheme.onAccent,
              surface: JweTheme.panel,
              onSurface: JweTheme.textWhite,
            ),
            dialogTheme:  DialogThemeData(backgroundColor: JweTheme.bgBase),
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

  Future<bool> _checkTelemetryAndConfirm(AppProvider provider, String dateStr) async {
    final targetDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final healthLog = provider.healthLogs[dateStr];

    final hasMovement = healthLog != null &&
        healthLog.activityLogs.any((a) => a.walkDistanceKm > 0);
    final hasWorkout = healthLog != null &&
        healthLog.activityLogs.any((a) => a.workoutMinutes > 0);
    final hasActivity = hasMovement || hasWorkout;
    final hasOtherHealth = healthLog != null &&
        (healthLog.meals.isNotEmpty ||
            healthLog.sleepLogs.isNotEmpty ||
            healthLog.waterGlasses > 0);

    final hasFinance = provider.transactions.any((t) =>
        t.timestamp.year == targetDate.year &&
        t.timestamp.month == targetDate.month &&
        t.timestamp.day == targetDate.day);

    final missingItems = <Map<String, String>>[];
    if (!hasActivity) {
      missingItems.add({
        'title': 'HEALTH & ACTIVITY DATA',
        'desc': hasOtherHealth
            ? 'No movement (walking distance) or workout minutes logged for today.'
            : 'No health telemetry, movement, or workout logged for today.',
        'icon': 'activity',
      });
    }

    if (!hasFinance) {
      missingItems.add({
        'title': 'FINANCIAL INPUT',
        'desc': 'No income or expense transactions recorded for today.',
        'icon': 'finance',
      });
    }

    if (missingItems.isEmpty) return true;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentWarn, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: JweTheme.accentWarn, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MISSING DAILY TELEMETRY',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The following telemetry has not been recorded for $dateStr:',
                style: GoogleFonts.inter(
                  color: JweTheme.textMid,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ...missingItems.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: JweTheme.panel2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: JweTheme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          item['icon'] == 'finance'
                              ? MdiIcons.cashMultiple
                              : MdiIcons.runFast,
                          size: 16,
                          color: JweTheme.accentWarn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentWarn,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['desc']!,
                              style: GoogleFonts.inter(
                                color: JweTheme.textWhite,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Text(
                'Generating the daily briefing without this data will produce incomplete AI summaries and omit your physical and financial performance insights.',
                style: GoogleFonts.inter(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'LOG DATA FIRST',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentWarn,
                foregroundColor: JweTheme.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'PROCEED ANYWAY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );

    return proceed == true;
  }

  Future<void> _generateTacticalBriefing(
    AppProvider provider,
    List<ReflectionLog> logs, {
    bool bypassTelemetryCheck = false,
  }) async {
    if (_selectedDate == null) return;

    if (!bypassTelemetryCheck) {
      final canProceed = await _checkTelemetryAndConfirm(provider, _selectedDate!);
      if (!canProceed) return;
    }
    
    setState(() {
      _isGeneratingSummary = true;
      _briefingStatus = 'Synthesizing today\'s reflections and metrics...';
      _briefingError = null;
    });
    
    try {
      final briefingData = await provider.generateTacticalBriefing(
        _selectedDate!,
        logs,
        onStatusUpdate: (status) {
          if (mounted) setState(() => _briefingStatus = status);
        },
      );
      
      setState(() {
        _tempGeneratedBriefing = briefingData;
        _briefingError = null;
      });
      
    } catch (e) {
      if (mounted) {
        setState(() => _briefingError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: JweTheme.accentRed,
          content: Text("Briefing generation failed: $e"),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  void _showBriefingDialog(BuildContext context, BriefingType type, ValueGetter<String?> statusGetter) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return TacticalBriefingIndicator(
                type: type,
                statusMessage: statusGetter(),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _generateWeeklyReport(AppProvider provider) async {
    setState(() {
      _isGeneratingWeeklyReport = true;
      _weeklyStatus = 'Synthesizing 7-day performance telemetry...';
    });

    _showBriefingDialog(context, BriefingType.weekly, () => _weeklyStatus);

    try {
      final targetDate = _selectedDate != null
          ? DateTime.tryParse(_selectedDate!) ?? DateTime.now()
          : DateTime.now();
      final selectedDateStr = _selectedDate ?? DateFormat('yyyy-MM-dd').format(targetDate);

      final result = await provider.reportActions.generateWeeklyReport(
        targetDate,
        (status) {
          if (mounted) setState(() => _weeklyStatus = status);
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => WeeklyReviewScreen(
              reportData: result,
              provider: provider,
              targetDate: targetDate,
              onArchive: () async {
                await provider.saveWeeklyReport(selectedDateStr, result);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Weekly Review ($selectedDateStr) Saved to Archive!")));
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: JweTheme.accentRed,
          content: Text("Weekly Report failed: $e"),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingWeeklyReport = false);
    }
  }

  Future<void> _generateMonthlyReport(AppProvider provider) async {
    setState(() {
      _isGeneratingMonthlyReport = true;
      _monthlyStatus = 'Synthesizing 30-day monthly briefing...';
    });

    _showBriefingDialog(context, BriefingType.monthly, () => _monthlyStatus);

    try {
      final targetDate = _selectedDate != null
          ? DateTime.tryParse(_selectedDate!) ?? DateTime.now()
          : DateTime.now();
      final selectedDateStr = _selectedDate ?? DateFormat('yyyy-MM-dd').format(targetDate);

      final result = await provider.reportActions.generateMonthlyReport(
        targetDate,
        (status) {
          if (mounted) setState(() => _monthlyStatus = status);
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MonthlyReviewScreen(
              reportData: result,
              provider: provider,
              targetDate: targetDate,
              onArchive: () async {
                await provider.saveMonthlyReport(selectedDateStr, result);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Monthly Briefing ($selectedDateStr) Saved to Archive!")));
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: JweTheme.accentRed,
          content: Text("Monthly briefing failed: $e"),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingMonthlyReport = false);
    }
  }

  Future<void> _generateStartDayReport(AppProvider provider) async {
    setState(() {
      _isGeneratingStartDay = true;
      _startupStatus = 'Synthesizing system startup sequence...';
      _startupError = null;
    });
    try {
      await provider.reportActions.generateStartDayReport(
        onStatusUpdate: (status) {
          if (mounted) setState(() => _startupStatus = status);
        },
      );
      setState(() => _startupError = null);
    } catch (e) {
      if (mounted) {
        setState(() => _startupError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: JweTheme.accentRed,
          content: Text("Start Day Report failed: $e"),
        ));
      }
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 14.0 : (0 + MediaQuery.of(context).padding.bottom);

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, 14, 0, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // ── Hero header ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: HudPanel(
                clip: HudClip.both,
                accent: JweTheme.accentCyan,
                allBrackets: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(children: [
                   HudReticle(size: 22, color: JweTheme.accentCyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('// INTEL DATABANK',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8,
                          )),
                      const SizedBox(height: 3),
                      Text('DATABANKS',
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.0, height: 1,
                          )),
                    ]),
                  ),
                  _IconBtn(
                    icon: MdiIcons.archiveSearchOutline,
                    accent: JweTheme.accentCyan,
                    tooltip: 'ARCHIVE',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedReportsScreen())),
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: _isGeneratingWeeklyReport ? null : MdiIcons.fileChartOutline,
                    accent: JweTheme.accentAmber,
                    tooltip: 'WEEKLY REPORT',
                    loading: _isGeneratingWeeklyReport,
                    onTap: _isGeneratingWeeklyReport ? null : () => _generateWeeklyReport(appProvider),
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: _isGeneratingMonthlyReport ? null : MdiIcons.calendarMonthOutline,
                    accent: JweTheme.accentTeal,
                    tooltip: 'MONTHLY BRIEFING',
                    loading: _isGeneratingMonthlyReport,
                    onTap: _isGeneratingMonthlyReport ? null : () => _generateMonthlyReport(appProvider),
                  ),
                ]),
              ),
            ),

            // ── 7-DAY PERFORMANCE carousel ─────────────
            const HudSectionHead(
              label: 'TELEMETRY',
              code: '7-DAY',
              accent: HudTone.amber,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: ChartCarousel(
                height: 280,
                pages: [
                  ChartCarouselData(
                    title: '7-DAY PERFORMANCE',
                    tone: HudTone.amber,
                    chart: WeeklyActivityLineChart(
                      weeklyData: chartData['activityData'],
                      dominantColors: chartData['activityColors'],
                      isVirtue: false,
                    ),
                  ),
                  ChartCarouselData(
                    title: 'WELL-BEING GROWTH',
                    tone: HudTone.cyan,
                    chart: WeeklyVirtueLineChart(
                      weeklyXp: chartData['virtueData'],
                      dominantVirtueColors: chartData['virtueColors'],
                    ),
                  ),
                ],
              ),
            ),

            // ── Pie panels ─────────────────────────────
            const HudSectionHead(
              label: 'DISTRIBUTION',
              code: 'TODAY',
              accent: HudTone.cyan,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: HudPanel(
                    clip: HudClip.br,
                    accent: JweTheme.accentCyan,
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _PanelHeader(label: 'MISSION FOCUS', color: JweTheme.accentCyan),
                      Padding(
                        padding: const EdgeInsets.all(10),
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
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HudPanel(
                    clip: HudClip.br,
                    accent: JweTheme.accentAmber,
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _PanelHeader(label: 'WELL-BEING', color: JweTheme.accentAmber),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: SizedBox(
                          height: 150,
                          child: WellbeingPieChart(
                            logs: reflectionsForDate,
                            selectedVirtue: _selectedVirtueFilter,
                            onVirtueSelected: (val) => setState(() => _selectedVirtueFilter = val),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Inspect date ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: JweDateSelector(
                dateStr: _selectedDate ?? 'TODAY',
                onTap: () => _pickDate(context),
              ),
            ),

            // ── Reflection protocol ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: JweReflectionProgress(
                logs: reflectionsForDate,
                dateStr: _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
              ),
            ),

            // ── Startup report ─────────────────────────
            if (_isGeneratingStartDay)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TacticalBriefingIndicator(
                  type: BriefingType.startup,
                  statusMessage: _startupStatus,
                ),
              )
            else if (_startupError != null && startDayReport == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TacticalBriefingIndicator(
                  type: BriefingType.startup,
                  errorMessage: _startupError,
                  onRetry: () => _generateStartDayReport(appProvider),
                ),
              )
            else if (startDayReport != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: StartDayReportCard(
                  report: startDayReport,
                  isRegenerating: _isGeneratingStartDay,
                  onRegenerate: () => _generateStartDayReport(appProvider),
                ),
              )
            else if (isToday)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _HudActionBar(
                  label: 'SYSTEM STARTUP REPORT',
                  icon: MdiIcons.power,
                  accent: JweTheme.accentCyan,
                  loading: false,
                  onTap: () => _generateStartDayReport(appProvider),
                ),
              ),

            // ── Tactical briefing ──────────────────────
            const HudSectionHead(label: 'TACTICAL BRIEFING', code: 'AI', accent: HudTone.amber),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _isGeneratingSummary
                  ? TacticalBriefingIndicator(
                      type: BriefingType.daily,
                      statusMessage: _briefingStatus,
                    )
                  : _briefingError != null && displayBriefing == null
                      ? TacticalBriefingIndicator(
                          type: BriefingType.daily,
                          errorMessage: _briefingError,
                          onRetry: () => _generateTacticalBriefing(appProvider, reflectionsForDate),
                        )
                      : displayBriefing != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TacticalBriefingCard(
                                  briefingData: displayBriefing,
                                  isSaved: savedBriefing != null,
                                  date: _selectedDate != null ? DateTime.tryParse(_selectedDate!) : null,
                                  onSave: savedBriefing == null
                                      ? () {
                                          appProvider.saveTacticalBriefing(_selectedDate!, displayBriefing);
                                          setState(() {});
                                        }
                                      : null,
                                  onDeleteAndRetry: () async {
                                    if (_selectedDate != null) {
                                      final canProceed = await _checkTelemetryAndConfirm(appProvider, _selectedDate!);
                                      if (!canProceed) return;
                                      appProvider.deleteTacticalBriefing(_selectedDate!);
                                      await _generateTacticalBriefing(appProvider, reflectionsForDate, bypassTelemetryCheck: true);
                                    }
                                  },
                                ),
                              ],
                            )
                          : HudPanel(
                              clip: HudClip.br,
                              accent: JweTheme.accentAmber,
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Text('NO BRIEFING INTEL AVAILABLE',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 14),
                                _HudActionBar(
                                  label: '+ GENERATE BRIEFING',
                                  icon: MdiIcons.brain,
                                  accent: JweTheme.accentAmber,
                                  loading: false,
                                  onTap: () => _generateTacticalBriefing(appProvider, reflectionsForDate),
                                ),
                              ]),
                            ),
            ),

            if (startDayReport != null && startDayReport['task_snapshot'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TaskProgressSnapshotView(
                  taskSnapshot: startDayReport['task_snapshot'],
                  liveTasks: appProvider.mainTasks,
                ),
              ),

            // ── Classified access ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: JweQuickAccessGrid(
                onArchive: () => _navigateToScreen(context, const ReflectionsArchiveScreen()),
                onAdvanced: () => _navigateToScreen(context, const AdvancedToolsScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData? icon;
  final Color accent;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;
  const _IconBtn({this.icon, required this.accent, required this.tooltip, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;
    Widget child = Container(
      width: 34, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled ? JweTheme.lineSoft : accent.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.4, valueColor: AlwaysStoppedAnimation<Color>(accent)),
            )
          : Icon(icon, size: 16, color: disabled ? JweTheme.textMuted : accent),
    );
    if (onTap != null) child = InkWell(onTap: onTap, child: child);
    return Tooltip(message: tooltip, child: child);
  }
}

class _PanelHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _PanelHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.20))),
      ),
      child: Row(children: [
        Container(width: 3, height: 10, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.jetBrainsMono(
              color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6,
            )),
      ]),
    );
  }
}

class _HudActionBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool loading;
  final VoidCallback? onTap;

  const _HudActionBar({
    required this.label,
    required this.icon,
    required this.accent,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;
    return InkWell(
      onTap: onTap,
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6, valueColor: AlwaysStoppedAnimation<Color>(accent)),
              )
            else
              Icon(icon, size: 14, color: disabled ? JweTheme.textMuted : accent),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.saira(
                  color: disabled ? JweTheme.textMuted : accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                )),
          ]),
        ),
      ),
    );
  }
}