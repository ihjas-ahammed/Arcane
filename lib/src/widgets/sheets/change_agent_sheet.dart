import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_dropdown.dart';
import 'package:provider/provider.dart';

class ChangeAgentSheet extends StatefulWidget {
  final String projectId;
  final String currentMainTaskId;

  const ChangeAgentSheet({
    super.key,
    required this.projectId,
    required this.currentMainTaskId,
  });

  @override
  State<ChangeAgentSheet> createState() => _ChangeAgentSheetState();
}

class _ChangeAgentSheetState extends State<ChangeAgentSheet> {
  String? _selectedAgentId;

  @override
  void initState() {
    super.initState();
    _selectedAgentId = widget.currentMainTaskId;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TRANSFER OPERATION",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: AppTheme.fontDisplay,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.fhTextPrimary
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select a new protocol agent for this project.",
                style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ValorantDropdown<String>(
                label: "DESTINATION AGENT",
                value: _selectedAgentId,
                items: provider.mainTasks.map((t) {
                  return DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAgentId = val);
                },
              ),
              const SizedBox(height: 32),
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
                      label: "TRANSFER",
                      isPrimary: true,
                      onPressed: () {
                        if (_selectedAgentId != null && _selectedAgentId != widget.currentMainTaskId) {
                          provider.projectActions.changeProjectAgent(
                            widget.currentMainTaskId, 
                            _selectedAgentId!, 
                            widget.projectId
                          );
                          Navigator.pop(context, true); // Close this sheet
                        } else {
                          Navigator.pop(context); // Just close if same
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
    );
  }
}