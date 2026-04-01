import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class DayPlanScreen extends StatefulWidget {
  const DayPlanScreen({super.key});

  @override
  State<DayPlanScreen> createState() => _DayPlanScreenState();
}

class _DayPlanScreenState extends State<DayPlanScreen> {
  List<String> _currentPlan = [];
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      _currentPlan = provider.taskActions.getDayPlan(helper.getTodayDateString());
      _isInit = false;
    }
  }

  void _savePlan() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.taskActions.updateDayPlan(helper.getTodayDateString(), _currentPlan);
    Navigator.pop(context);
  }

  void _addToPlan(String compoundId) {
    if (!_currentPlan.contains(compoundId)) {
      setState(() {
        _currentPlan.add(compoundId);
        // Auto-remove any child checkpoints if the parent subtask was just added
        final parts = compoundId.split('|');
        if (parts.length == 2) {
           _currentPlan.removeWhere((item) {
             final p = item.split('|');
             return p.length == 3 && p[0] == parts[0] && p[1] == parts[1];
           });
        }
      });
    }
  }

  void _removeFromPlan(String compoundId) {
    setState(() => _currentPlan.remove(compoundId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final currentPlanSet = _currentPlan.toSet();

    // Build available list
    List<Widget> availableWidgets = [];
    final activeTasks = provider.mainTasks.where((t) => t.isActive).toList(); // Only active
    
    for (var task in activeTasks) {
      final activeSubs = task.subTasks.where((s) => !s.completed).toList();
      if (activeSubs.isEmpty) continue;

      List<Widget> taskWidgets = [];

      for (var sub in activeSubs) {
        final subId = "${task.id}|${sub.id}";
        final activeCheckpoints = sub.subSubTasks.where((c) => !c.completed).toList();
        final allCheckpointIds = activeCheckpoints.map((c) => "$subId|${c.id}").toList();

        bool isSubtaskInPlan = currentPlanSet.contains(subId);
        bool allCheckpointsInPlan = activeCheckpoints.isNotEmpty && allCheckpointIds.every((id) => currentPlanSet.contains(id));

        // 1. Add SubTask itself if not in plan AND not all its checkpoints are already queued
        if (!isSubtaskInPlan && !allCheckpointsInPlan) {
          taskWidgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark.withOpacity(0.5),
                border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: Icon(MdiIcons.targetAccount, color: task.taskColor, size: 20),
                title: Text(sub.name, style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 14)),
                trailing: const Icon(Icons.add, color: AppTheme.fhAccentTeal),
                onTap: () => _addToPlan(subId),
              ),
            )
          );
        }

        // 2. Add Checkpoints inside the SubTask ONLY if parent SubTask is NOT queued
        if (!isSubtaskInPlan) {
          for (var cp in activeCheckpoints) {
            final cpId = "$subId|${cp.id}";
            if (!currentPlanSet.contains(cpId)) {
              taskWidgets.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 8, left: 24), // Indent checkpoints
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withOpacity(0.3),
                    border: Border(left: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5), width: 2)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(MdiIcons.rhombusOutline, color: AppTheme.fhTextSecondary, size: 16),
                    title: Text(cp.name, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13)),
                    trailing: const Icon(Icons.add, color: AppTheme.fhAccentTeal, size: 18),
                    onTap: () => _addToPlan(cpId),
                  ),
                )
              );
            }
          }
        }
      }

      if (taskWidgets.isNotEmpty) {
        availableWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4),
            child: Text(task.name.toUpperCase(), style: TextStyle(color: task.taskColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
          )
        );
        availableWidgets.addAll(taskWidgets);
      }
    }

    return Scaffold(
      backgroundColor: PersonInfoTheme.bgDark,
      appBar: AppBar(
        title: Text("STARTUP PLAN MAKER", style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PersonInfoTheme.textWhite),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.fhAccentGreen),
            onPressed: _savePlan,
            tooltip: "Save Plan",
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selected Plan (Reorderable)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: PersonInfoTheme.bgPanel,
                    child: Text("TODAY'S QUEUE", style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                  ),
                  Expanded(
                    child: _currentPlan.isEmpty
                      ? const Center(child: Text("QUEUE EMPTY", style: TextStyle(color: AppTheme.fhTextDisabled)))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _currentPlan.length,
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) newIndex -= 1;
                            setState(() {
                              final item = _currentPlan.removeAt(oldIndex);
                              _currentPlan.insert(newIndex, item);
                            });
                          },
                          proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                          itemBuilder: (context, index) {
                            final compId = _currentPlan[index];
                            final parts = compId.split('|');
                            if (parts.length < 2) return const SizedBox.shrink();
                            
                            final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
                            final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
                            
                            if (task == null || sub == null) return SizedBox.shrink(key: ValueKey(compId));

                            final isCheckpoint = parts.length == 3;
                            String title = sub.name;
                            String subtitle = task.name;
                            IconData leadingIcon = MdiIcons.targetAccount;

                            if (isCheckpoint) {
                              final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
                              if (cp == null) return SizedBox.shrink(key: ValueKey(compId));
                              title = cp.name;
                              subtitle = "${task.name} > ${sub.name}";
                              leadingIcon = MdiIcons.rhombusOutline;
                            }

                            return Container(
                              key: ValueKey(compId),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: PersonInfoTheme.bgPanel,
                                border: Border(left: BorderSide(color: task.taskColor, width: 4)),
                              ),
                              child: ListTile(
                                leading: Icon(leadingIcon, color: task.taskColor, size: 20),
                                title: Text(title, style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(subtitle, style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppTheme.fhAccentRed, size: 18),
                                      onPressed: () => _removeFromPlan(compId),
                                    ),
                                    const Icon(Icons.drag_handle, color: AppTheme.fhTextSecondary, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  )
                ],
              ),
            ),
            
            Container(height: 2, color: PersonInfoTheme.spideyRed.withOpacity(0.5)),

            // Available Tasks
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: PersonInfoTheme.bgPanel,
                    child: Text("AVAILABLE MISSIONS", style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: availableWidgets,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}