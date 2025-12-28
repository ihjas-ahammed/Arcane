import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/ui/saved_prompts_list.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AiPromptsView extends StatefulWidget {
  const AiPromptsView({super.key});

  @override
  State<AiPromptsView> createState() => _AiPromptsViewState();
}

class _AiPromptsViewState extends State<AiPromptsView> {
  final TextEditingController _promptController = TextEditingController();
  String? _selectedMainTaskId;

  final List<Map<String, String>> _templates = [
    {
      "title": "Health & Fitness",
      "prompt":
          "Create a 4-week structured plan to improve cardiovascular health for a beginner, including daily activities and milestones."
    },
    {
      "title": "Creative Writing",
      "prompt":
          "Outline a project for writing a short sci-fi story. Steps should include world-building, character design, drafting, and editing."
    },
    {
      "title": "Coding & Tech",
      "prompt":
          "Build a roadmap to learn Python for data analysis in 30 days. Include setup, syntax basics, pandas, and a final capstone project."
    },
    {
      "title": "Home Org",
      "prompt":
          "Generate a step-by-step plan to declutter and organize a home office, broken down by zone (desk, files, shelves)."
    }
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedMainTaskId =
        provider.selectedTaskId ?? provider.mainTasks.firstOrNull?.id;
  }

  void _saveCurrentPrompt(AppProvider provider) {
    if (_promptController.text.trim().isEmpty) return;
    
    final currentPrompts = List<String>.from(provider.settings.savedPrompts);
    final newPrompt = _promptController.text.trim();
    
    if (!currentPrompts.contains(newPrompt)) {
      currentPrompts.add(newPrompt);
      provider.setSettings(provider.settings..savedPrompts = currentPrompts);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prompt Saved!"), backgroundColor: AppTheme.fhAccentGreen)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("AI Prompts"),
        backgroundColor: AppTheme.fhBgDeepDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text("Describe your project idea...",
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppTheme.fhTextSecondary)),
            const SizedBox(height: 12),

            // Text Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _promptController,
                    maxLines: 5,
                    decoration: const InputDecoration.collapsed(
                      hintText:
                          "e.g., 'Learn Python in 90 days with a focus on web development.'",
                      hintStyle: TextStyle(color: AppTheme.fhTextSecondary),
                    ),
                    style: const TextStyle(color: AppTheme.fhTextPrimary),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(MdiIcons.contentSaveOutline, size: 16),
                      label: const Text("Save Prompt"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.fhTextSecondary,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap
                      ),
                      onPressed: () => _saveCurrentPrompt(provider),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Task Selector for AI Generation
            DropdownButtonFormField<String>(
              initialValue: _selectedMainTaskId,
              dropdownColor: AppTheme.fhBgDark,
              decoration: InputDecoration(
                labelText: "Assign to Mission",
                fillColor: AppTheme.fhBgDark,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              items: provider.mainTasks
                  .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedMainTaskId = val),
            ),

            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isGeneratingSubquests
                    ? null
                    : () async {
                        if (_promptController.text.isNotEmpty &&
                            _selectedMainTaskId != null) {
                          try {
                            await provider.projectActions
                                .generateProjectStructure(_selectedMainTaskId!,
                                    _promptController.text);
                            if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Project Generated! Check your projects list."))
                              );
                            }
                          } finally {
                            // Close loading dialog if applicable, provider handles state
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: provider.isGeneratingSubquests 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Generate Project Plan",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),
            Text("Prompt Templates",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Templates Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final t = _templates[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _promptController.text = t['prompt']!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.fhBorderColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['title']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            t['prompt']!,
                            style: const TextStyle(
                                color: AppTheme.fhTextSecondary, fontSize: 12),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            // Saved Prompts Section
            SavedPromptsList(
              onSelect: (prompt) => setState(() => _promptController.text = prompt),
            ),
          ],
        ),
      ),
    );
  }
}
