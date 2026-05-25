import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/widgets/cards/submission_card.dart';
import 'package:missions/src/widgets/cards/task_header_card.dart';
import 'package:missions/src/widgets/ui/completed_submissions_section.dart';
import 'package:missions/src/widgets/ui/recurring_completed_section.dart';
import 'package:missions/src/widgets/ui/inactive_submissions_section.dart';
import 'package:missions/src/widgets/dialogs/initialize_action_plan_dialog.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskDetailsView extends StatefulWidget {
  const TaskDetailsView({super.key});

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView> {

  void _showAddActionPlanDialog(BuildContext context, AppProvider provider, MainTask task) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const InitializeActionPlanDialog(),
    );

    if (result != null && mounted) {
      final name = result['name']!;
      final why = result['why']!;
      
      // Create new subtask
      final newId = provider.addSubtask(task.id, {
        'name': name,
        'why': why,
        'isCountable': false,
        'subSubTasksData': [],
        'isActive': true,
      });

      final updatedTask = provider.mainTasks.firstWhere((t) => t.id == task.id);
      final newSubTask = updatedTask.subTasks.firstWhere((s) => s.id == newId);

      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => SubmissionDetailScreen(parentTask: updatedTask, subTask: newSubTask))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final task = appProvider.getSelectedTask();
        final theme = Theme.of(context);

        if (task == null || task.isDeleted) {
          return const Center(child: Text('NO PROTOCOL SELECTED'));
        }

        final weeklyCompletion = appProvider.getCompletionStatusForCurrentWeek(task);
        final int yesterdayTime = appProvider.getYesterdaysTimeForTask(task.id);

        final activeSubtasks = task.subTasks.where((st) => !st.completed && st.isActive && !st.isDeleted).toList();
        final inactiveSubtasks = task.subTasks.where((st) => !st.completed && !st.isActive && !st.isDeleted).toList();
        
        final completedRecurring = task.subTasks.where((st) => st.completed && st.isRecurring && !st.isDeleted).toList();
        final completedArchived = task.subTasks.where((st) => st.completed && !st.isRecurring && !st.isDeleted).toList();

        return RefreshIndicator(
          color: AppTheme.fhAccentTeal,
          backgroundColor: AppTheme.fhBgDark,
          onRefresh: () async {
            await appProvider.performManualSync();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 0, bottom: 80, left: 0, right: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskHeaderCard(
                  task: task,
                  yesterdayTime: yesterdayTime,
                  weeklyCompletion: weeklyCompletion,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 16, color: task.taskColor),
                          const SizedBox(width: 8),
                          Text('ACTIVE TASKS',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: AppTheme.fontDisplay,
                                  color: AppTheme.fhTextPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0
                              )),
                        ],
                      ),
                      IconButton(
                        icon: Icon(MdiIcons.plus, color: AppTheme.fhAccentTeal),
                        onPressed: () => _showAddActionPlanDialog(context, appProvider, task),
                        tooltip: "New Contract",
                      )
                    ],
                  ),
                ),

                if (activeSubtasks.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
                      color: AppTheme.fhBgDark.withOpacity(0.3)
                    ),
                    child: Column(
                      children: [
                        const Text(
                            'NO ACTIVE TASKS',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, letterSpacing: 0.5)
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showAddActionPlanDialog(context, appProvider, task),
                          child: const Text("INITIALIZE NEW CONTRACT", style: TextStyle(color: AppTheme.fhAccentTeal)),
                        )
                      ],
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    itemCount: activeSubtasks.length,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final list = List<SubTask>.from(activeSubtasks);
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      appProvider.taskActions.reorderSubtasksBySubset(task.id, list.map((e) => e.id).toList());
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 5,
                        shadowColor: Colors.black,
                        child: child,
                      );
                    },
                    itemBuilder: (ctx, index) {
                      final st = activeSubtasks[index];
                      return SubmissionCard(key: ValueKey(st.id), parentTask: task, subTask: st);
                    },
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: InactiveSubmissionsSection(parentTask: task, inactiveSubtasks: inactiveSubtasks),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: RecurringCompletedSection(parentTask: task, completedSubtasks: completedRecurring),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: CompletedSubmissionsSection(parentTask: task, completedSubtasks: completedArchived),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}