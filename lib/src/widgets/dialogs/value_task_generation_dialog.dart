import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/task_generation_row.dart';
import 'package:provider/provider.dart';

class ValueTaskGenerationDialog extends StatefulWidget {
  final List<Map<String, dynamic>> generatedTasks;

  const ValueTaskGenerationDialog({super.key, required this.generatedTasks});

  @override
  State<ValueTaskGenerationDialog> createState() =>
      _ValueTaskGenerationDialogState();
}

class _ValueTaskGenerationDialogState extends State<ValueTaskGenerationDialog> {
  final List<Map<String, dynamic>> _finalTasksConfig = [];
  String? _defaultMainTaskId;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _defaultMainTaskId =
        provider.selectedTaskId ?? provider.mainTasks.firstOrNull?.id;

    // Initialize config list
    for (var task in widget.generatedTasks) {
      _finalTasksConfig.add({}); // Will be populated by row callbacks
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Dialog(
      backgroundColor: AppTheme.fhBgDeepDark,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
            ),
            child: const Text("TACTICAL INTEGRATION",
                style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppTheme.fhTextPrimary)),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Configure generated actions and assign them to active protocols.",
                      style: TextStyle(color: AppTheme.fhTextSecondary)),
                  const SizedBox(height: 16),
                  ...widget.generatedTasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final taskData = entry.value;
                    return TaskGenerationRow(
                      taskData: taskData,
                      availableMissions: provider.mainTasks,
                      defaultMissionId: _defaultMainTaskId,
                      onChanged: (config) {
                        _finalTasksConfig[index] = config;
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.fhBorderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL")),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentTeal,
                      foregroundColor: AppTheme.fhBgDeepDark),
                  onPressed: () {
                    int count = 0;
                    for (var config in _finalTasksConfig) {
                      if (config['isSelected'] == true &&
                          config['missionId'] != null) {
                        final missionId = config['missionId'] as String;
                        final name = config['name'] as String;
                        final isCountable =
                            config['isCountable'] as bool? ?? false;
                        final targetCount =
                            config['targetCount'] as int? ?? 0;

                        if (config['type'] == 'Task') {
                          // Add as SubTask
                          provider.addSubtask(missionId, {
                            'name': name,
                            'isCountable': isCountable,
                            'targetCount': targetCount,
                          });
                          count++;
                        } else if (config['type'] == 'Checkpoint' &&
                            config['parentId'] != null) {
                          // Add as SubSubTask
                          provider.addSubSubtask(
                              missionId, config['parentId'] as String, {
                            'name': name,
                            'isCountable': isCountable,
                            'targetCount': targetCount,
                          });
                          count++;
                        }
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("$count actions integrated!")));
                    Navigator.pop(context);
                  },
                  child: const Text("INTEGRATE"),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
