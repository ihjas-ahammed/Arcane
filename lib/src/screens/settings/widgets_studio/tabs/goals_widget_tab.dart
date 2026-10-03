import 'package:flutter/material.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_resolvers.dart';

class GoalsWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const GoalsWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<GoalsWidgetTab> createState() => _GoalsWidgetTabState();
}

class _GoalsWidgetTabState extends State<GoalsWidgetTab> {
  bool _overrideGoals = false;
  List<GoalModel> _mockGoals = [
    GoalModel(
      id: 'mock_1',
      title: 'COMPLETE SYSTEM ARCHITECTURE AUDIT',
      isCompleted: true,
      xpReward: 50,
      scope: GoalScope.daily,
    ),
    GoalModel(
      id: 'mock_2',
      title: 'NEURAL SYNC // REFLECTION SYNTHESIS',
      isCompleted: false,
      xpReward: 75,
      scope: GoalScope.daily,
      subChecklist: [
        GoalSubCheckItem(id: 's1', title: 'Review morning telemetry', isCompleted: true),
        GoalSubCheckItem(id: 's2', title: 'Analyze mission progress', isCompleted: false),
      ],
    ),
    GoalModel(
      id: 'mock_3',
      title: 'DEEP WORK FOCUS SESSION (60 MIN)',
      isCompleted: false,
      metricType: GoalMetricType.timeCounter,
      currentValue: 40,
      targetValue: 60,
      xpReward: 100,
      scope: GoalScope.daily,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final live = WidgetsStudioResolvers.resolveLiveGoals(widget.provider);
    final displayGoals = _overrideGoals ? _mockGoals : live.goals;
    final displayProgress = _overrideGoals
        ? (_mockGoals.where((g) => g.isCompleted).length / _mockGoals.length)
        : live.progress;
    final displayEarnedXp = _overrideGoals
        ? _mockGoals.where((g) => g.isCompleted).fold<int>(0, (sum, g) => sum + g.xpReward)
        : live.earnedXp;
    final displayTotalXp = _overrideGoals
        ? _mockGoals.fold<int>(0, (sum, g) => sum + g.xpReward)
        : live.totalXp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideGoals,
            child: Center(
              child: TodayGoalsHomeWidget(
                goals: displayGoals,
                progress: displayProgress,
                earnedXp: displayEarnedXp,
                totalXp: displayTotalXp,
                onGoalTap: (g) {
                  if (!_overrideGoals) {
                    widget.provider.toggleGoalCheck(g.id);
                  } else {
                    setState(() {
                      _mockGoals = _mockGoals.map((m) {
                        if (m.id == g.id) {
                          return m.copyWith(isCompleted: !m.isCompleted);
                        }
                        return m;
                      }).toList();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideGoals,
            onToggleOverride: (val) {
              setState(() => _overrideGoals = val);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TOGGLE TEST GOALS COMPLETION",
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                for (final g in _mockGoals)
                  CheckboxListTile(
                    title: Text(
                      g.title,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      "+${g.xpReward} XP",
                      style: const TextStyle(fontSize: 10, color: Colors.amber),
                    ),
                    value: g.isCompleted,
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        _mockGoals = _mockGoals.map((m) {
                          if (m.id == g.id) {
                            return m.copyWith(isCompleted: val ?? false);
                          }
                          return m;
                        }).toList();
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
