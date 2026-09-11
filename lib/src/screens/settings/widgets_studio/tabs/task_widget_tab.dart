import 'package:flutter/material.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_models.dart';
import '../widgets_studio_resolvers.dart';
import '../widgets_studio_sync.dart';

class TaskWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const TaskWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<TaskWidgetTab> createState() => _TaskWidgetTabState();
}

class _TaskWidgetTabState extends State<TaskWidgetTab> {
  bool _overrideTask = false;
  String _taskTitle = "DESIGN NEURAL ARCHITECTURE";
  String _taskSubtitle = "OPERATIONAL PROTOCOL // DEEP WORK";
  String _taskCapacity = "2h40 / 4h30";
  double _taskProgress = 0.65;
  bool _taskIsRunning = true;
  final bool _taskIsCheckpoint = false;
  final int _taskAccumulatedSeconds = 1800;
  int _taskMultitaskCount = 1;
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final live = WidgetsStudioResolvers.resolveLiveTask(widget.provider);
    final title = _overrideTask ? _taskTitle : live.title;
    final subtitle = _overrideTask ? _taskSubtitle : live.subtitle;
    final isRunning = _overrideTask ? _taskIsRunning : live.isRunning;
    final isCheckpoint = _overrideTask ? _taskIsCheckpoint : live.isCheckpoint;
    final accumulated = _overrideTask ? _taskAccumulatedSeconds : live.accumulatedSeconds;
    final progress = _overrideTask ? _taskProgress : live.progress;
    final capacity = _overrideTask ? _taskCapacity : live.capacity;

    final List<ResolvedDayPlanItem> previewMultitask;
    if (_overrideTask) {
      if (_taskMultitaskCount > 1) {
        previewMultitask = [
          ResolvedDayPlanItem(
            compoundId: 'test-1',
            name: _taskTitle,
            parentName: 'PRIMARY PROTOCOL',
            color: Colors.cyan,
            mainTaskId: 'm1',
            subTaskId: 's1',
            isRunning: _taskIsRunning,
            totalCheckpoints: 3,
            completedCheckpoints: 1,
            durationMinutes: 45,
          ),
          ResolvedDayPlanItem(
            compoundId: 'test-2',
            name: 'SYSTEM RECON & TELEMETRY',
            parentName: 'ARCANE CORE',
            color: Colors.amber,
            mainTaskId: 'm2',
            subTaskId: 's2',
            isRunning: false,
            totalCheckpoints: 0,
            completedCheckpoints: 0,
            durationMinutes: 30,
          ),
          if (_taskMultitaskCount >= 3)
            ResolvedDayPlanItem(
              compoundId: 'test-3',
              name: 'SECURITY AUDIT // SUITE',
              parentName: 'CYBERPUNK OPS',
              color: Colors.purple,
              mainTaskId: 'm3',
              subTaskId: 's3',
              isRunning: false,
              totalCheckpoints: 4,
              completedCheckpoints: 2,
              durationMinutes: 20,
            ),
        ];
      } else {
        previewMultitask = const [];
      }
    } else {
      previewMultitask = live.multitaskTasks;
    }

    final currentData = TaskWidgetData(
      hasTask: _overrideTask ? true : live.hasTask,
      title: title,
      subtitle: subtitle,
      isRunning: isRunning,
      isCheckpoint: isCheckpoint,
      accumulatedSeconds: accumulated,
      progress: progress,
      capacity: capacity,
      multitaskTasks: previewMultitask,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideTask,
            child: Center(
              child: RunningTaskHomeWidget(
                hasTask: _overrideTask ? true : live.hasTask,
                title: title,
                subtitle: subtitle,
                isRunning: isRunning,
                isCheckpoint: isCheckpoint,
                accumulatedSeconds: accumulated,
                progress: progress,
                capacity: capacity,
                multitaskTasks: previewMultitask,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StudioActionButtons(
            syncLabel: "SYNC TASK WIDGET",
            isSyncing: _isSyncing,
            onSync: () async {
              setState(() => _isSyncing = true);
              await WidgetsStudioSync.pushTaskToAndroid(currentData, context: context);
              if (mounted) setState(() => _isSyncing = false);
            },
            onPin: () => WidgetsStudioSync.pinWidget(
              context,
              HomeWidgetService.instance.requestPinTask,
              "Active Task Widget",
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideTask,
            onToggleOverride: (val) {
              setState(() {
                _overrideTask = val;
                if (val) {
                  _taskTitle = live.title;
                  _taskSubtitle = live.subtitle;
                  _taskIsRunning = live.isRunning;
                  _taskProgress = live.progress;
                  _taskCapacity = live.capacity;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text("Is Active / Running", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _taskIsRunning,
                  activeTrackColor: JweTheme.accentAmber,
                  onChanged: (val) => setState(() => _taskIsRunning = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Mission Title",
                  initialValue: _taskTitle,
                  onChanged: (val) => setState(() => _taskTitle = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Subtitle / Checkpoint",
                  initialValue: _taskSubtitle,
                  onChanged: (val) => setState(() => _taskSubtitle = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Capacity String",
                  initialValue: _taskCapacity,
                  onChanged: (val) => setState(() => _taskCapacity = val),
                ),
                const SizedBox(height: 12),
                Text("Progress: ${(_taskProgress * 100).toStringAsFixed(0)}%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _taskProgress,
                  min: 0.0,
                  max: 1.0,
                  activeColor: JweTheme.accentAmber,
                  onChanged: (v) => setState(() => _taskProgress = v),
                ),
                const SizedBox(height: 12),
                Text("Multitask Layout Mode", style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text("1 Task", style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 2, label: Text("2 Tasks", style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 3, label: Text("3 Tasks", style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_taskMultitaskCount},
                  onSelectionChanged: (set) => setState(() => _taskMultitaskCount = set.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
