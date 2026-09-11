import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

class AccountAndDataSettingsSection extends StatefulWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const AccountAndDataSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  @override
  State<AccountAndDataSettingsSection> createState() =>
      _AccountAndDataSettingsSectionState();
}

class _AccountAndDataSettingsSectionState
    extends State<AccountAndDataSettingsSection> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordChangeLoading = false;
  String _passwordChangeError = '';
  String _passwordChangeSuccess = '';
  bool _logoutLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
      if (e is AuthFailure) {
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

  Future<void> _handleLogout(AppProvider appProvider) async {
    setState(() => _logoutLoading = true);
    try {
      await appProvider.logoutUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: AppTheme.fhAccentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = widget.appProvider;
    final theme = widget.theme;

    return Column(
      children: [
        // 9. CREDENTIALS
        if (appProvider.currentUser != null)
          SettingsSectionCard(
            icon: MdiIcons.shieldAccountOutline,
            title: 'Access Credentials',
            children: [
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Passcode Sequence',
                  prefixIcon: Icon(MdiIcons.formTextboxPassword, size: 20),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Passcode Sequence',
                  prefixIcon: Icon(MdiIcons.formTextboxPassword, size: 20),
                ),
                obscureText: true,
              ),
              if (_passwordChangeError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    _passwordChangeError,
                    style: TextStyle(
                      color: AppTheme.fhAccentRed,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_passwordChangeSuccess.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    _passwordChangeSuccess,
                    style: TextStyle(
                      color: AppTheme.fhAccentGreen,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _passwordChangeLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.fhTextPrimary,
                        ),
                      )
                    : Icon(MdiIcons.keyChange, size: 18),
                label: const Text('UPDATE PASSCODE'),
                onPressed: _passwordChangeLoading
                    ? null
                    : () => _handleChangePassword(appProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (appProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed),
                  foregroundColor: AppTheme.fhBgDark,
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: _logoutLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.fhAccentOrange,
                        ),
                      )
                    : Icon(MdiIcons.logoutVariant, size: 18),
                label: const Text('TERMINATE SESSION'),
                onPressed: _logoutLoading ? null : () => _handleLogout(appProvider),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.fhAccentOrange,
                  side: BorderSide(
                    color: AppTheme.fhAccentOrange,
                    width: 1.5,
                  ),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),

        // 10. DATA RESET
        SettingsSectionCard(
          icon: MdiIcons.databaseRemoveOutline,
          title: 'Data & System Reset',
          children: [
            Text(
              'WARNING: The "Purge All Data" protocol will erase all your data from the cloud, including missions, sub-quests, and logs. This action is irreversible.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.fhTextSecondary,
                height: 1.5,
              ),
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
                      Icon(MdiIcons.alertOutline, color: AppTheme.fhAccentRed),
                      const SizedBox(width: 10),
                      Text(
                        'Confirm System Purge',
                        style: TextStyle(color: AppTheme.fhAccentRed),
                      ),
                    ]),
                    content: const Text(
                      'Are you absolutely certain you wish to erase all data? This operation cannot be undone and will result in total loss of progress.',
                    ),
                    actionsAlignment: MainAxisAlignment.spaceBetween,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('CANCEL'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.fhAccentRed,
                          foregroundColor: AppTheme.fhTextPrimary,
                        ),
                        child: const Text('CONFIRM PURGE'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  appProvider.clearAllData();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('All data has been purged.'),
                      backgroundColor: AppTheme.fhAccentGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fhAccentRed,
                foregroundColor: AppTheme.fhTextPrimary,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
