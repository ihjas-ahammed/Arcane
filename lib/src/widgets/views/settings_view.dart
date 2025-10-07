// lib/src/widgets/views/settings_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
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
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newUsernameController = TextEditingController(); // For username change
  bool _passwordChangeLoading = false;
  String _passwordChangeError = '';
  String _passwordChangeSuccess = '';
  bool _usernameChangeLoading = false; // For username change
  String _usernameChangeError = ''; // For username change
  String _usernameChangeSuccess = ''; // For username change
  bool _logoutLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize username controller if user is available
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    _newUsernameController.text = gameProvider.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword(GameProvider gameProvider) async {
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
      await gameProvider.changePasswordHandler(_newPasswordController.text);
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

  Future<void> _handleChangeUsername(GameProvider gameProvider) async {
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
      await gameProvider
          .updateUserDisplayName(_newUsernameController.text.trim());
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
      GameProvider gameProvider, BuildContext pageContext) async {
    setState(() {
      _logoutLoading = true;
    });
    try {
      await gameProvider.logoutUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: AppTheme.fhAccentRed));
    } finally {
      if (mounted) {
        setState(() {
          _logoutLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);

    String lastSavedString = "Not synced yet.";
    if (gameProvider.lastSuccessfulSaveTimestamp != null) {
      lastSavedString =
          "Last synced: ${DateFormat('MMM d, yyyy, hh:mm:ss a').format(gameProvider.lastSuccessfulSaveTimestamp!.toLocal())}";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          _buildSettingsSection(gameProvider, theme,
              icon: MdiIcons.cloudSyncOutline,
              title: 'Cloud Synchronization',
              children: [
                ElevatedButton.icon(
                  icon: gameProvider.isManuallySaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.fhTextPrimary))
                      : Icon(MdiIcons.cloudUploadOutline, size: 18),
                  label: const Text('SAVE TO CLOUD NOW'),
                  onPressed: gameProvider.isManuallySaving ||
                          gameProvider.isManuallyLoading
                      ? null
                      : () async {
                          try {
                            await gameProvider.manuallySaveToCloud();
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
                      backgroundColor:
                          (gameProvider.getSelectedTask()?.taskColor ??
                              AppTheme.fhAccentTealFixed),
                      foregroundColor: AppTheme.fhBgDark),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: gameProvider.isManuallyLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.fhTextPrimary))
                      : Icon(MdiIcons.cloudDownloadOutline, size: 18),
                  label: const Text('LOAD FROM CLOUD NOW'),
                  onPressed: gameProvider.isManuallySaving ||
                          gameProvider.isManuallyLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Row(children: [
                                Icon(MdiIcons.cloudQuestionOutline,
                                    color: AppTheme.fhAccentOrange),
                                const SizedBox(width: 10),
                                const Text('Confirm Load')
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
                              await gameProvider.manuallyLoadFromCloud();
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
                      backgroundColor:
                          (gameProvider.getSelectedTask()?.taskColor ??
                              AppTheme.fhAccentTealFixed),
                      foregroundColor: AppTheme.fhBgDark),
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
                const SizedBox(height: 8),
                Text(
                  "Note: Game progress is auto-saved to the cloud periodically (approx. every minute if changes are detected). Use these options for immediate synchronization or recovery.",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.fhTextSecondary.withOpacity(0.8),
                      fontSize: 10),
                ),
              ]),
          _buildSettingsSection(gameProvider, theme,
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
                      : () => _handleChangeUsername(gameProvider),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44)),
                ),
              ]),
          _buildSettingsSection(
            gameProvider,
            theme,
            icon: MdiIcons.brain,
            title: 'Cognitive Matrix (AI)',
            children: [
              SwitchListTile.adaptive(
                title: const Text('Daily Auto-Generate Content'),
                subtitle: const Text(
                    'Each day, automatically generate new challenges (enemies, and a new realm if current one is pacified).'),
                value: gameProvider.settings.dailyAutoGenerateContent,
                onChanged: (value) => gameProvider.setSettings(
                    gameProvider.settings..dailyAutoGenerateContent = value),
                activeColor: (gameProvider.getSelectedTask()?.taskColor ??
                    AppTheme.fhAccentTealFixed),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Text(
                'Manually initiate content generation protocols for current operational level (${gameProvider.playerLevel}). This may consume significant resources.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.fhTextSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage
                            .contains("Adversaries")
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.fhTextPrimary))
                    : Icon(MdiIcons.skullCrossbonesOutline, size: 18),
                label: Text(gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage
                            .contains("Adversaries")
                    ? 'GENERATING ADVERSARIES...'
                    : 'GENERATE NEW ADVERSARIES'),
                onPressed: gameProvider.isGeneratingContent
                    ? null
                    : () => gameProvider.generateGameContent(
                        gameProvider.playerLevel,
                        isManual: true,
                        isInitial: false,
                        contentType: "enemies"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage
                            .contains("Artifacts")
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.fhTextPrimary))
                    : Icon(MdiIcons.swordCross, size: 18),
                label: Text(gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage
                            .contains("Artifacts")
                    ? 'FORGING ARTIFACTS...'
                    : 'FORGE NEW ARTIFACTS'),
                onPressed: gameProvider.isGeneratingContent
                    ? null
                    : () => gameProvider.generateGameContent(
                        gameProvider.playerLevel,
                        isManual: true,
                        isInitial: false,
                        contentType: "artifacts"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage.contains("Realms")
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.fhTextPrimary))
                    : Icon(MdiIcons.mapSearchOutline, size: 18),
                label: Text(gameProvider.isGeneratingContent &&
                        gameProvider.aiGenerationStatusMessage.contains("Realms")
                    ? 'DISCOVERING REALMS...'
                    : 'DISCOVER NEW REALMS'),
                onPressed: gameProvider.isGeneratingContent
                    ? null
                    : () => gameProvider.generateGameContent(
                        gameProvider.playerLevel,
                        isManual: true,
                        isInitial: false,
                        contentType: "locations"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44)),
              ),
              if (gameProvider.isGeneratingContent)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: gameProvider.aiGenerationProgress,
                        backgroundColor:
                            AppTheme.fhBorderColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            (gameProvider.getSelectedTask()?.taskColor ??
                                    AppTheme.fhAccentTealFixed)
                                .withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gameProvider.aiGenerationStatusMessage.isNotEmpty
                            ? gameProvider.aiGenerationStatusMessage
                            : 'Cognitive matrix recalculating... please standby.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: (gameProvider.getSelectedTask()?.taskColor ??
                                    AppTheme.fhAccentTealFixed)
                                .withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          _buildSettingsSection(gameProvider, theme,
              icon: MdiIcons.mapLegend,
              title: "Manage Realms (Combat Zones)",
              children: [
                if (gameProvider.gameLocationsList.isEmpty)
                  const Text("No combat zones discovered yet.",
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gameProvider.gameLocationsList.length,
                  itemBuilder: (context, index) {
                    final location = gameProvider.gameLocationsList[index];
                    return ListTile(
                      leading: Text(location.iconEmoji,
                          style: const TextStyle(fontSize: 20)),
                      title: Text(location.name),
                      subtitle: Text(
                          "Lvl ${location.minPlayerLevelToUnlock}+. ${location.description}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: Icon(MdiIcons.mapMarkerRemoveVariant,
                            color: AppTheme.fhAccentRed),
                        tooltip: "Decommission Realm",
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Row(children: [
                                Icon(MdiIcons.alertOutline,
                                    color: AppTheme.fhAccentRed),
                                const SizedBox(width: 10),
                                const Text('Confirm Decommission')
                              ]),
                              content: Text(
                                  'Are you sure you want to decommission the realm "${location.name}"? This cannot be undone.'),
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
                                        backgroundColor: AppTheme.fhAccentRed),
                                    child: const Text('DECOMMISSION REALM')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            gameProvider.deleteGameLocation(location.id);
                          }
                        },
                      ),
                    );
                  },
                )
              ]),
          _buildSettingsSection(gameProvider, theme,
              icon: MdiIcons.layersTripleOutline,
              title: 'Content Matrix Control',
              children: [
                Text(
                  'Manage generated game content. These actions are specific and do not affect player progress directly, but may alter game balance or availability of items/enemies.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.fhTextSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.archiveRemoveOutline,
                      size: 18, color: AppTheme.fhTextPrimary),
                  label: const Text('CLEAR ARTIFACTS & BLUEPRINTS'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentOrange),
                          const SizedBox(width: 10),
                          const Text('Confirm Artifact Purge')
                        ]),
                        content: const Text(
                            'This will remove ALL owned artifacts from your inventory (equipped items will be unequipped) AND all artifact blueprints/templates. This action cannot be undone. Are you sure?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentOrange),
                              child: const Text('CONFIRM PURGE')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      gameProvider.clearAllArtifactsAndTemplates(); // Updated method name
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'All owned artifacts and blueprints purged.'),
                            backgroundColor: AppTheme.fhAccentGreen));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentOrange,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.skullCrossbonesOutline,
                      size: 18, color: AppTheme.fhTextPrimary),
                  label: const Text('DECOMMISSION ENEMIES'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentOrange),
                          const SizedBox(width: 10),
                          const Text('Confirm Decommission')
                        ]),
                        content: const Text(
                            'This removes all enemy templates. The Arena might be empty until new content is generated. This action cannot be undone. Are you sure?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentOrange,
                                  foregroundColor: AppTheme.fhTextPrimary),
                              child: const Text('CONFIRM DECOMMISSION')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      gameProvider.removeAllEnemyTemplates();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'All enemy signatures decommissioned.'),
                                backgroundColor: AppTheme.fhAccentGreen));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentOrange,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon( 
                  icon: Icon(MdiIcons.earthRemove,
                      size: 18, color: AppTheme.fhTextPrimary),
                  label: const Text('DECOMMISSION ALL REALMS'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentOrange),
                          const SizedBox(width: 10),
                          const Text('Confirm Realm Decommission')
                        ]),
                        content: const Text(
                            'This removes ALL combat zones (realms). The Arena will be inaccessible until new realms are discovered/generated. This action cannot be undone. Are you sure?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentOrange,
                                  foregroundColor: AppTheme.fhTextPrimary),
                              child: const Text('CONFIRM DECOMMISSION')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      gameProvider.removeAllGameLocations();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'All realms decommissioned.'),
                                backgroundColor: AppTheme.fhAccentGreen));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentOrange,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
                 const SizedBox(height: 12),
                ElevatedButton.icon( // Reset Park Data button
                  icon: Icon(MdiIcons.island, // Changed icon to MdiIcons.island
                      size: 18, color: AppTheme.fhTextPrimary),
                  label: const Text('RESET JURASSIC PARK DATA'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentOrange),
                          const SizedBox(width: 10),
                          const Text('Confirm Park Reset')
                        ]),
                        content: const Text(
                            'This will reset all Jurassic Park data (owned dinosaurs, buildings, fossils, park rating, funds). Dinosaur species and building blueprints will remain. This action cannot be undone. Are you sure?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentOrange,
                                  foregroundColor: AppTheme.fhTextPrimary),
                              child: const Text('CONFIRM PARK RESET')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await gameProvider.resetParkData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Jurassic Park data has been reset.'),
                                backgroundColor: AppTheme.fhAccentGreen));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentOrange,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
              ]),
          _buildSettingsSection(gameProvider, theme,
              icon: MdiIcons.eyeSettingsOutline,
              title: 'User Interface Config',
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Verbose Data Display'),
                  subtitle: const Text(
                      'Show detailed descriptions for stats and items throughout the interface.'),
                  value: gameProvider.settings.descriptionsVisible,
                  onChanged: (value) => gameProvider.setSettings(
                      gameProvider.settings..descriptionsVisible = value),
                  activeColor: (gameProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
          if (gameProvider.currentUser != null)
            _buildSettingsSection(gameProvider, theme,
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
                        : () => _handleChangePassword(gameProvider),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (gameProvider.getSelectedTask()?.taskColor ??
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
                        : () => _handleLogout(gameProvider, context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.fhAccentOrange,
                        side: const BorderSide(
                            color: AppTheme.fhAccentOrange, width: 1.5),
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                ]),
          _buildSettingsSection(gameProvider, theme,
              icon: MdiIcons.databaseRemoveOutline,
              title: 'Data & System Reset',
              children: [
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.undoVariant, size: 18),
                  label: const Text('RESET PLAYER LEVEL'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(children: [
                          Icon(MdiIcons.alertOutline,
                              color: AppTheme.fhAccentOrange),
                          const SizedBox(width: 10),
                          const Text('Confirm Level Reset')
                        ]),
                        content: const Text(
                            'This will reset your player level to 1, XP to 0, and clear defeated enemies for the current level. Your tasks, items, and coins will remain. Are you sure?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentOrange),
                              child: const Text('CONFIRM RESET')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      gameProvider.resetPlayerLevelAndProgress();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Player level and progress reset.'),
                                backgroundColor: AppTheme.fhAccentGreen));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentOrange,
                      foregroundColor: AppTheme.fhTextPrimary,
                      minimumSize: const Size(double.infinity, 44)),
                ),
                const SizedBox(height: 16),
                Text(
                  'WARNING: The "Purge All Data" protocol will erase all operational data, including quest logs, experience, currency, and acquired assets. This action is irreversible and will reset the system to factory defaults.',
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
                      gameProvider.clearAllGameData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('All game data has been purged.'),
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

  Widget _buildSettingsSection(GameProvider gameProvider, ThemeData theme,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Card(
      // Using the globally themed Card
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: (gameProvider.getSelectedTask()?.taskColor ??
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