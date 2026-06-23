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
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/screens/journaling/weekly_review_screen.dart';
import 'package:missions/src/screens/reflections_archive_screen.dart';
import 'package:missions/src/screens/journaling/advanced_tools_screen.dart';
import 'package:missions/src/screens/journaling/archived_reports_screen.dart';
import 'package:missions/src/widgets/cards/start_day_report_card.dart'; 
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';
import 'package:missions/src/widgets/analytics/jwe_date_selector.dart';
import 'package:missions/src/widgets/analytics/jwe_reflection_progress.dart';
import 'package:missions/src/widgets/analytics/jwe_quick_access_grid.dart';
import 'package:missions/src/widgets/dialogs/pin_dialog.dart';
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

  String _buildFinanceWeekContext(AppProvider provider) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    double weekIncome = 0, weekExpense = 0;
    for (final t in provider.transactions) {
      if (t.timestamp.isAfter(weekAgo)) {
        if (t.isIncome) weekIncome += t.amount; else weekExpense += t.amount;
      }
    }
    final balance = provider.financeActions.currentBalance;
    return 'Week Income: ₹${weekIncome.toStringAsFixed(0)}, Expense: ₹${weekExpense.toStringAsFixed(0)}, Net: ₹${(weekIncome - weekExpense).toStringAsFixed(0)}, Balance: ₹${balance.toStringAsFixed(0)}';
  }

  String _buildAgentProgressContext(AppProvider provider) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final buf = StringBuffer();
    for (final task in provider.mainTasks.where((t) => !t.isDeleted && t.isActive).take(4)) {
      int weekSec = 0;
      int completedSubs = 0;
      final activeSubs = task.subTasks.where((s) => !s.isDeleted && s.isActive).toList();
      for (final sub in activeSubs) {
        if (sub.completed) completedSubs++;
        for (final sess in sub.sessions) {
          if (sess.startTime.isAfter(weekAgo)) weekSec += sess.durationSeconds;
        }
      }
      buf.writeln('${task.name}: ${(weekSec / 3600).toStringAsFixed(1)}h this week, $completedSubs/${activeSubs.length} subtasks done');
    }
    return buf.toString();
  }

  Future<void> _generateWeeklyReport(AppProvider provider) async {
    setState(() => _isGeneratingWeeklyReport = true);
    try {
      final data = provider.getLast7DaysData();
      final wellbeingDiff = provider.getWeeklyWellbeingComparison();
      final aiService = provider.aiService;
      final financeContext = _buildFinanceWeekContext(provider);
      final agentContext = _buildAgentProgressContext(provider);

      final result = await aiService.generateWeeklyReport(
        logsText: data['logs'] as String,
        timeStatsText: data['times'] as String,
        wellbeingStatsText: wellbeingDiff,
        financeText: financeContext,
        agentProgressText: agentContext,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
        writingStyleMap: provider.settings.adaptWritingStyle ? provider.settings.writingStyleMap : null,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => WeeklyReviewScreen(
              reportData: result,
              onArchive: () async {
                final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                await provider.saveWeeklyReport(dateStr, result);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weekly Review Saved to Archive!")));
                }
              },
            ),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 14.0 : (0 + MediaQuery.of(context).padding.bottom);

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: SingleChildScrollView(
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
                  const HudReticle(size: 22, color: JweTheme.accentCyan),
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
            if (startDayReport != null)
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
                  loading: _isGeneratingStartDay,
                  onTap: _isGeneratingStartDay ? null : () => _generateStartDayReport(appProvider),
                ),
              ),

            // ── Tactical briefing ──────────────────────
            const HudSectionHead(label: 'TACTICAL BRIEFING', code: 'AI', accent: HudTone.amber),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: displayBriefing != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TacticalBriefingCard(
                          briefingData: displayBriefing,
                          isSaved: savedBriefing != null,
                          onSave: savedBriefing == null
                              ? () {
                                  appProvider.saveTacticalBriefing(_selectedDate!, displayBriefing);
                                  setState(() {});
                                }
                              : null,
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
                          label: _isGeneratingSummary ? 'ANALYZING…' : '+ GENERATE BRIEFING',
                          icon: MdiIcons.brain,
                          accent: JweTheme.accentAmber,
                          loading: _isGeneratingSummary,
                          onTap: _isGeneratingSummary ? null : () => _generateTacticalBriefing(appProvider, reflectionsForDate),
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
                onArchive: () => _checkPinAndNavigate(context, const ReflectionsArchiveScreen()),
                onAdvanced: () => _checkPinAndNavigate(context, const AdvancedToolsScreen()),
              ),
            ),
          ],
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