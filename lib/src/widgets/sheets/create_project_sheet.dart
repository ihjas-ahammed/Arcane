import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({super.key});

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedMainTaskId;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    // Default to currently selected task, or first available
    _selectedMainTaskId = provider.selectedTaskId ?? provider.mainTasks.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

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
          
          Text("Create New Project", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // Project Name
          const Text("Project Name", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "e.g., Develop AI Prompt System",
              filled: true,
              fillColor: AppTheme.fhBgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          
          const SizedBox(height: 20),

           // Mission Selector
          const Text("Link to Mission (Optional)", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
             ),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: _selectedMainTaskId,
                 isExpanded: true,
                 dropdownColor: AppTheme.fhBgDark,
                 items: provider.mainTasks.map((task) {
                   return DropdownMenuItem(
                     value: task.id,
                     child: Text(task.name, style: const TextStyle(color: AppTheme.fhTextPrimary)),
                   );
                 }).toList(),
                 onChanged: (val) => setState(() => _selectedMainTaskId = val),
               ),
             ),
          ),
          
          const SizedBox(height: 20),
          
          // Description
          const Text("Description", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Briefly describe your project goals...",
              filled: true,
              fillColor: AppTheme.fhBgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          
          const Spacer(),
          
          // Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _selectedMainTaskId != null) {
                  provider.projectActions.addProject(
                    _nameController.text, 
                    _descController.text,
                    mainTaskId: _selectedMainTaskId
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2), // Matching the blue/purple gradient vibe
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Create Project", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}