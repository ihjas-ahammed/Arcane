import 'package:flutter/material.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class NoraControlPanel extends StatefulWidget {
  final NoraSession session;
  final Function(Map<String, dynamic>) onSave;

  const NoraControlPanel({super.key, required this.session, required this.onSave});

  @override
  State<NoraControlPanel> createState() => _NoraControlPanelState();
}

class _NoraControlPanelState extends State<NoraControlPanel> {
  late TextEditingController _promptController;
  late TextEditingController _limitController;
  late TextEditingController _daysController;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.session.systemPromptOverride ?? "");
    _limitController = TextEditingController(text: widget.session.messageLimit.toString());
    _daysController = TextEditingController(text: widget.session.contextDays.toString());
    _selectedModel = widget.session.modelOverride;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _limitController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final availableModels = [...provider.settings.liteModels, ...provider.settings.heavyModels].toSet().toList();

    return Container(
      color: AppTheme.fhBgDeepDark,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("NORA PARAMETERS", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, color: AppTheme.fhAccentPurple, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            const Text("SYSTEM PROMPT OVERRIDE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppTheme.fhBgDark,
                hintText: "Override Nora's base instructions...",
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("MAX BUBBLES/REPLY", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _limitController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                        decoration: const InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: OutlineInputBorder(), hintText: "e.g. 3 (0 = Auto)"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CONTEXT (DAYS)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                        decoration: const InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: OutlineInputBorder(), hintText: "e.g. 7"),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            const Text("MODEL OVERRIDE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              dropdownColor: AppTheme.fhBgDark,
              decoration: const InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text("System Default", style: TextStyle(color: AppTheme.fhTextSecondary))),
                ...availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white)))),
              ],
              onChanged: (val) => setState(() => _selectedModel = val),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple, foregroundColor: Colors.white),
                    onPressed: () {
                      final config = {
                        'systemPromptOverride': _promptController.text.trim().isEmpty ? null : _promptController.text.trim(),
                        'messageLimit': int.tryParse(_limitController.text) ?? 0,
                        'contextDays': int.tryParse(_daysController.text) ?? 7,
                        'modelOverride': _selectedModel,
                      };
                      widget.onSave(config);
                      Navigator.pop(context);
                    },
                    child: const Text("UPDATE"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}