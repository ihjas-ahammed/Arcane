import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/widgets/cards/submission_card.dart';
import 'package:missions/src/widgets/cards/task_header_card.dart';
import 'package:missions/src/widgets/ui/completed_submissions_section.dart';
import 'package:missions/src/widgets/ui/recurring_completed_section.dart';
import 'package:missions/src/widgets/ui/inactive_submissions_section.dart';
import 'package:missions/src/widgets/dialogs/initialize_action_plan_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_edit_protocol_dialog.dart';
import 'package:missions/src/widgets/dialogs/jwe_task_options_dialog.dart';
import 'package:missions/src/widgets/ui/jwe_drawer_protocol_item.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class TaskDetailsView extends StatefulWidget {
  const TaskDetailsView({super.key});

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView> {
  final List<Map<String, dynamic>> _availableThemes = [
    {'name': 'tech', 'icon': MdiIcons.memory, 'color': AppTheme.fhAccentTealFixed},
    {'name': 'knowledge', 'icon': MdiIcons.bookOpenPageVariantOutline, 'color': AppTheme.fhAccentPurple},
    {'name': 'learning', 'icon': MdiIcons.schoolOutline, 'color': AppTheme.fhAccentOrange},
    {'name': 'discipline', 'icon': MdiIcons.karate, 'color': AppTheme.fhAccentRed},
    {'name': 'order', 'icon': MdiIcons.playlistCheck, 'color': AppTheme.fhAccentGreen},
    {'name': 'health', 'icon': MdiIcons.heartPulse, 'color': const Color(0xFF58D68D)},
    {'name': 'finance', 'icon': MdiIcons.cashMultiple, 'color': const Color(0xFFF1C40F)},
    {'name': 'creative', 'icon': MdiIcons.paletteOutline, 'color': const Color(0xFFEC7063)},
    {'name': 'exploration', 'icon': MdiIcons.mapSearchOutline, 'color': const Color(0xFF5DADE2)},
    {'name': 'social', 'icon': MdiIcons.accountGroupOutline, 'color': const Color(0xFFE59866)},
    {'name': 'nature', 'icon': MdiIcons.treeOutline, 'color': const Color(0xFF2ECC71)},
    {'name': 'general', 'icon': MdiIcons.targetAccount, 'color': AppTheme.fhTextSecondary},
  ];

  IconData _getThemeIcon(String? themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => _availableThemes.last)['icon'] as IconData;
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return const AddEditProtocolDialog();
      },
    );
  }

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

  Widget _buildProtocolSelector({
    required BuildContext context,
    required AppProvider appProvider,
    required MainTask? selectedTask,
    required List<MainTask> activeTasks,
    required List<MainTask> inactiveTasks,
  }) {
    final allTasks = [...activeTasks, ...inactiveTasks];
    final showDeployCard = allTasks.length % 2 != 0;
    final gridCount = showDeployCard ? allTasks.length + 1 : allTasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Container(width: 4, height: 12, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Text(
                'OPERATIONAL SYSTEM PROTOCOLS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showAddTaskDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.plus, size: 12, color: JweTheme.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      'DEPLOY',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Animated Hero (active protocol) in first row
        if (selectedTask != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: TaskHeaderCard(
              key: ValueKey(selectedTask.id),
              task: selectedTask,
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 8) / 2;
              const desiredHeight = 96.0;
              final childAspectRatio = cellWidth / desiredHeight;

              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: gridCount,
                itemBuilder: (context, index) {
                  if (showDeployCard && index == allTasks.length) {
                    // Add Deploy Protocol Button Card
                    return InkWell(
                      onTap: () => _showAddTaskDialog(context),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: JweTheme.lineAmber.withValues(alpha: 0.3), width: 1.0, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(2.0),
                          color: JweTheme.bgDeep.withValues(alpha: 0.2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.plus, size: 18, color: JweTheme.accentAmber.withValues(alpha: 0.7)),
                            const SizedBox(height: 4),
                            Text(
                              'DEPLOY AGENT',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentAmber.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final task = allTasks[index];
                  final isSelected = selectedTask?.id == task.id;

                  return JweDrawerProtocolItem(
                    task: task,
                    isSelected: isSelected,
                    icon: _getThemeIcon(task.theme),
                    onTap: () => appProvider.setSelectedTaskId(task.id),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => JweTaskOptionsDialog(task: task),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final activeTasks = appProvider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
        final inactiveTasks = appProvider.mainTasks.where((t) => !t.isActive && !t.isDeleted).toList();
        final allTasks = [...activeTasks, ...inactiveTasks];

        if (allTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.targetAccount, size: 48, color: JweTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  'NO OPERATIONAL PROTOCOLS DEPLOYED',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(MdiIcons.plus, color: JweTheme.accentAmber),
                  label: Text('DEPLOY PROTOCOL', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: JweTheme.lineAmber),
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: () => _showAddTaskDialog(context),
                ),
              ],
            ),
          );
        }

        final MainTask? selectedTask = appProvider.getSelectedTask();
        MainTask? task = selectedTask;
        // If the selected task is deleted or inactive, auto select the first available active task
        if (task == null || task.isDeleted) {
          final firstValid = activeTasks.firstOrNull ?? inactiveTasks.firstOrNull;
          if (firstValid != null) {
            task = firstValid;
            // Schedule setting selected task ID in next frame to avoid build-phase state updates
            WidgetsBinding.instance.addPostFrameCallback((_) {
              appProvider.setSelectedTaskId(firstValid.id);
            });
          }
        }

        final MainTask currentTask = task!;

        final activeSubtasks = currentTask.subTasks.where((st) => !st.completed && st.isActive && !st.isDeleted).toList();
        final inactiveSubtasks = currentTask.subTasks.where((st) => !st.completed && !st.isActive && !st.isDeleted).toList();
        
        final completedRecurring = currentTask.subTasks.where((st) => st.completed && st.isRecurring && !st.isDeleted).toList();
        final completedArchived = currentTask.subTasks.where((st) => st.completed && !st.isRecurring && !st.isDeleted).toList();

        final theme = Theme.of(context);

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
                _buildProtocolSelector(
                  context: context,
                  appProvider: appProvider,
                  selectedTask: currentTask,
                  activeTasks: activeTasks,
                  inactiveTasks: inactiveTasks,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 16, color: currentTask.taskColor),
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
                        onPressed: () => _showAddActionPlanDialog(context, appProvider, currentTask),
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
                      border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),
                      color: AppTheme.fhBgDark.withValues(alpha: 0.3)
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
                          onPressed: () => _showAddActionPlanDialog(context, appProvider, currentTask),
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
                      appProvider.taskActions.reorderSubtasksBySubset(currentTask.id, list.map((e) => e.id).toList());
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
                      return SubmissionCard(key: ValueKey(st.id), parentTask: currentTask, subTask: st);
                    },
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: InactiveSubmissionsSection(parentTask: currentTask, inactiveSubtasks: inactiveSubtasks),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: RecurringCompletedSection(parentTask: currentTask, completedSubtasks: completedRecurring),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: CompletedSubmissionsSection(parentTask: currentTask, completedSubtasks: completedArchived),
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