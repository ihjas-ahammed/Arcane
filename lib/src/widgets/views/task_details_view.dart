import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/widgets/cards/submission_card.dart';
import 'package:arcane/src/widgets/cards/task_header_card.dart';
import 'package:arcane/src/widgets/ui/completed_submissions_section.dart';
import 'package:arcane/src/widgets/ui/recurring_completed_section.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskDetailsView extends StatefulWidget {
  const TaskDetailsView({super.key});

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView> {
  String _aiGenerationMode = 'text_list';
  final _aiUserInputController = TextEditingController();
  final _aiNumSubquestsController = TextEditingController(text: '3');
  final _newSubTaskController = TextEditingController();

  void _handleAiGenerateSubquests(AppProvider appProvider, MainTask task) {
    if (_aiUserInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide input for the AI."), backgroundColor: AppTheme.fhAccentOrange),
      );
      return;
    }
    appProvider.triggerAISubquestGeneration(
        task,
        _aiGenerationMode,
        _aiUserInputController.text.trim(),
        int.tryParse(_aiNumSubquestsController.text) ?? 3);
    _aiUserInputController.clear();
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
                    Text('ACTIVE SUB-MISSIONS',
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
                      'ALL SUB-MISSIONS COMPLETED.\nLOG NEW ACTIVITY BELOW.',
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

              _buildAddNewSubTaskButton(context, appProvider, task),
              _buildAISubQuestCard(theme, appProvider, task),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddNewSubTaskButton(BuildContext context, AppProvider provider, MainTask task) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        children: [
          TextField(
            controller: _newSubTaskController,
            decoration: const InputDecoration(
              hintText: "NEW SUB-MISSION TITLE...",
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.fhTextSecondary),
              filled: true,
              border: OutlineInputBorder(borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(fontSize: 14, color: AppTheme.fhTextPrimary),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                provider.addSubtask(task.id, {'name': value.trim(), 'isCountable': false});
                _newSubTaskController.clear();
              }
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: Icon(MdiIcons.plus, size: 18),
            label: const Text("ADD OBJECTIVE"),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fhBgDark,
                foregroundColor: AppTheme.fhAccentTeal,
                minimumSize: const Size(double.infinity, 44),
                shape: const BeveledRectangleBorder(),
                side: BorderSide(color: AppTheme.fhAccentTeal.withOpacity(0.5))),
            onPressed: () {
              if (_newSubTaskController.text.trim().isNotEmpty) {
                provider.addSubtask(task.id, {
                  'name': _newSubTaskController.text.trim(),
                  'isCountable': false
                });
                _newSubTaskController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAISubQuestCard(ThemeData theme, AppProvider appProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgDark.withOpacity(0.5),
      margin: const EdgeInsets.only(top: 24),
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: AppTheme.fhAccentPurple, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.creation, color: AppTheme.fhAccentPurple, size: 20),
                const SizedBox(width: 10),
                const Text('AI GENERATION PROTOCOL',
                    style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 14
                    )),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aiUserInputController,
              decoration: const InputDecoration(
                labelText: 'INPUT PARAMETERS',
                labelStyle: TextStyle(fontSize: 11, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0),
                hintText: "e.g. 'Read chapters 1-3 of Design Patterns'",
                hintStyle: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                filled: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'MODE',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelStyle: TextStyle(fontSize: 11, fontFamily: AppTheme.fontDisplay)
                    ),
                    dropdownColor: AppTheme.fhBgMedium,
                    initialValue: _aiGenerationMode,
                    style: const TextStyle(fontSize: 12, color: AppTheme.fhTextPrimary),
                    items: const [
                      DropdownMenuItem(value: 'text_list', child: Text('List')),
                      DropdownMenuItem(value: 'book_chapter', child: Text('Chapter')),
                      DropdownMenuItem(value: 'general_plan', child: Text('General')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _aiGenerationMode = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _aiNumSubquestsController,
                    decoration: const InputDecoration(
                        labelText: 'COUNT',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelStyle: TextStyle(fontSize: 11, fontFamily: AppTheme.fontDisplay)
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, color: AppTheme.fhTextPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: appProviderConsumer.isGeneratingSubquests
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(MdiIcons.check, size: 16),
              label: Text(appProviderConsumer.isGeneratingSubquests ? 'PROCESSING...' : 'EXECUTE'),
              onPressed: appProviderConsumer.isGeneratingSubquests
                  ? null
                  : () => _handleAiGenerateSubquests(appProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentPurple,
                  foregroundColor: Colors.white,
                  shape: const BeveledRectangleBorder(),
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }
}