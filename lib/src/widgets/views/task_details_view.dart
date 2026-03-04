import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/widgets/cards/submission_card.dart';
import 'package:arcane/src/widgets/cards/task_header_card.dart';
import 'package:arcane/src/widgets/ui/completed_submissions_section.dart';
import 'package:arcane/src/widgets/ui/recurring_completed_section.dart';
import 'package:arcane/src/widgets/dialogs/initialize_action_plan_dialog.dart';
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
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
        'subSubTasksData': [] // Empty How/Steps initially
      });

      // Get created task to pass to details
      final updatedTask = provider.mainTasks.firstWhere((t) => t.id == task.id);
      final newSubTask = updatedTask.subTasks.firstWhere((s) => s.id == newId);

      // Navigate to details to finish What/How
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

        if (task == null) {
          return const Center(child: Text('NO PROTOCOL SELECTED'));
        }

        final weeklyCompletion = appProvider.getCompletionStatusForCurrentWeek(task);
        final int yesterdayTime = appProvider.getYesterdaysTimeForTask(task.id);

        final activeSubtasks = task.subTasks.where((st) => !st.completed).toList();
        
        // Split completed tasks into recurring (cooldown) and archived (one-time)
        final completedRecurring = task.subTasks.where((st) => st.completed && st.isRecurring).toList();
        final completedArchived = task.subTasks.where((st) => st.completed && !st.isRecurring).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8, bottom: 80, left: 10, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaskHeaderCard(
                task: task,
                yesterdayTime: yesterdayTime,
                weeklyCompletion: weeklyCompletion,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                child: Row(
                  children: [
                    Container(width: 4, height: 16, color: task.taskColor),
                    const SizedBox(width: 8),
                    Text('ACTIVE ACTION PLANS',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: AppTheme.fontDisplay,
                            color: AppTheme.fhTextPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0
                        )),
                  ],
                ),
              ),

              if (activeSubtasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
                    color: AppTheme.fhBgDark.withOpacity(0.3)
                  ),
                  child: const Text(
                      'ALL ACTION PLANS COMPLETED.\nINITIATE NEW PLAN BELOW.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, letterSpacing: 0.5)
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeSubtasks.length,
                  onReorder: (oldIndex, newIndex) {
                    appProvider.reorderSubtasks(task.id, oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, index) {
                    final st = activeSubtasks[index];
                    return SubmissionCard(key: ValueKey(st.id), parentTask: task, subTask: st);
                  },
                ),

              // Recurring Completed Section
              RecurringCompletedSection(parentTask: task, completedSubtasks: completedRecurring),

              // Archived (One-time) Section
              CompletedSubmissionsSection(parentTask: task, completedSubtasks: completedArchived),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(MdiIcons.plus, size: 18),
                  label: const Text("INITIALIZE ACTION PLAN"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhBgDark,
                      foregroundColor: AppTheme.fhAccentTeal,
                      minimumSize: const Size(double.infinity, 48),
                      shape: const BeveledRectangleBorder(),
                      side: BorderSide(color: AppTheme.fhAccentTeal.withOpacity(0.5))),
                  onPressed: () => _showAddActionPlanDialog(context, appProvider, task),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}