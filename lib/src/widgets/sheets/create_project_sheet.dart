import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/valorant/valorant_text_field.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_dropdown.dart';
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

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, 
            right: 24, 
            top: 24, 
            bottom: MediaQuery.of(context).viewInsets.bottom + 24
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(width: 4, height: 24, color: AppTheme.fhAccentRed),
                    const SizedBox(width: 12),
                    Text(
                      "INITIATE PROJECT", 
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppTheme.fhTextPrimary
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Mission Selector
                ValorantDropdown<String>(
                  label: "LINK TO MISSION",
                  value: _selectedMainTaskId,
                  items: provider.mainTasks.map((task) {
                    return DropdownMenuItem(
                      value: task.id,
                      child: Text(task.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMainTaskId = val),
                ),
                
                const SizedBox(height: 24),
                
                // Project Name
                ValorantTextField(
                  controller: _nameController,
                  label: "PROJECT CODENAME",
                  hint: "e.g. OPERATION PHOENIX",
                  autofocus: true,
                ),
                
                const SizedBox(height: 24),
                
                // Description
                ValorantTextField(
                  controller: _descController,
                  label: "BRIEFING / OBJECTIVES",
                  hint: "Describe the primary goal...",
                  maxLines: 3,
                ),
                
                const SizedBox(height: 40),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ValorantButton(
                        label: "ABORT",
                        isPrimary: false,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ValorantButton(
                        label: "DEPLOY",
                        isPrimary: true,
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
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}