// lib/src/widgets/views/task_details_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/cards/submission_card.dart'; // Use new card
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskDetailsView extends StatefulWidget {
  const TaskDetailsView({super.key});

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView> {
  // ... AI Controllers remain for the generation section
  String _aiGenerationMode = 'text_list';
  final _aiUserInputController = TextEditingController();
  final _aiNumSubquestsController = TextEditingController(text: '3');

  late AppProvider appProvider;

  @override
  void initState() {
    super.initState();
    appProvider = Provider.of<AppProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _aiUserInputController.dispose();
    _aiNumSubquestsController.dispose();
    super.dispose();
  }

  void _handleAiGenerateSubquests(AppProvider appProvider, MainTask task) {
    if (_aiUserInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please provide input for the AI to generate sub-quests."),
            backgroundColor: AppTheme.fhAccentOrange),
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

  String _formatMinutesToHHMM(int totalMinutes) {
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProviderConsumer, child) {
        final task = appProviderConsumer.getSelectedTask();
        final theme = Theme.of(context);

        if (task == null) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(MdiIcons.textBoxSearchOutline,
                    size: 56, color: AppTheme.fhAccentTealFixed),
                const SizedBox(height: 16),
                Text('Select a Mission',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: AppTheme.fhAccentTealFixed)),
                const SizedBox(height: 8),
                Text(
                  'Details of the selected mission will appear here.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppTheme.fhTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ));
        }

        const double dailyGoalMinutes = 60.0;
        final double progress = task.dailyTimeSpent / dailyGoalMinutes;
        final timeSpentFormatted = _formatMinutesToHHMM(task.dailyTimeSpent);
        final weeklyCompletion =
            appProviderConsumer.getCompletionStatusForCurrentWeek(task);
        final int daysCompleted = weeklyCompletion.where((c) => c).length;
        final String streakText = daysCompleted >= 7
            ? "WEEKLY STREAK ACHIEVED"
            : "WEEKLY PROGRESS";

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: 8, bottom: 80, left: 10, right: 10), // Bottom padding for FAB if used
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- MAIN TASK HEADER CARD ---
              Card(
                color: AppTheme.fhBgMedium,
                margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: BorderSide(
                      color: AppTheme.fhBorderColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(MdiIcons.shieldOutline, color: task.taskColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${task.theme.toUpperCase()} PROTOCOL',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: (appProvider.getSelectedTask()?.taskColor ??
                                    AppTheme.fhAccentTealFixed),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(task.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppTheme.fhTextPrimary,
                              fontSize: 24,
                              fontFamily: AppTheme.fontDisplay,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(task.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 14,
                              height: 1.5)),
                      const SizedBox(height: 20),
                      // TIME PROGRESS BAR
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.fhBgDeepDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "TIME ELAPSED",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.fhTextSecondary,
                                      fontWeight: FontWeight.bold)),
                                Text(
                                  "$timeSpentFormatted / 01:00",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.fhTextPrimary,
                                      fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              height: 8,
                              decoration: const BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4)),
                                color: AppTheme.fhBgMedium,
                              ),
                              child: FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.fhAccentTeal.withValues(alpha: 0.7),
                                        AppTheme.fhAccentTeal,
                                      ],
                                    ),
                                    boxShadow: [BoxShadow(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // STREAK PANEL
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.fhBgDeepDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(streakText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.fhTextSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final isComplete =
                                    weeklyCompletion.length > index &&
                                        weeklyCompletion[index];
                                return Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isComplete ? AppTheme.fhAccentGold.withValues(alpha: 0.2) : Colors.transparent,
                                    border: Border.all(color: isComplete ? AppTheme.fhAccentGold : AppTheme.fhTextDisabled.withValues(alpha: 0.3))
                                  ),
                                  child: isComplete ?  Icon(MdiIcons.check, size: 16, color: AppTheme.fhAccentGold) : null,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: Text('Sub-Missions',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.w600)),
              ),

              // --- SUB-MISSIONS LIST (USING NEW CARD) ---
              if (task.subTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                      child: Text(
                          'No sub-missions recorded yet. Add some manually or use AI.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.fhTextSecondary.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: task.subTasks.length,
                  itemBuilder: (ctx, index) {
                    final st = task.subTasks[index];
                    return SubmissionCard(parentTask: task, subTask: st);
                  },
                ),

              // --- ADD / AI CARDS ---
              _buildAddNewSubTaskButton(context, appProviderConsumer, task),
              _buildAISubQuestCard(theme, appProviderConsumer, task),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddNewSubTaskButton(BuildContext context, AppProvider provider, MainTask task) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ElevatedButton.icon(
        icon: Icon(MdiIcons.plusBoxOutline),
        label: const Text("ADD NEW SUB-MISSION"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.fhBgMedium,
          foregroundColor: AppTheme.fhTextPrimary,
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.5))
        ),
        onPressed: () {
           // Simple dialog to add a subtask name
           showDialog(
             context: context,
             builder: (ctx) {
               final controller = TextEditingController();
               return AlertDialog(
                 backgroundColor: AppTheme.fhBgMedium,
                 title: const Text("New Sub-Mission"),
                 content: TextField(
                   controller: controller,
                   autofocus: true,
                   decoration: const InputDecoration(hintText: "Enter title..."),
                 ),
                 actions: [
                   TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
                   ElevatedButton(
                     onPressed: () {
                       if (controller.text.isNotEmpty) {
                         provider.addSubtask(task.id, {'name': controller.text.trim(), 'isCountable': false});
                         Navigator.pop(ctx);
                       }
                     },
                     child: const Text("Create")
                   )
                 ],
               );
             }
           );
        },
      ),
    );
  }

  Widget _buildAISubQuestCard(
      ThemeData theme, AppProvider appProviderConsumer, MainTask task) {
    return Card(
      color: AppTheme.fhBgMedium,
      margin: const EdgeInsets.only(top: 16, left: 0, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
            color: AppTheme.fhAccentPurple, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 Icon(MdiIcons.robotHappyOutline,
                    color: AppTheme.fhAccentPurple, size: 22),
                const SizedBox(width: 10),
                Text('Generate Sub-Missions with AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Generation Mode',
                  labelStyle:
                      TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody)),
              dropdownColor: AppTheme.fhBgMedium,
              value: _aiGenerationMode,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
              items: const [
                DropdownMenuItem(
                    value: 'text_list',
                    child: Text('From Text List / Outline')),
                DropdownMenuItem(
                    value: 'book_chapter',
                    child: Text('From Book Chapter/Section')),
                DropdownMenuItem(
                    value: 'general_plan',
                    child: Text('From General Plan/Goal')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _aiGenerationMode = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aiUserInputController,
              decoration: const InputDecoration(
                labelText: 'Your Input for AI...',
                alignLabelWithHint: true,
                labelStyle:
                    TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody),
              ),
              maxLines: null,
              minLines: 2,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aiNumSubquestsController,
              decoration: const InputDecoration(
                  labelText: 'Approx. # Sub-Missions',
                  labelStyle:
                      TextStyle(fontSize: 13, fontFamily: AppTheme.fontBody)),
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: AppTheme.fhTextPrimary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: appProviderConsumer.isGeneratingSubquests
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.fhBgDeepDark))
                  :  Icon(MdiIcons.creationOutline, size: 18),
              label: Text(appProviderConsumer.isGeneratingSubquests
                  ? 'GENERATING...'
                  : 'INITIATE AI PROTOCOL'),
              onPressed: appProviderConsumer.isGeneratingSubquests
                  ? null
                  : () => _handleAiGenerateSubquests(appProviderConsumer, task),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}