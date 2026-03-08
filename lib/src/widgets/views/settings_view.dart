// lib/src/widgets/views/settings_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/screens/settings/data_recovery_screen.dart';
import 'package:arcane/src/widgets/settings/api_key_manager.dart';
import 'package:arcane/src/widgets/settings/model_configuration_widget.dart';
import 'package:arcane/src/widgets/dialogs/pin_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _customChatbotPromptController = TextEditingController();
  final _customReflectionPromptController = TextEditingController();

  bool _passwordChangeLoading = false;
  String _passwordChangeError = '';
  String _passwordChangeSuccess = '';
  bool _usernameChangeLoading = false;
  String _usernameChangeError = '';
  String _usernameChangeSuccess = '';
  bool _logoutLoading = false;

  List<String> _availableModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ];
  bool _fetchingModels = false;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    _newUsernameController.text = appProvider.currentUser?.displayName ?? '';
    _customChatbotPromptController.text =
        appProvider.settings.customChatbotPrompt ?? '';
    _customReflectionPromptController.text =
        appProvider.settings.customReflectionPrompt ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchModels(appProvider);
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newUsernameController.dispose();
    _customChatbotPromptController.dispose();
    _customReflectionPromptController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword(AppProvider appProvider) async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _passwordChangeError = "Passwords do not match.");
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() => _passwordChangeError =
          "Password should be at least 6 characters long.");
      return;
    }
    setState(() {
      _passwordChangeLoading = true;
      _passwordChangeError = '';
      _passwordChangeSuccess = '';
    });
    try {
      await appProvider.changePasswordHandler(_newPasswordController.text);
      if (!mounted) return;
      setState(() {
        _passwordChangeSuccess = "Password changed successfully!";
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      if (e is FirebaseAuthException) {
        setState(() =>
            _passwordChangeError = e.message ?? "Failed to change password.");
      } else {
        setState(() => _passwordChangeError =
            "An unexpected error occurred while changing password.");
      }
    } finally {
      if (mounted) {
        setState(() => _passwordChangeLoading = false);
      }
    }
  }

  Future<void> _handleChangeUsername(AppProvider appProvider) async {
    if (_newUsernameController.text.trim().isEmpty) {
      setState(() => _usernameChangeError = "Username cannot be empty.");
      return;
    }
    if (_newUsernameController.text.trim().length < 3) {
      setState(() =>
          _usernameChangeError = "Username must be at least 3 characters.");
      return;
    }
    setState(() {
      _usernameChangeLoading = true;
      _usernameChangeError = '';
      _usernameChangeSuccess = '';
    });
    try {
      await appProvider
          .updateUserDisplayName(_newUsernameController.text.trim());
      if (!mounted) return;
      setState(() {
        _usernameChangeSuccess = "Username updated successfully!";
      });
    } catch (e) {
      if (!mounted) return;
      if (e is FirebaseAuthException) {
        setState(() =>
            _usernameChangeError = e.message ?? "Failed to update username.");
      } else {
        setState(() => _usernameChangeError =
            "An unexpected error occurred while updating username.");
      }
    } finally {
      if (mounted) {
        setState(() => _usernameChangeLoading = false);
      }
    }
  }

  Future<void> _handleLogout(
      AppProvider appProvider, BuildContext pageContext) async {
    setState(() => _logoutLoading = true);
    try {
      await appProvider.logoutUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: AppTheme.fhAccentRed));
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  Future<void> _fetchModels(AppProvider appProvider) async {
    setState(() => _fetchingModels = true);
    try {
      final aiService = AIService();
      final models = await aiService.fetchAvailableModels(
          customApiKey: appProvider.settings.customApiKeys.isNotEmpty
              ? appProvider.settings.customApiKeys.first
              : null);
      if (!mounted) return;
      setState(() {
        if (models.isNotEmpty) _availableModels = models;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fetched ${_availableModels.length} models."), backgroundColor: AppTheme.fhAccentGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching models: $e"), backgroundColor: AppTheme.fhAccentRed),
      );
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _handleChangePin(AppProvider provider) async {
    // If PIN exists, require old PIN first to change
    if (provider.settings.journalPin != null) {
      final auth = await PinDialog.show(context: context, isSetupMode: false, expectedPin: provider.settings.journalPin);
      if (auth != true) return;
    }
    
    if (!mounted) return;
    
    // Set New PIN
    final newPin = await PinDialog.show(context: context, isSetupMode: true);
    if (newPin != null && newPin is String) {
      provider.setJournalPin(newPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Security PIN Updated.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    String lastSavedString = "Not synced yet.";
    if (appProvider.lastSuccessfulSaveTimestamp != null) {
      lastSavedString =
          "Last synced: ${DateFormat('MMM d, yyyy, hh:mm:ss a').format(appProvider.lastSuccessfulSaveTimestamp!.toLocal())}";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CLOUD SYNC
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.cloudSyncOutline,
                          color: AppTheme.fhAccentTealFixed, size: 22),
                      const SizedBox(width: 10),
                      Text('Cloud Synchronization',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Divider(height: 24, thickness: 0.5, color: AppTheme.fhBorderColor.withOpacity(0.5)),
                  
                  SwitchListTile.adaptive(
                    title: const Text('Real-Time Sync'),
                    subtitle: const Text('Automatically sync changes to cloud immediately.'),
                    value: appProvider.settings.autoSaveEnabled,
                    activeTrackColor: AppTheme.fhAccentTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) {
                      appProvider.setSettings(appProvider.settings..autoSaveEnabled = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  ElevatedButton.icon(
                    icon: appProvider.isSyncing 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhTextPrimary))
                        : Icon(MdiIcons.cloudUploadOutline, size: 18),
                    label: const Text('FORCE CLOUD SYNC'),
                    onPressed: appProvider.isSyncing ? null : () => appProvider.manuallySaveToCloud(),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        backgroundColor: AppTheme.fhAccentTealFixed,
                        foregroundColor: AppTheme.fhBgDark),
                  ),
                  
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.cloudDownloadOutline, size: 18),
                    label: const Text('RESTORE FROM CLOUD (OVERWRITE)'),
                    onPressed: appProvider.isSyncing || appProvider.isManuallyLoading ? null : () async {
                       final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Restore'),
                              content: const Text(
                                  'This will overwrite local data with cloud data. Continue?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESTORE')),
                              ],
                            ),
                          );
                       if (confirm == true) appProvider.manuallyLoadFromCloud();
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        backgroundColor: AppTheme.fhBgDark,
                        foregroundColor: AppTheme.fhTextPrimary,
                        side: const BorderSide(color: AppTheme.fhAccentTealFixed)),
                  ),
                  
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: Icon(MdiIcons.backupRestore, size: 18),
                    label: const Text('DATA RECOVERY & BACKUPS'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const DataRecoveryScreen()));
                    },
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        foregroundColor: AppTheme.fhTextPrimary,
                        side: BorderSide(
                            color: AppTheme.fhTextSecondary.withOpacity(0.5))),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      lastSavedString,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.fhTextSecondary.withOpacity(0.8),
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. SECURITY
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.shieldLockOutline,
              title: 'Security & Nora Privacy',
              children: [
                OutlinedButton.icon(
                  icon: Icon(MdiIcons.dialpad, size: 18),
                  label: Text(appProvider.settings.journalPin == null ? "SET SECURITY PIN" : "CHANGE SECURITY PIN"),
                  onPressed: () => _handleChangePin(appProvider),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: AppTheme.fhAccentPurple,
                    side: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.5))
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Nora AI Context Access", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextSecondary)),
                SwitchListTile.adaptive(
                  title: const Text('Access Session Logs', style: TextStyle(fontSize: 14)),
                  value: appProvider.settings.noraAccessSessions,
                  activeTrackColor: AppTheme.fhAccentPurple,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool value) {
                    appProvider.setSettings(appProvider.settings..noraAccessSessions = value);
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('Access Finance Data', style: TextStyle(fontSize: 14)),
                  value: appProvider.settings.noraAccessFinance,
                  activeTrackColor: AppTheme.fhAccentPurple,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool value) {
                    appProvider.setSettings(appProvider.settings..noraAccessFinance = value);
                  },
                ),
              ]),

          // 3. AI MODELS
          ModelConfigurationWidget(
            appProvider: appProvider,
            availableModels: _availableModels,
            isFetching: _fetchingModels,
            onFetch: () => _fetchModels(appProvider),
          ),

          // 4. ADVANCED AI
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.keyVariant,
              title: 'Advanced AI Settings',
              children: [
                const Text("Custom Gemini API Keys", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
                const SizedBox(height: 8),
                const ApiKeyManager(),

                const SizedBox(height: 16),
                Text("Custom System Prompts",
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customReflectionPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reflection Analysis System Prompt',
                    hintText:
                        'Define how reflections are analyzed and XP awarded.',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (val) {
                    appProvider.setSettings(
                        appProvider.settings..customReflectionPrompt = val);
                  },
                ),
                const SizedBox(height: 8),
                const Text("Leave blank to use built-in defaults.",
                    style: TextStyle(
                        color: AppTheme.fhTextSecondary, fontSize: 11)),
              ]
          ),

          // 5. WEEKLY PROGRESS
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.calendarWeek,
              title: 'Weekly Progress',
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Start Day of the Week',
                    prefixIcon: Icon(MdiIcons.calendarStartOutline, size: 20),
                  ),
                  dropdownColor: AppTheme.fhBgMedium,
                  initialValue: appProvider.settings.startOfWeek,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                    DropdownMenuItem(value: 7, child: Text('Sunday')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      appProvider.setSettings(
                          appProvider.settings..startOfWeek = value);
                    }
                  },
                ),
              ]),

          // 6. USER PROFILE
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.accountEditOutline,
              title: 'User Profile',
              children: [
                TextFormField(
                  controller: _newUsernameController,
                  decoration: InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(MdiIcons.accountBadgeOutline, size: 20)),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name cannot be empty.';
                    }
                    if (value.trim().length < 3) {
                      return 'Must be at least 3 characters.';
                    }
                    return null;
                  },
                ),
                if (_usernameChangeError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_usernameChangeError,
                        style: const TextStyle(
                            color: AppTheme.fhAccentRed, fontSize: 12)),
                  ),
                if (_usernameChangeSuccess.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_usernameChangeSuccess,
                        style: const TextStyle(
                            color: AppTheme.fhAccentGreen, fontSize: 12)),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: _usernameChangeLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.fhTextPrimary))
                      : Icon(MdiIcons.contentSaveOutline, size: 18),
                  label: const Text('UPDATE DISPLAY NAME'),
                  onPressed: _usernameChangeLoading
                      ? null
                      : () => _handleChangeUsername(appProvider),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44)),
                ),
              ]),

          // 7. UI CONFIG
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.eyeSettingsOutline,
              title: 'User Interface Config',
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Verbose Data Display'),
                  subtitle: const Text(
                      'Show detailed descriptions for stats and items throughout the interface.'),
                  value: appProvider.settings.descriptionsVisible,
                  onChanged: (value) => appProvider.setSettings(
                      appProvider.settings..descriptionsVisible = value),
                  activeTrackColor: (appProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
          
          // 8. DIAGNOSTICS
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.tools,
              title: 'System Diagnostics',
              children: [
                const Text(
                  'Use these tools to repair data inconsistencies.',
                  style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(MdiIcons.databaseSyncOutline, size: 18),
                  label: const Text('RECALIBRATE TIME LOGS'),
                  onPressed: () async {
                    try {
                      await appProvider.recalibrateTimeLogs();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Time logs successfully recalibrated from session history.'),
                          backgroundColor: AppTheme.fhAccentGreen
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Recalibration failed: $e'),
                          backgroundColor: AppTheme.fhAccentRed
                        ));
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: AppTheme.fhAccentOrange,
                    side: BorderSide(color: AppTheme.fhAccentOrange.withOpacity(0.5))
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Re-syncs total task time data for the past 7 days based strictly on raw session entries. Use if time totals appear incorrect.",
                    style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ]),

          // 9. CREDENTIALS
          if (appProvider.currentUser != null)
            _buildSettingsSection(appProvider, theme,
                icon: MdiIcons.shieldAccountOutline,
                title: 'Access Credentials',
                children: [
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                        labelText: 'New Passcode Sequence',
                        prefixIcon:
                            Icon(MdiIcons.formTextboxPassword, size: 20)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                        labelText: 'Confirm Passcode Sequence',
                        prefixIcon:
                            Icon(MdiIcons.formTextboxPassword, size: 20)),
                    obscureText: true,
                  ),
                  if (_passwordChangeError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(_passwordChangeError,
                          style: const TextStyle(
                              color: AppTheme.fhAccentRed, fontSize: 12)),
                    ),
                  if (_passwordChangeSuccess.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(_passwordChangeSuccess,
                          style: const TextStyle(
                              color: AppTheme.fhAccentGreen, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: _passwordChangeLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.fhTextPrimary))
                        : Icon(MdiIcons.keyChange, size: 18),
                    label: const Text('UPDATE PASSCODE'),
                    onPressed: _passwordChangeLoading
                        ? null
                        : () => _handleChangePassword(appProvider),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (appProvider.getSelectedTask()?.taskColor ??
                                AppTheme.fhAccentTealFixed),
                        foregroundColor: AppTheme.fhBgDark,
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: _logoutLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.fhAccentOrange))
                        : Icon(MdiIcons.logoutVariant, size: 18),
                    label: const Text('TERMINATE SESSION'),
                    onPressed: _logoutLoading
                        ? null
                        : () => _handleLogout(appProvider, context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.fhAccentOrange,
                        side: const BorderSide(
                            color: AppTheme.fhAccentOrange, width: 1.5),
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                ]),

          // 10. DATA RESET
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.databaseRemoveOutline,
              title: 'Data & System Reset',
              children: [
                Text(
                  'WARNING: The "Purge All Data" protocol will erase all your data from the cloud, including missions, sub-quests, and logs. This action is irreversible.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.fhTextSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.alertOctagonOutline, size: 18),
                  label: const Text('PURGE ALL DATA'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentRed),
                          const SizedBox(width: 10),
                          const Text('Confirm System Purge',
                              style: TextStyle(color: AppTheme.fhAccentRed))
                        ]),
                        content: const Text(
                            'Are you absolutely certain you wish to erase all data? This operation cannot be undone and will result in total loss of progress.'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentRed,
                                  foregroundColor: AppTheme.fhTextPrimary),
                              child: const Text('CONFIRM PURGE')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      appProvider.clearAllData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('All data has been purged.'),
                          backgroundColor: AppTheme.fhAccentGreen));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentRed,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
              ]),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(AppProvider appProvider, ThemeData theme,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: (appProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed),
                    size: 22),
                const SizedBox(width: 10),
                Text(title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            Divider(
                height: 24,
                thickness: 0.5,
                color: AppTheme.fhBorderColor.withOpacity(0.5)),
            ...children,
          ],
        ),
      ),
    );
  }
}