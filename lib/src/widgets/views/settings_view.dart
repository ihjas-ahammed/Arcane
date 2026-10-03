import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/settings/ai_models_screen.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/settings/sections/account_and_data_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/cloud_sync_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/diagnostics_and_tools_section.dart';
import 'package:missions/src/widgets/settings/sections/notifications_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/security_privacy_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/launcher_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';
import 'package:missions/src/widgets/settings/sections/ui_and_progress_settings_section.dart';
import 'package:missions/src/widgets/settings/sections/update_settings_section.dart';
import 'package:provider/provider.dart';

export 'package:missions/src/widgets/settings/sections/account_and_data_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/advanced_ai_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/cloud_sync_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/diagnostics_and_tools_section.dart';
export 'package:missions/src/widgets/settings/sections/notifications_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/security_privacy_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/settings_section_card.dart';
export 'package:missions/src/widgets/settings/sections/ui_and_progress_settings_section.dart';
export 'package:missions/src/widgets/settings/sections/update_settings_section.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final isLight = JweTheme.isLight;

    return Align(
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
              // 1. ACCOUNT & SYNC (credentials + cloud sync/backup)
              AccountAndDataSettingsSection(
                appProvider: appProvider,
                theme: theme,
                includeDangerZone: false,
              ),
              CloudSyncSettingsSection(appProvider: appProvider, theme: theme),

              // 2. HOME LAUNCHER (default home / MIUI takeover)
              const LauncherSettingsSection(),

              // 3. NOTIFICATIONS
              NotificationsSettingsSection(appProvider: appProvider, theme: theme),

              // 4. AI (models + advanced AI behavior)
              SettingsSectionCard(
                icon: MdiIcons.robotOutline,
                title: 'Neural & AI Engine',
                iconColor: JweTheme.accentCyan,
                children: [
                  Text(
                    'Configure multi-provider model selection (Gemini, OpenRouter, Groq, Ollama), API key rotation, reasoning prompts, and morning briefing directives in a dedicated subsystem.',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLight ? JweTheme.bgCanvas : AppTheme.fhBgDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: JweTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE INFERENCE MODEL',
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appProvider.settings.activeAiModel,
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.accentCyan,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${appProvider.settings.customApiKeys.length} Custom API key(s) configured',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMid,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(MdiIcons.cogOutline, size: 16),
                          label: Text(
                            'CONFIGURE',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JweTheme.accentCyan,
                            foregroundColor: JweTheme.onAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AiModelsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 5. UI (theme, weekly progress, interface config)
              UiAndProgressSettingsSection(appProvider: appProvider, theme: theme),

              // 6. UPDATES
              UpdateSettingsSection(appProvider: appProvider, theme: theme),

              // 7. SECURITY & PRIVACY
              SecurityPrivacySettingsSection(appProvider: appProvider),

              // 8. DIAGNOSTICS & TOOLS
              DiagnosticsAndToolsSection(appProvider: appProvider, theme: theme),

              // 9. DANGER ZONE (data & system reset)
              AccountAndDataSettingsSection(
                appProvider: appProvider,
                theme: theme,
                includeCredentials: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}