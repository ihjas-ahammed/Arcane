import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/services/assistant_routing_service.dart';
import 'package:missions/src/services/tts_service.dart';
import 'package:missions/src/screens/settings/custom_assistant_picker_screen.dart';
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
  List<InstalledAssistant> _installedAssistants = [];
  bool _isLoadingAssistants = true;

  @override
  void initState() {
    super.initState();
    _customPkgController = TextEditingController(
      text: widget.appProvider.settings.bluetoothAssistantCustomPackage,
    );
    _loadInstalledAssistants();
  }

  Future<void> _loadInstalledAssistants() async {
    setState(() => _isLoadingAssistants = true);
    final list = await AssistantRoutingService.instance.getInstalledAssistants();
    if (mounted) {
      setState(() {
        _installedAssistants = list;
        _isLoadingAssistants = false;
      });
    }
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isLoadingAssistants
                  ? "Scanning installed assistants..."
                  : "${_installedAssistants.length} installed assistant app(s) discovered",
              style: TextStyle(
                color: JweTheme.isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (_isLoadingAssistants)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  MdiIcons.refresh,
                  size: 16,
                  color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
                ),
                tooltip: 'Re-scan installed assistant apps',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _loadInstalledAssistants,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (context) {
            final List<DropdownMenuItem<String>> items = [
              const DropdownMenuItem(
                value: 'nora',
                child: Text('Nora (Arcane Tactical Assistant)'),
              ),
              const DropdownMenuItem(
                value: 'system_assist',
                child: Text('System Default Assistant'),
              ),
              ..._installedAssistants.map((assistant) {
                return DropdownMenuItem<String>(
                  value: assistant.package,
                  child: Text(
                    '${assistant.label} (${assistant.package})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              const DropdownMenuItem(
                value: 'custom',
                child: Text('Custom App Package Name...'),
              ),
            ];

            // Normalize legacy short codes if present
            String currentTarget = appProvider.settings.bluetoothAssistantRedirectTarget;
            if (currentTarget == 'chatgpt' && _installedAssistants.any((a) => a.package == 'com.openai.chatgpt')) {
              currentTarget = 'com.openai.chatgpt';
            } else if (currentTarget == 'gemini' && _installedAssistants.any((a) => a.package == 'com.google.android.apps.googleassistant')) {
              currentTarget = 'com.google.android.apps.googleassistant';
            } else if (currentTarget == 'claude' && _installedAssistants.any((a) => a.package == 'com.anthropic.claude')) {
              currentTarget = 'com.anthropic.claude';
            } else if (currentTarget == 'perplexity' && _installedAssistants.any((a) => a.package == 'ai.perplexity.app')) {
              currentTarget = 'ai.perplexity.app';
            } else if (currentTarget == 'copilot' && _installedAssistants.any((a) => a.package == 'com.microsoft.copilot')) {
              currentTarget = 'com.microsoft.copilot';
            }

            final validValues = items.map((i) => i.value).toSet();
            if (!validValues.contains(currentTarget)) {
              if (currentTarget.isNotEmpty && currentTarget != 'nora' && currentTarget != 'system_assist') {
                if (_customPkgController.text.isEmpty) {
                  _customPkgController.text = currentTarget;
                }
                currentTarget = 'custom';
              } else {
                currentTarget = 'nora';
              }
            }

            return DropdownButtonFormField<String>(
              value: currentTarget,
              decoration: InputDecoration(
                labelText: 'Bluetooth Voice Command Target',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              dropdownColor: JweTheme.isLight ? JweTheme.panel : AppTheme.fhBgDark,
              isExpanded: true,
              items: items,
              onChanged: (val) async {
                if (val == null) return;
                setState(() {
                  appProvider.settings.bluetoothAssistantRedirectTarget = val;
                });
                appProvider.setSettings(appProvider.settings);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('bluetooth_assistant_redirect_target', val);

                if (val == 'custom' && appProvider.settings.bluetoothAssistantCustomPackage.isEmpty) {
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomAssistantPickerScreen(),
                    ),
                  );
                  setState(() {});
                }
              },
            );
          },
        ),
        if (appProvider.settings.bluetoothAssistantRedirectTarget == 'custom') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.isLight ? JweTheme.panel : AppTheme.fhBgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "CUSTOM ASSISTANT TARGET",
                      style: TextStyle(
                        color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (appProvider.settings.bluetoothAssistantCustomPackage.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final launched = await AssistantRoutingService.instance.launchVoiceMode(
                            appProvider.settings.bluetoothAssistantCustomPackage,
                            activity: appProvider.settings.bluetoothAssistantCustomActivity,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(launched ? 'Target launched in voice mode' : 'Failed to launch target'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rocket_launch, size: 14, color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple),
                            const SizedBox(width: 4),
                            Text(
                              "TEST",
                              style: TextStyle(
                                color: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.apps,
                      size: 20,
                      color: JweTheme.isLight ? JweTheme.textMid : AppTheme.fhTextSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appProvider.settings.bluetoothAssistantCustomPackage.isEmpty
                                ? "No application selected"
                                : appProvider.settings.bluetoothAssistantCustomPackage,
                            style: TextStyle(
                              color: JweTheme.isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            appProvider.settings.bluetoothAssistantCustomActivity.isEmpty
                                ? "Activity: Auto-Detect Voice / Default"
                                : "Activity: ${appProvider.settings.bluetoothAssistantCustomActivity}",
                            style: TextStyle(
                              color: JweTheme.isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                              fontSize: 10,
                              fontFamily: 'RobotoMono',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.touch_app, size: 16),
                    label: const Text("BROWSE APPS & ACTIVITIES"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple).withOpacity(0.15),
                      foregroundColor: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
                      side: BorderSide(color: (JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple).withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomAssistantPickerScreen(),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
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
