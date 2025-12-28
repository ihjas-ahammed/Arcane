import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_dropdown.dart';
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

    // Filter projects based on selected main task
    final availableProjects = <Project>[];
    if (_selectedMainTaskId != null) {
      final task = provider.mainTasks.firstWhere((t) => t.id == _selectedMainTaskId);
      availableProjects.addAll(task.projects);
    }

    return Container(
      color: AppTheme.fhBgDeepDark,
      height: MediaQuery.of(context).size.height * 0.9, // Taller for lists
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(width: 4, height: 24, color: AppTheme.fhAccentPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "LINK PROTOCOL", 
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppTheme.fhTextPrimary,
                        fontSize: 24
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "CONNECT PROJECT STEP TO MISSION LOG.",
                style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 32),

              // 1. Choose Mission
              ValorantDropdown<String>(
                label: "TARGET MISSION",
                value: _selectedMainTaskId,
                items: provider.mainTasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name.toUpperCase()))).toList(),
                onChanged: (val) {
                   setState(() {
                     _selectedMainTaskId = val;
                     _selectedProjectId = null;
                     _selectedStepId = null;
                     _selectedProjectObj = null;
                   });
                }
              ),

              const SizedBox(height: 20),

              // 2. Select Project
              if (_selectedMainTaskId != null) ...[
                 ValorantDropdown<String>(
                  label: "SOURCE PROJECT",
                  value: _selectedProjectId,
                  items: availableProjects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title.toUpperCase()))).toList(),
                  onChanged: (val) {
                     final proj = availableProjects.firstWhere((p) => p.id == val);
                     setState(() {
                       _selectedProjectId = val;
                       _selectedProjectObj = proj;
                       _selectedStepId = null;
                     });
                  }
                ),
              ],

              const SizedBox(height: 20),

              // 3. Select Step List
              if (_selectedProjectObj != null) ...[
                Text(
                  "SELECT OBJECTIVE",
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontFamily: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDark.withOpacity(0.5),
                      border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
                    ),
                    child: ListView.separated(
                      itemCount: _selectedProjectObj!.steps.length,
                      separatorBuilder: (c, i) => Divider(color: AppTheme.fhBorderColor.withOpacity(0.1), height: 1),
                      itemBuilder: (context, index) {
                        final step = _selectedProjectObj!.steps[index];
                        final isSelected = _selectedStepId == step.id;
                        return ListTile(
                          tileColor: isSelected ? AppTheme.fhAccentPurple.withOpacity(0.1) : null,
                          title: Text(
                            step.title.toUpperCase(), 
                            style: TextStyle(
                              color: isSelected ? AppTheme.fhAccentPurple : AppTheme.fhTextPrimary,
                              fontFamily: AppTheme.fontBody,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                          trailing: isSelected 
                            ? Icon(MdiIcons.checkBold, color: AppTheme.fhAccentPurple, size: 18) 
                            : Icon(MdiIcons.circleOutline, color: AppTheme.fhTextSecondary, size: 18),
                          onTap: () => setState(() => _selectedStepId = step.id),
                        );
                      },
                    ),
                  ),
                )
              ] else ...[
                const Spacer(),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: ValorantButton(
                      label: "CANCEL",
                      isPrimary: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ValorantButton(
                      label: "LINK",
                      isPrimary: true,
                      color: AppTheme.fhAccentPurple,
                      onPressed: (_selectedMainTaskId != null && _selectedStepId != null) 
                        ? () {
                            final step = _selectedProjectObj!.steps.firstWhere((s) => s.id == _selectedStepId);
                            provider.projectActions.promoteStepToSubmission(_selectedMainTaskId!, step);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Linked successfully!")));
                        }
                        : null,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}