import 'package:flutter/material.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_resolvers.dart';
import '../widgets_studio_sync.dart';

class DayPlanWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const DayPlanWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<DayPlanWidgetTab> createState() => _DayPlanWidgetTabState();
}

class _DayPlanWidgetTabState extends State<DayPlanWidgetTab> {
  bool _overrideDayPlan = false;
  String _dayPlanCapacity = "2h40 / 4h30";
  List<String> _customDayPlanTasks = [
    "DESIGN NEURAL ARCHITECTURE",
    "SECURITY AUDIT SUITE",
    "QUANTUM TELEMETRY REVIEW",
    "REFLECTIONS & LOG SYNTHESIS",
    "DEPLOY ARCANE ENGINE",
  ];
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final today = helper.getTodayDateString();
    final livePlanTasks = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: widget.provider.mainTasks,
      plan: widget.provider.taskActions.getDayPlan(today),
    );
    final liveTask = WidgetsStudioResolvers.resolveLiveTask(widget.provider);
    final liveCapacity = liveTask.capacity.isNotEmpty
        ? liveTask.capacity
        : (livePlanTasks.isNotEmpty ? "${livePlanTasks.length} ITEMS" : "");

    final List<ResolvedDayPlanItem> displayTasks;
    if (_overrideDayPlan) {
      displayTasks = List.generate(
        _customDayPlanTasks.length,
        (i) => ResolvedDayPlanItem(
          compoundId: 'custom-plan-$i',
          name: _customDayPlanTasks[i],
          parentName: 'TACTICAL DISPATCH // 0${i + 1}',
          color: i == 0 ? JweTheme.accentCyan : JweTheme.accentAmber,
          mainTaskId: 'm$i',
          subTaskId: 's$i',
          isRunning: false,
          totalCheckpoints: 2,
          completedCheckpoints: 0,
          durationMinutes: 30,
        ),
      );
    } else {
      displayTasks = livePlanTasks;
    }

    final capacity = _overrideDayPlan ? _dayPlanCapacity : liveCapacity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideDayPlan,
            child: Center(
              child: DayPlanHomeWidget(
                tasks: displayTasks,
                capacity: capacity,
                progress: liveTask.progress,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StudioActionButtons(
            syncLabel: "SYNC PLAN WIDGET",
            isSyncing: _isSyncing,
            onSync: () async {
              setState(() => _isSyncing = true);
              await WidgetsStudioSync.pushTaskToAndroid(liveTask, context: context);
              if (mounted) setState(() => _isSyncing = false);
            },
            onPin: () => WidgetsStudioSync.pinWidget(
              context,
              HomeWidgetService.instance.requestPinDayPlan,
              "Day Plan Widget",
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideDayPlan,
            onToggleOverride: (val) {
              setState(() {
                _overrideDayPlan = val;
                if (val && livePlanTasks.isNotEmpty) {
                  _customDayPlanTasks = livePlanTasks.map((t) => t.name).toList();
                  while (_customDayPlanTasks.length < 5) {
                    _customDayPlanTasks.add("TASK 0${_customDayPlanTasks.length + 1}");
                  }
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudioTextField(
                  label: "Capacity Text",
                  initialValue: _dayPlanCapacity,
                  onChanged: (val) => setState(() => _dayPlanCapacity = val),
                ),
                const SizedBox(height: 12),
                Text(
                  "Custom Plan Tasks (Top 5):",
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < 5; i++) ...[
                  StudioTextField(
                    label: "Item ${i + 1}",
                    initialValue: i < _customDayPlanTasks.length ? _customDayPlanTasks[i] : "",
                    onChanged: (val) {
                      setState(() {
                        while (_customDayPlanTasks.length <= i) {
                          _customDayPlanTasks.add("");
                        }
                        _customDayPlanTasks[i] = val;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
