import 'package:flutter/material.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
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
    final availableModels = <String>{
      ...AppSettings.defaultLiveModels,
      ...AppSettings.defaultLiteModels,
      ...AppSettings.defaultHeavyModels,
      ...provider.settings.liveModels,
      ...provider.settings.liteModels,
      ...provider.settings.heavyModels,
    }.toList();

    final isLight = JweTheme.isLight;
    final bgDark = isLight ? JweTheme.panel : AppTheme.fhBgDark;
    final bgDeepDark = isLight ? JweTheme.bgDeep : AppTheme.fhBgDeepDark;
    final textPrimary = isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary;
    final textSecondary = isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary;
    final accentColor = isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple;

    return Container(
      color: bgDeepDark,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NORA PARAMETERS", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, color: accentColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            Text("SYSTEM PROMPT OVERRIDE", style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgDark,
                hintText: "Override Nora's base instructions...",
                border: const OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("MAX BUBBLES/REPLY", style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _limitController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textPrimary, fontFamily: 'RobotoMono'),
                        decoration: InputDecoration(filled: true, fillColor: bgDark, border: const OutlineInputBorder(), hintText: "e.g. 3 (0 = Auto)"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CONTEXT (DAYS)", style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textPrimary, fontFamily: 'RobotoMono'),
                        decoration: InputDecoration(filled: true, fillColor: bgDark, border: const OutlineInputBorder(), hintText: "e.g. 7"),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            Text("MODEL OVERRIDE", style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              dropdownColor: bgDark,
              decoration: InputDecoration(filled: true, fillColor: bgDark, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: null, child: Text("System Default", style: TextStyle(color: textSecondary))),
                ...availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(color: textPrimary)))),
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
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
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