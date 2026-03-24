import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/header_widget.dart';
import 'package:arcane/src/widgets/task_navigation_drawer.dart';
import 'package:arcane/src/widgets/drawers/wellbeing_drawer.dart';
import 'package:arcane/src/widgets/ui/jwe_bottom_nav_bar.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/views/task_details_view.dart';
import 'package:arcane/src/widgets/views/projects_view.dart';
import 'package:arcane/src/widgets/views/schedule_view.dart';
import 'package:arcane/src/screens/logbook_screen.dart';
import 'package:arcane/src/screens/more_screen.dart'; 
import 'package:arcane/src/screens/finance/finance_dashboard_screen.dart'; 
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppProvider _appProvider;
  bool _isUsernameDialogShowing = false;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<String> _viewTitles = <String>[
    'MISSIONS',
    'SCHEDULE',
    'PROJECTS',
    'ANALYTICS',
    'WALLET',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
    _checkAndPromptForUsername(
        Provider.of<AppProvider>(context, listen: false));
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
    final Color currentAccentColor = appProvider.getSelectedTask()?.taskColor ??
        JweTheme.accentCyan;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: Border.all(color: currentAccentColor, width: 2),
          title: Text('SET CALLSIGN',
              style: TextStyle(color: currentAccentColor, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: usernameController,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                hintText: "Enter callsign (username)",
                hintStyle: TextStyle(color: JweTheme.textMuted.withOpacity(0.5)),
                filled: true,
                fillColor: JweTheme.bgBase,
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: currentAccentColor)),
              ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: currentAccentColor,
                foregroundColor: Colors.black,
                shape: const BeveledRectangleBorder()
              ),
              child: const Text('CONFIRM CALLSIGN', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  String newUsername = usernameController.text.trim();
                  Navigator.of(dialogContext).pop();
                  await appProvider.updateUserDisplayName(newUsername);
                  if (!mounted) return;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Callsign updated!'),
                          backgroundColor: JweTheme.accentCyan),
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

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MoreScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;

    final appProvider = context.watch<AppProvider>();
    final Color currentTaskColor =
        appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentCyan;
    final ThemeData dynamicTheme =
        AppTheme.getThemeData(primaryAccent: currentTaskColor);

    final List<Widget> widgetOptions = <Widget>[
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: const TaskDetailsView(),
        ),
      ),
      const ScheduleView(),
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: const ProjectsView(),
        ),
      ),
      const LogbookScreen(), 
      const FinanceDashboardScreen(),
    ];

    return Theme(
      data: dynamicTheme.copyWith(scaffoldBackgroundColor: JweTheme.bgBase),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: JweTheme.bgBase,
        appBar: HeaderWidget(
          currentViewLabel: _viewTitles[_selectedIndex],
          onOpenPersona: () => _scaffoldKey.currentState?.openEndDrawer(),
          customAction: IconButton(
            icon:  Icon(MdiIcons.cogOutline, color: JweTheme.textMuted),
            tooltip: "SYSTEM SETTINGS",
            onPressed: _navigateToSettings,
          ),
        ),
        drawer: isLargeScreen ? null : const TaskNavigationDrawer(),
        endDrawer: const WellbeingDrawer(),
        body: Row(
          children: [
            if (isLargeScreen)
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  border: Border(
                      right: BorderSide(
                          color: JweTheme.border,
                          width: 1)),
                ),
                child: const TaskNavigationDrawer(),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: widgetOptions,
              ),
            ),
          ],
        ),
        bottomNavigationBar: JweBottomNavBar(
          selectedIndex: _selectedIndex,
          activeColor: currentTaskColor,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}