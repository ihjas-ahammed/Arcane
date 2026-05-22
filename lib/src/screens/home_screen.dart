import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/header_widget.dart';
import 'package:missions/src/widgets/task_navigation_drawer.dart';
import 'package:missions/src/widgets/drawers/wellbeing_drawer.dart';
import 'package:missions/src/widgets/ui/jwe_bottom_nav_bar.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/views/task_details_view.dart';
import 'package:missions/src/widgets/views/health_dashboard_view.dart';
import 'package:missions/src/widgets/views/schedule_view.dart';
import 'package:missions/src/screens/logbook_screen.dart';
import 'package:missions/src/screens/more_screen.dart'; 
import 'package:missions/src/screens/finance/finance_dashboard_screen.dart'; 
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppProvider _appProvider;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _scheduleOpenTick = ValueNotifier<int>(0);

  static const List<String> _viewTitles = <String>[
    'MISSIONS',
    'SCHEDULE',
    'BIOMETRICS',
    'ANALYTICS',
    'WALLET',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      _scheduleOpenTick.value++;
    }
  }

  @override
  void dispose() {
    _scheduleOpenTick.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _appProvider = Provider.of<AppProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appProvider.selectedTaskId == null &&
          _appProvider.mainTasks.isNotEmpty) {
        // FIX: Ensure default selected task is not soft-deleted
        final firstValid = _appProvider.mainTasks.firstWhereOrNull((t) => !t.isDeleted);
        if (firstValid != null) _appProvider.setSelectedTaskId(firstValid.id);
      }
    });
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
      ScheduleView(openTick: _scheduleOpenTick),
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const HealthDashboardView(),
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