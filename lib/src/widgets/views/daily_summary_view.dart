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
import 'package:arcane/src/utils/helpers.dart';
import 'package:arcane/src/utils/chart_data_helper.dart'; // Import helper
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:collection/collection.dart';

class DailySummaryView extends StatefulWidget {
  const DailySummaryView({super.key});

  @override
  State<DailySummaryView> createState() => _DailySummaryViewState();
}

class _DailySummaryViewState extends State<DailySummaryView> {
  String? _selectedDate;
  bool _isLoading = false;
  String? _selectedTaskFilter;
  String? _selectedVirtueFilter;

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
              onDelete: () {},
              onSave: (val) {},
            ));
  }

  Future<void> _generateDailySummary() async {
    if (_selectedDate == null) return;

    setState(() => _isLoading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final aiService = Provider.of<AIService>(context, listen: false);

      final targetDate = DateTime.parse(_selectedDate!);
      final dailyLogs = appProvider.reflectionLogs.where((l) {
        return l.timestamp.year == targetDate.year &&
            l.timestamp.month == targetDate.month &&
            l.timestamp.day == targetDate.day;
      }).toList();

      if (dailyLogs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("No reflections to summarize for this day.")));
        }
        return;
      }

      final summary = await aiService.generateDailySummary(
        reflections: dailyLogs
            .map((l) => {
                  'trigger': l.trigger,
                  'emotion': l.emotion,
                  'reason': l.reason,
                })
            .toList(),
        modelCandidates: appProvider.settings.liteModels,
        currentApiKeyIndex: appProvider.apiKeyIndex,
        onNewApiKeyIndex: appProvider.setProviderApiKeyIndex,
        onLog: (s) => (s),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.fhBgDark,
          title: const Text("Daily Summary",
              style: TextStyle(color: AppTheme.fhTextPrimary)),
          content: SingleChildScrollView(
              child: Text(summary,
                  style: const TextStyle(color: AppTheme.fhTextSecondary))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to generate summary: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    final availableDates = appProvider.completedByDay.keys.toList();
    availableDates.sort((a, b) => b.compareTo(a));

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
        if (mounted && _selectedDate != null) {
          setState(() => _selectedDate = null);
        }
      });
    }

    // Use Helper to prepare data
    final chartData = ChartDataHelper.prepareWeeklyData(
      appProvider, 
      _selectedDate, 
      _selectedTaskFilter, 
      _selectedVirtueFilter
    );

    final summaryData = _selectedDate != null
        ? appProvider.completedByDay[_selectedDate!]
        : null;

    Map<String, dynamic> taskTimes = {};
    if (_selectedDate != null &&
        _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      final today = DateTime.now();
      for (var task in appProvider.mainTasks) {
        final val = ChartDataHelper.calculateDailyTimeFromSessions(task, today); // Exposed in helper if needed or copy logic back if private
        if (val > 0) {
          taskTimes[task.id] = val;
        }
      }
    } else {
      taskTimes = summaryData?['taskTimes'] as Map<String, dynamic>? ?? {};
    }
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
                  final dates = availableDates.map((d) => DateTime.parse(d)).toList();
                  dates.sort();
                  final firstDate = dates.first;
                  final initialDate = _selectedDate != null ? DateTime.parse(_selectedDate!) : dates.last;

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: firstDate.subtract(const Duration(days: 365)),
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
                          dialogTheme: DialogThemeData(backgroundColor: AppTheme.fhBgDark),
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
                        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(_selectedDate!))
                        : 'Select a date',
                    style: const TextStyle(color: AppTheme.fhTextPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- DAILY STATS CAROUSEL ---
              ChartCarousel(
                height: 320,
                pages: [
                  ChartCarouselData(
                    title: "Daily Virtue Breakdown",
                    chart: VirtuePieChart(
                      logs: reflectionsForDate,
                      selectedVirtue: _selectedVirtueFilter,
                      onVirtueSelected: (val) {
                        setState(() => _selectedVirtueFilter = val);
                      },
                    ),
                  ),
                  ChartCarouselData(
                    title: "Today's Mission Focus",
                    chart: TimePieChart(
                      taskData: chartData['dailyTaskTimeData'],
                      taskColors: chartData['taskColors'],
                      selectedTask: _selectedTaskFilter,
                      onTaskSelected: (val) {
                        setState(() => _selectedTaskFilter = val);
                      },
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
          Row(
            children: [
              IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(MdiIcons.robotHappyOutline,
                          color: AppTheme.fhAccentGold),
                  tooltip: "Generate Daily Summary",
                  onPressed: _isLoading ? null : _generateDailySummary),
              const SizedBox(width: 8),
              Text("Reflections", style: theme.textTheme.headlineSmall),
            ],
          ),
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
}
// Note: _calculateDailyTimeFromSessions inside chart_data_helper was made static publicly, but inside here I relied on it being private or imported?
// I added `ChartDataHelper.calculateDailyTimeFromSessions` in the helper but didn't rename the usage in `build`.
// The code `ChartDataHelper.calculateDailyTimeFromSessions` was used in `build`.
// The private `_calculateDailyTimeFromSessions` inside view was removed/not used.
// Double check the helper file content I generated. I named it `_calculateDailyTimeFromSessions` (private) in the helper class...
// I should fix the helper file generation to make it public if I use it here, or duplicate it.
// I will regenerate the helper file content to be public.