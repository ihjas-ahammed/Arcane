import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/header_widget.dart';
import 'package:arcane/src/widgets/task_navigation_drawer.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/views/task_details_view.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppProvider _appProvider;
  bool _isUsernameDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _appProvider = Provider.of<AppProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appProvider.selectedTaskId == null &&
          _appProvider.mainTasks.isNotEmpty) {
        _appProvider.setSelectedTaskId(_appProvider.mainTasks.first.id);
      }
      _checkAndPromptForUsername(_appProvider);
    });
    _appProvider.addListener(_handleProviderForUsernamePrompt);
  }

  void _handleProviderForUsernamePrompt() {
    _checkAndPromptForUsername(Provider.of<AppProvider>(context, listen: false));
  }

  void _checkAndPromptForUsername(AppProvider appProvider) {
    if (mounted &&
        appProvider.isUsernameMissing &&
        appProvider.currentUser != null &&
        !_isUsernameDialogShowing &&
        !appProvider.authLoading &&
        !appProvider.isDataLoadingAfterLogin) {
      setState(() => _isUsernameDialogShowing = true);
      _showUsernameDialog(context, appProvider).then((_) {
        if (mounted) setState(() => _isUsernameDialogShowing = false);
      });
    }
  }

  Future<void> _showUsernameDialog(
      BuildContext context, AppProvider appProvider) async {
    final TextEditingController usernameController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    final Color currentAccentColor =
        appProvider.getSelectedTask()?.taskColor ??
            Theme.of(context).colorScheme.secondary;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Set Your Callsign',
              style: TextStyle(color: currentAccentColor)),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: usernameController,
              decoration:
                  const InputDecoration(hintText: "Enter callsign (username)"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Callsign cannot be empty.';
                }
                if (value.trim().length < 3) {
                  return 'Must be at least 3 characters.';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: currentAccentColor),
              child: Text('CONFIRM CALLSIGN',
                  style: TextStyle(
                      color: ThemeData.estimateBrightnessForColor(
                                  currentAccentColor) ==
                              Brightness.dark
                          ? AppTheme.fhTextPrimary
                          : AppTheme.fhBgDark)),
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  String newUsername = usernameController.text.trim();
                  Navigator.of(dialogContext).pop();
                  await appProvider.updateUserDisplayName(newUsername);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Callsign updated!'),
                          backgroundColor: AppTheme.fhAccentGreen),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _appProvider.removeListener(_handleProviderForUsernamePrompt);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;

    final appProvider = context.watch<AppProvider>();
    final Color currentTaskColor =
        appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;
    final ThemeData dynamicTheme =
        AppTheme.getThemeData(primaryAccent: currentTaskColor);

    return Theme(
      data: dynamicTheme,
      child: Scaffold(
        appBar: const HeaderWidget(currentViewLabel: "MISSIONS"),
        drawer: isLargeScreen ? null : const TaskNavigationDrawer(),
        body: SafeArea(
          child: Row(
            children: [
              if (isLargeScreen)
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: dynamicTheme.cardTheme.color,
                    border: Border(
                        right: BorderSide(
                            color: dynamicTheme.dividerTheme.color ??
                                AppTheme.fhBorderColor,
                            width: 1)),
                  ),
                  child: const TaskNavigationDrawer(),
                ),
               Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 800),
                    child: TaskDetailsView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}