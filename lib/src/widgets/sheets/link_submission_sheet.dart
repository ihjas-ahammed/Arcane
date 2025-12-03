import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LinkSubmissionSheet extends StatefulWidget {
  const LinkSubmissionSheet({super.key});

  @override
  State<LinkSubmissionSheet> createState() => _LinkSubmissionSheetState();
}

class _LinkSubmissionSheetState extends State<LinkSubmissionSheet> {
  String? _selectedMainTaskId;
  String? _selectedProjectId;
  String? _selectedStepId;
  Project? _selectedProjectObj;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedMainTaskId = provider.selectedTaskId;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    // Filter projects based on selected main task
    final availableProjects = <Project>[];
    if (_selectedMainTaskId != null) {
      final task = provider.mainTasks.firstWhere((t) => t.id == _selectedMainTaskId);
      availableProjects.addAll(task.projects);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.fhBgDeepDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.fhTextSecondary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          Text("Add Submission to Mission", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Link a project step to a mission as a sub-task.", style: TextStyle(color: AppTheme.fhTextSecondary)),
          
          const SizedBox(height: 24),

          // 1. Choose Mission
          const Text("Choose Mission", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedMainTaskId,
            items: provider.mainTasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (val) {
               setState(() {
                 _selectedMainTaskId = val as String?;
                 _selectedProjectId = null;
                 _selectedStepId = null;
                 _selectedProjectObj = null;
               });
            }
          ),

          const SizedBox(height: 20),

          // 2. Select Project
          if (_selectedMainTaskId != null) ...[
            const Text("Select Project", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
             _buildDropdown(
              value: _selectedProjectId,
              items: availableProjects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title))).toList(),
              onChanged: (val) {
                 final proj = availableProjects.firstWhere((p) => p.id == val);
                 setState(() {
                   _selectedProjectId = val as String?;
                   _selectedProjectObj = proj;
                   _selectedStepId = null;
                 });
              }
            ),
          ],

          const SizedBox(height: 20),

          // 3. Select Step (Flattened for simplicity)
          if (_selectedProjectObj != null) ...[
            const Text("Select Project Step", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: _selectedProjectObj!.steps.length,
                itemBuilder: (context, index) {
                  final step = _selectedProjectObj!.steps[index];
                  final isSelected = _selectedStepId == step.id;
                  return ListTile(
                    title: Text(step.title, style: TextStyle(color: isSelected ? AppTheme.fhAccentTeal : AppTheme.fhTextPrimary)),
                    trailing: isSelected ?  Icon(MdiIcons.checkCircle, color: AppTheme.fhAccentTeal) :  Icon(MdiIcons.circleOutline, color: AppTheme.fhTextSecondary),
                    onTap: () => setState(() => _selectedStepId = step.id),
                  );
                },
              ),
            )
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedMainTaskId != null && _selectedStepId != null) 
                ? () {
                    // Find the actual step object
                    // Note: This only finds top-level steps for now based on the simplistic ListView above.
                    // Recursive lookup would be needed for deep steps.
                    final step = _selectedProjectObj!.steps.firstWhere((s) => s.id == _selectedStepId);
                    provider.projectActions.promoteStepToSubmission(_selectedMainTaskId!, step);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Linked successfully!")));
                }
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fhAccentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Link Submission", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown({required dynamic value, required List<DropdownMenuItem<Object>> items, required Function(Object?) onChanged}) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          borderRadius: BorderRadius.circular(12),
       ),
       child: DropdownButtonHideUnderline(
         child: DropdownButton(
           value: value,
           isExpanded: true,
           dropdownColor: AppTheme.fhBgDark,
           hint: const Text("Select...", style: TextStyle(color: AppTheme.fhTextSecondary)),
           items: items,
           onChanged: onChanged,
           style: const TextStyle(color: AppTheme.fhTextPrimary),
         ),
       ),
    );
  }
}