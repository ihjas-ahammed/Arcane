import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/model_configuration_widget.dart';
import 'package:missions/src/widgets/settings/sections/account_and_data_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/advanced_ai_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/cloud_sync_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/diagnostics_and_tools_section.dart';
import 'package:missions/src/widgets/settings/sections/notifications_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/security_privacy_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/ui_and_progress_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/update_settings_section.dart';

export 'package:missions/src/widgets/settings/sections/account_and_data_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/advanced_ai_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/cloud_sync_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/diagnostics_and_tools_section.dart';
export 'package:missions/src/widgets/settings/sections/notifications_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/security_privacy_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/settings_section_card.dart';
export 'package:missions/src/widgets/settings/sections/ui_and_progress_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/update_settings_section.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _customReflectionPromptController = TextEditingController();
  final _customBriefingPromptController = TextEditingController();

  List<String> _availableModels = [
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-pro-exp-02-05',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-3.1-flash-live-preview',
    'gemini-pro',
  ];
  bool _fetchingModels = false;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    _customReflectionPromptController.text =
        appProvider.settings.customReflectionPrompt ?? '';
    _customBriefingPromptController.text =
        appProvider.settings.customBriefingPrompt ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchModels(appProvider);
    });
  }

  @override
  void dispose() {
    _customReflectionPromptController.dispose();
    _customBriefingPromptController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels(AppProvider appProvider) async {
    setState(() => _fetchingModels = true);
    try {
      final aiService = AIService();
      final models = await aiService.fetchAvailableModels(
        customApiKey: appProvider.settings.customApiKeys.isNotEmpty
            ? appProvider.settings.customApiKeys.first
            : null,
      );
      if (!mounted) return;
      setState(() {
        if (models.isNotEmpty) _availableModels = models;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fetched ${_availableModels.length} models."),
          backgroundColor: AppTheme.fhAccentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching models: $e"),
          backgroundColor: AppTheme.fhAccentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. AUTO UPDATE & SYSTEM RELEASES
              UpdateSettingsSection(appProvider: appProvider, theme: theme),

              // 1. CLOUD SYNC
              CloudSyncSettingsSection(appProvider: appProvider, theme: theme),

              // 2. SECURITY, PRIVACY & THEME
              SecurityPrivacySettingsSection(appProvider: appProvider),

              // 3. AI MODELS
              ModelConfigurationWidget(
                appProvider: appProvider,
                availableModels: _availableModels,
                isFetching: _fetchingModels,
                onFetch: () => _fetchModels(appProvider),
              ),

              // 4. ADVANCED AI
              AdvancedAiSettingsSection(
                appProvider: appProvider,
                theme: theme,
                reflectionPromptController: _customReflectionPromptController,
                briefingPromptController: _customBriefingPromptController,
              ),

              // 5 & 6. WEEKLY PROGRESS & UI CONFIG
              UiAndProgressSettingsSection(appProvider: appProvider, theme: theme),

              // 7. NOTIFICATIONS
              NotificationsSettingsSection(appProvider: appProvider, theme: theme),

              // 8, 8.5, 8.6. DIAGNOSTICS & ONBOARDING & TOOLS
              DiagnosticsAndToolsSection(appProvider: appProvider, theme: theme),

              // 9 & 10. CREDENTIALS & DATA RESET
              AccountAndDataSettingsSection(appProvider: appProvider, theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}