import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';

class ProjectGenerationDialog extends StatefulWidget {
  final String mainTaskId;
  const ProjectGenerationDialog({super.key, required this.mainTaskId});

  @override
  State<ProjectGenerationDialog> createState() => _ProjectGenerationDialogState();
}

class _ProjectGenerationDialogState extends State<ProjectGenerationDialog> {
  final TextEditingController _promptController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Generate Project with AI", style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Describe the project goal. The AI will break it down into recursive steps.", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "e.g., Build a personal website with portfolio and blog.",
              border: OutlineInputBorder()
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: provider.isGeneratingSubquests ? null : () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: provider.isGeneratingSubquests 
            ? null 
            : () async {
              if (_promptController.text.isNotEmpty) {
                // Using existing loading flag for simplicity, or create a new one
                await provider.projectActions.generateProjectStructure(widget.mainTaskId, _promptController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple),
          child: provider.isGeneratingSubquests 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text("Generate"),
        )
      ],
    );
  }
}