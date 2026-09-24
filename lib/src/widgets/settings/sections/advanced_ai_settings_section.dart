import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/services/tts_service.dart';
import 'package:missions/src/widgets/settings/ai_providers_manager.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

class AdvancedAiSettingsSection extends StatefulWidget {
  final AppProvider appProvider;
  final ThemeData theme;
  final TextEditingController reflectionPromptController;
  final TextEditingController briefingPromptController;

  const AdvancedAiSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
    required this.reflectionPromptController,
    required this.briefingPromptController,
  });

  @override
  State<AdvancedAiSettingsSection> createState() =>
      _AdvancedAiSettingsSectionState();
}

class _AdvancedAiSettingsSectionState extends State<AdvancedAiSettingsSection> {
  bool _regeneratingStyleMap = false;
  late TextEditingController _customPkgController;

  @override
  void initState() {
    super.initState();
    _customPkgController = TextEditingController(
      text: widget.appProvider.settings.bluetoothAssistantCustomPackage,
    );
  }

  @override
  void dispose() {
    _customPkgController.dispose();
    super.dispose();
  }

  void _showEditStyleMapDialog(BuildContext context, AppProvider appProvider) {
    final controller = TextEditingController(
      text: appProvider.settings.writingStyleMap ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: Row(
          children: [
            Icon(MdiIcons.pencilOutline, color: AppTheme.fhAccentPurple),
            const SizedBox(width: 10),
            Text(
              'Edit Writing Style Map',
              style: TextStyle(color: AppTheme.fhTextPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manually define or tweak the map describing your writing style. Downstream AI models will reference this description to align their tone.',
                style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TextField(
                  controller: controller,
                  maxLines: 8,
                  minLines: 3,
                  style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        'Describe your writing style (e.g. casual tone, uses analytical terms, prefers short sentences...)',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppTheme.fhTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.appProvider.setSettings(
                widget.appProvider.settings
                  ..writingStyleMap = controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Writing style map updated.'),
                  backgroundColor: AppTheme.fhAccentGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fhAccentPurple,
              foregroundColor: AppTheme.fhBgDark,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = widget.appProvider;
    final theme = widget.theme;

    return SettingsSectionCard(
      icon: MdiIcons.keyVariant,
      title: 'Advanced AI Settings',
      children: [
        Text(
          "AI Providers & API Keys",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.fhTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const AiProvidersManager(),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          title: const Text(
            'Adapt User Writing Style',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: const Text(
            'Analyze last 7 days of reflections to mirror your writing style in AI responses',
            style: TextStyle(fontSize: 12),
          ),
          value: appProvider.settings.adaptWritingStyle,
          activeTrackColor: AppTheme.fhAccentPurple,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool value) async {
            appProvider.setSettings(
              appProvider.settings..adaptWritingStyle = value,
            );
            if (value) {
              setState(() => _regeneratingStyleMap = true);
              try {
                await appProvider.updateWritingStyleMap();
              } finally {
                if (mounted) {
                  setState(() => _regeneratingStyleMap = false);
                }
              }
            }
          },
        ),
        if (appProvider.settings.adaptWritingStyle) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _regeneratingStyleMap
                      ? "Generating writing style map..."
                      : (appProvider.settings.writingStyleMap != null
                          ? "Writing style map generated (Active)"
                          : "No writing style map generated yet"),
                  style: TextStyle(
                    fontSize: 12,
                    color: appProvider.settings.writingStyleMap != null
                        ? AppTheme.fhAccentPurple
                        : AppTheme.fhTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              if (!_regeneratingStyleMap) ...[
                IconButton(
                  icon: Icon(
                    MdiIcons.refresh,
                    size: 18,
                    color: AppTheme.fhAccentPurple,
                  ),
                  tooltip: 'Regenerate Writing Style Map',
                  onPressed: () async {
                    setState(() => _regeneratingStyleMap = true);
                    try {
                      await appProvider.updateWritingStyleMap();
                    } finally {
                      if (mounted) {
                        setState(() => _regeneratingStyleMap = false);
                      }
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    MdiIcons.pencilOutline,
                    size: 18,
                    color: AppTheme.fhAccentPurple,
                  ),
                  tooltip: 'Manually View & Edit Map',
                  onPressed: () =>
                      _showEditStyleMapDialog(context, appProvider),
                ),
              ],
              if (_regeneratingStyleMap)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.fhAccentPurple,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text("Custom System Prompts", style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.reflectionPromptController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reflection Analysis System Prompt',
            hintText: 'Define how reflections are analyzed and XP awarded.',
            alignLabelWithHint: true,
          ),
          onChanged: (val) {
            appProvider.setSettings(
              appProvider.settings..customReflectionPrompt = val,
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.briefingPromptController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Daily Briefing Prompt Extension',
            hintText:
                'Add specific instructions for generating the daily tactical briefing.',
            alignLabelWithHint: true,
          ),
          onChanged: (val) {
            appProvider.setSettings(
              appProvider.settings..customBriefingPrompt = val,
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          "Leave blank to use built-in defaults.",
          style: TextStyle(
            color: JweTheme.isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 20),
        Divider(
          height: 32,
          color: JweTheme.isLight ? JweTheme.border : AppTheme.fhBorderColor,
        ),
        Row(
          children: [
            Icon(
              Icons.bluetooth_audio,
              color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "Bluetooth AI Assistant & Redirector",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Arcane catches Bluetooth headset voice commands (ACTION_VOICE_COMMAND) and lock screen assist intents. You can open Nora or bridge the call to third-party assistant apps that lack Bluetooth voice manifests.",
          style: TextStyle(
            color: JweTheme.isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: appProvider.settings.bluetoothAssistantRedirectTarget,
          decoration: InputDecoration(
            labelText: 'Bluetooth Voice Command Target',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          dropdownColor: JweTheme.isLight ? JweTheme.panel : AppTheme.fhBgDark,
          items: const [
            DropdownMenuItem(value: 'nora', child: Text('Nora (Arcane Tactical Assistant)')),
            DropdownMenuItem(value: 'chatgpt', child: Text('ChatGPT (com.openai.chatgpt)')),
            DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (Assistant)')),
            DropdownMenuItem(value: 'claude', child: Text('Anthropic Claude')),
            DropdownMenuItem(value: 'perplexity', child: Text('Perplexity AI')),
            DropdownMenuItem(value: 'copilot', child: Text('Microsoft Copilot')),
            DropdownMenuItem(value: 'system_assist', child: Text('System Default Assistant')),
            DropdownMenuItem(value: 'custom', child: Text('Custom App Package Name...')),
          ],
          onChanged: (val) async {
            if (val == null) return;
            setState(() {
              appProvider.settings.bluetoothAssistantRedirectTarget = val;
            });
            appProvider.setSettings(appProvider.settings);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('bluetooth_assistant_redirect_target', val);
          },
        ),
        if (appProvider.settings.bluetoothAssistantRedirectTarget == 'custom') ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _customPkgController,
            decoration: const InputDecoration(
              labelText: 'Target Android Package Name',
              hintText: 'e.g. com.openai.chatgpt',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (val) async {
              appProvider.settings.bluetoothAssistantCustomPackage = val.trim();
              appProvider.setSettings(appProvider.settings);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('bluetooth_assistant_custom_package', val.trim());
            },
          ),
        ],
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Auto-Speak Nora Responses (TTS)",
            style: TextStyle(
              color: JweTheme.isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            "Synthesizes and speaks Nora's responses out loud using native Android Text-To-Speech engine.",
            style: TextStyle(
              color: JweTheme.isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
              fontSize: 11,
            ),
          ),
          value: appProvider.settings.noraAutoSpeakTts,
          activeColor: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
          onChanged: (val) {
            setState(() {
              appProvider.settings.noraAutoSpeakTts = val;
            });
            appProvider.setSettings(appProvider.settings);
            if (!val) {
              TtsService.instance.stop();
            } else {
              TtsService.instance.speak("Nora speech synthesizer activated.");
            }
          },
        ),
      ],
    );
  }
}
