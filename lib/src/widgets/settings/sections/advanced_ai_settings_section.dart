import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
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
          style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
