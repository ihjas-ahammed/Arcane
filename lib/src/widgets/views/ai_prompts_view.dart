import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/ui/saved_prompts_list.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

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
      "title": "HEALTH & FITNESS",
      "prompt":
          "Create a 4-week structured plan to improve cardiovascular health for a beginner, including daily activities and milestones."
    },
    {
      "title": "CREATIVE WRITING",
      "prompt":
          "Outline a project for writing a short sci-fi story. Steps should include world-building, character design, drafting, and editing."
    },
    {
      "title": "CODING & TECH",
      "prompt":
          "Build a roadmap to learn Python for data analysis in 30 days. Include setup, syntax basics, pandas, and a final capstone project."
    },
    {
      "title": "HOME ORGANIZATION",
      "prompt":
          "Generate a step-by-step plan to declutter and organize a home office, broken down by zone (desk, files, shelves)."
    }
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedMainTaskId =
        provider.selectedTaskId ?? provider.mainTasks.where((t) => !t.isDeleted).firstOrNull?.id;
  }

  void _saveCurrentPrompt(AppProvider provider) {
    if (_promptController.text.trim().isEmpty) return;

    final currentPrompts = List<String>.from(provider.settings.savedPrompts);
    final newPrompt = _promptController.text.trim();

    if (!currentPrompts.contains(newPrompt)) {
      currentPrompts.add(newPrompt);
      provider.setSettings(provider.settings..savedPrompts = currentPrompts);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Prompt Saved!"),
          backgroundColor: AppTheme.fhAccentGreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("AI PROTOCOLS"),
        backgroundColor: AppTheme.fhBgDeepDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(MdiIcons.consoleLine, color: AppTheme.fhAccentTeal),
                const SizedBox(width: 8),
                Text("INPUT PARAMETERS",
                    style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.fhTextPrimary)),
              ],
            ),
            const SizedBox(height: 12),

            // Text Input (Valorant Style)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                border: Border.all(color: AppTheme.fhBorderColor),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _promptController,
                    maxLines: 5,
                    decoration: const InputDecoration.collapsed(
                      hintText:
                          "DEFINE MISSION PARAMETERS...\ne.g., 'Learn Python in 90 days with a focus on web development.'",
                      hintStyle: TextStyle(color: AppTheme.fhTextSecondary, fontStyle: FontStyle.italic),
                    ),
                    style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: 'RobotoMono', fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _saveCurrentPrompt(provider),
                      child: Text("[ SAVE PROMPT ]", style: TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 10)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Task Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedMainTaskId,
              dropdownColor: AppTheme.fhBgDark,
              decoration: InputDecoration(
                labelText: "ASSIGN TO PROTOCOL",
                fillColor: AppTheme.fhBgDark,
                filled: true,
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.fhBorderColor)),
              ),
              items: provider.mainTasks.where((t) => !t.isDeleted)
                  .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _selectedMainTaskId = val),
            ),

            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: provider.isGeneratingSubquests ? "PROCESSING..." : "EXECUTE GENERATION",
                isPrimary: true,
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
                                  const SnackBar(
                                      content: Text(
                                          "PROJECT STRUCTURE GENERATED. CHECK PROJECTS TAB.")));
                            }
                          } finally {
                            //
                          }
                        }
                      },
              ),
            ),

            const SizedBox(height: 40),
            
            Text("TEMPLATES",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay)),
            const SizedBox(height: 16),

            // Templates Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
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
                      border: Border.all(
                          color: AppTheme.fhBorderColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['title']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.fhAccentTeal)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            t['prompt']!,
                            style: const TextStyle(
                                color: AppTheme.fhTextSecondary, fontSize: 11),
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
              onSelect: (prompt) =>
                  setState(() => _promptController.text = prompt),
            ),
          ],
        ),
      ),
    );
  }
}