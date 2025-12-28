import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';

class ValueTaskGenerationDialog extends StatefulWidget {
  final List<Map<String, dynamic>> generatedTasks;

  const ValueTaskGenerationDialog({super.key, required this.generatedTasks});

  @override
  State<ValueTaskGenerationDialog> createState() =>
      _ValueTaskGenerationDialogState();
}

class _ValueTaskGenerationDialogState extends State<ValueTaskGenerationDialog> {
  final List<bool> _selected = [];
  String? _selectedMainTaskId;

  @override
  void initState() {
    super.initState();
    _selected.addAll(List.filled(widget.generatedTasks.length, true));
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedMainTaskId =
        provider.selectedTaskId ?? provider.mainTasks.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Generated Tasks",
          style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Review actions suggested by AI to align with your values.",
                style: TextStyle(color: AppTheme.fhTextSecondary)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.generatedTasks.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = widget.generatedTasks[index];
                  return CheckboxListTile(
                    value: _selected[index],
                    onChanged: (val) {
                      setState(() => _selected[index] = val ?? false);
                    },
                    title: Text(task['name'],
                        style: const TextStyle(color: AppTheme.fhTextPrimary)),
                    subtitle: task['isCountable'] == true
                        ? Text("Count: ${task['targetCount']}",
                            style: const TextStyle(
                                color: AppTheme.fhTextSecondary))
                        : null,
                    activeColor: AppTheme.fhAccentTeal,
                    checkColor: AppTheme.fhBgDeepDark,
                    tileColor: AppTheme.fhBgDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedMainTaskId,
              decoration: const InputDecoration(
                labelText: "Add to Mission",
                filled: true,
                fillColor: AppTheme.fhBgDark,
              ),
              dropdownColor: AppTheme.fhBgDark,
              items: provider.mainTasks
                  .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedMainTaskId = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
          onPressed: _selectedMainTaskId == null
              ? null
              : () {
                  int count = 0;
                  for (int i = 0; i < widget.generatedTasks.length; i++) {
                    if (_selected[i]) {
                      provider.addSubtask(
                          _selectedMainTaskId!, widget.generatedTasks[i]);
                      count++;
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("$count tasks added to mission!")));
                  Navigator.pop(context);
                },
          child: const Text("Add Selected"),
        )
      ],
    );
  }
}
