// lib/src/widgets/views/settings_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // ... (existing controllers)
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _aiModelNameController = TextEditingController();
  final _apiKeyController = TextEditingController(); 
  final _customChatbotPromptController = TextEditingController(); // New
  final _customReflectionPromptController = TextEditingController(); // New
  
  bool _passwordChangeLoading = false;
  String _passwordChangeError = '';
  String _passwordChangeSuccess = '';
  bool _usernameChangeLoading = false;
  String _usernameChangeError = '';
  String _usernameChangeSuccess = '';
  bool _logoutLoading = false;

  final List<String> _availableModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    _newUsernameController.text = appProvider.currentUser?.displayName ?? '';
    _aiModelNameController.text = appProvider.settings.aiModelName;
    _apiKeyController.text = appProvider.settings.customApiKey ?? '';
    _customChatbotPromptController.text = appProvider.settings.customChatbotPrompt ?? '';
    _customReflectionPromptController.text = appProvider.settings.customReflectionPrompt ?? '';
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newUsernameController.dispose();
    _aiModelNameController.dispose();
    _apiKeyController.dispose();
    _customChatbotPromptController.dispose();
    _customReflectionPromptController.dispose();
    super.dispose();
  }

  // ... (Change password and username methods same as before)
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
      setState(() {
        _passwordChangeSuccess = "Password changed successfully!";
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
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
      await appProvider.updateUserDisplayName(_newUsernameController.text.trim());
      setState(() {
        _usernameChangeSuccess = "Username updated successfully!";
      });
    } catch (e) {
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
      ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: AppTheme.fhAccentRed));
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    // ... (Manual save section same as before)
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
           _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.cloudSyncOutline,
              title: 'Cloud Synchronization',
              children: [
                  // ... (Save/Load buttons same)
                  ElevatedButton.icon(
                  icon: appProvider.isManuallySaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.fhTextPrimary))
                      : Icon(MdiIcons.cloudUploadOutline, size: 18),
                  label: const Text('SAVE TO CLOUD NOW'),
                  onPressed: appProvider.isManuallySaving ||
                          appProvider.isManuallyLoading
                      ? null
                      : () async {
                          try {
                            await appProvider.manuallySaveToCloud();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Data saved to cloud.'),
                                      backgroundColor: AppTheme.fhAccentGreen));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Cloud save failed: ${e.toString()}'),
                                      backgroundColor: AppTheme.fhAccentRed));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: (appProvider.getSelectedTask()?.taskColor ??
                          AppTheme.fhAccentTealFixed),
                      foregroundColor: AppTheme.fhBgDark),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: appProvider.isManuallyLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.fhTextPrimary))
                      : Icon(MdiIcons.cloudDownloadOutline, size: 18),
                  label: const Text('LOAD FROM CLOUD NOW'),
                  onPressed: appProvider.isManuallySaving ||
                          appProvider.isManuallyLoading
                      ? null
                      : () async {
                           // ... confirm dialog
                            final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title:  Row(children: [
                                Icon(MdiIcons.cloudQuestionOutline,
                                    color: AppTheme.fhAccentOrange),
                                SizedBox(width: 10),
                                Text('Confirm Load')
                              ]),
                              content: const Text(
                                  'This will overwrite any local unsaved changes with data from the cloud. Are you sure?'),
                              actionsAlignment: MainAxisAlignment.spaceBetween,
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('CANCEL')),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.fhAccentOrange),
                                    child: const Text('CONFIRM LOAD')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await appProvider.manuallyLoadFromCloud();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Data loaded from cloud.'),
                                        backgroundColor:
                                            AppTheme.fhAccentGreen));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Cloud load failed: ${e.toString()}'),
                                        backgroundColor: AppTheme.fhAccentRed));
                              }
                            }
                          }
                      },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: (appProvider.getSelectedTask()?.taskColor ??
                          AppTheme.fhAccentTealFixed),
                      foregroundColor: AppTheme.fhBgDark),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    lastSavedString,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.fhTextSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ]),
          
          // AI CONFIGURATION
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.robotHappyOutline,
              title: 'AI Configuration',
              children: [
                DropdownButtonFormField<String>(
                  value: _availableModels.contains(appProvider.settings.aiModelName) 
                      ? appProvider.settings.aiModelName 
                      : null,
                  decoration:  InputDecoration(
                    labelText: 'AI Model Selection',
                    prefixIcon: Icon(MdiIcons.brain, size: 20),
                  ),
                  dropdownColor: AppTheme.fhBgLight,
                  items: _availableModels.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                       appProvider.setSettings(appProvider.settings..aiModelName = val);
                       _aiModelNameController.text = val;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _aiModelNameController,
                  decoration:   InputDecoration(
                    labelText: 'Custom Model Name (Override)',
                    hintText: 'e.g., gemini-1.5-pro-latest',
                    prefixIcon:  Icon(MdiIcons.pencilOutline, size: 20),
                  ),
                  onChanged: (value) {
                    appProvider
                        .setSettings(appProvider.settings..aiModelName = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Custom Gemini API Key (Optional)',
                    hintText: 'Paste your API Key here',
                    prefixIcon: Icon(MdiIcons.keyVariant, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(MdiIcons.contentSave, size: 20),
                      onPressed: () {
                         appProvider.setSettings(appProvider.settings..customApiKey = _apiKeyController.text.trim());
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Key saved locally.")));
                      },
                    )
                  ),
                  onChanged: (val) {
                    // Do not auto-save on every keystroke for security/perf, rely on save button or leave logic
                  },
                ),
                const SizedBox(height: 16),
                Text("Custom System Prompts", style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customChatbotPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'AI Advisor System Prompt',
                    hintText: 'Define the persona and behavior of the chatbot.',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (val) {
                     appProvider.setSettings(appProvider.settings..customChatbotPrompt = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customReflectionPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reflection Analysis System Prompt',
                    hintText: 'Define how reflections are analyzed and XP awarded.',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (val) {
                     appProvider.setSettings(appProvider.settings..customReflectionPrompt = val);
                  },
                ),
                const SizedBox(height: 8),
                const Text("Leave blank to use built-in defaults.", 
                  style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11)),
              ]),
              
          // ... (Rest of the sections: Weekly Progress, User Profile, Interface, Credentials, Reset)
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.calendarWeek,
              title: 'Weekly Progress',
              children: [
                DropdownButtonFormField<int>(
                  decoration:   InputDecoration(
                    labelText: 'Start Day of the Week',
                    prefixIcon: Icon(MdiIcons.calendarStartOutline, size: 20),
                  ),
                  dropdownColor: AppTheme.fhBgLight,
                  value: appProvider.settings.startOfWeek,
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
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.accountEditOutline,
              title: 'User Profile',
              children: [
                  // ... same
                  TextFormField(
                  controller: _newUsernameController,
                  decoration:  InputDecoration(
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
          // ... Credentials & Reset sections
           if (appProvider.currentUser != null)
            _buildSettingsSection(appProvider, theme,
                icon: MdiIcons.shieldAccountOutline,
                title: 'Access Credentials',
                children: [
                    // ... same
                     TextFormField(
                    controller: _newPasswordController,
                    decoration:  InputDecoration(
                        labelText: 'New Passcode Sequence',
                        prefixIcon:
                            Icon(MdiIcons.formTextboxPassword, size: 20)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration:  InputDecoration(
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
          _buildSettingsSection(appProvider, theme,
              icon: MdiIcons.databaseRemoveOutline,
              title: 'Data & System Reset',
              children: [
                 // ... same
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
                        title:  Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentRed),
                          SizedBox(width: 10),
                          Text('Confirm System Purge',
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('All data has been purged.'),
                                backgroundColor: AppTheme.fhAccentGreen));
                      }
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
                color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
            ...children,
          ],
        ),
      ),
    );
  }
}