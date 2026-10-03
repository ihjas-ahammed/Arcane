import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/settings/model_configuration_widget.dart';
import 'package:missions/src/widgets/settings/sections/advanced_ai_settings_section.dart';
import 'package:provider/provider.dart';

class AiModelsScreen extends StatefulWidget {
  const AiModelsScreen({super.key});

  @override
  State<AiModelsScreen> createState() => _AiModelsScreenState();
}

class _AiModelsScreenState extends State<AiModelsScreen> {
  final _customReflectionPromptController = TextEditingController();
  final _customBriefingPromptController = TextEditingController();

  List<String> _availableModels = [
    'gemini-3.8-flash',
    'gemini-3.8-flash-live-preview',
    'gemini-3.1-flash-live-preview',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.0-pro-exp-02-05',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'meta-llama/llama-3.3-70b-instruct',
    'groq/compound',
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
          content: Text(
            "Fetched ${_availableModels.length} models.",
            style: GoogleFonts.jetBrainsMono(fontSize: 12),
          ),
          backgroundColor: AppTheme.fhAccentGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error fetching models: $e",
            style: GoogleFonts.jetBrainsMono(fontSize: 12),
          ),
          backgroundColor: AppTheme.fhAccentRed,
          duration: const Duration(seconds: 3),
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
    final isLight = JweTheme.isLight;

    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: JweTheme.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEURAL & AI ENGINE',
              style: GoogleFonts.rajdhani(
                color: JweTheme.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '// MODEL SELECTION & INFERENCE CONFIGURATION',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _fetchingModels
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: JweTheme.accentCyan,
                    ),
                  )
                : Icon(Icons.refresh, color: JweTheme.accentCyan),
            tooltip: 'Fetch Available Models',
            onPressed: _fetchingModels ? null : () => _fetchModels(appProvider),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: JweTheme.border, height: 1),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16.0,
              16.0,
              16.0,
              32.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick tactical overview card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLight ? JweTheme.panel : AppTheme.fhBgMedium,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(MdiIcons.robotOutline, color: JweTheme.accentCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE MODEL: ${appProvider.settings.activeAiModel}',
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.accentCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${appProvider.settings.customApiKeys.length} API keys configured • Multiple providers supported (Gemini, OpenRouter, Groq, Ollama)',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 1. Model Configuration Widget (Providers, API Keys, Model Pickers)
                ModelConfigurationWidget(
                  appProvider: appProvider,
                  availableModels: _availableModels,
                  isFetching: _fetchingModels,
                  onFetch: () => _fetchModels(appProvider),
                ),

                const SizedBox(height: 16),

                // 2. Advanced AI Settings Section (Reflection, Briefing, Directives)
                AdvancedAiSettingsSection(
                  appProvider: appProvider,
                  theme: theme,
                  reflectionPromptController: _customReflectionPromptController,
                  briefingPromptController: _customBriefingPromptController,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
