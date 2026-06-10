import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/widget_action_router.dart';
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
    WidgetActionRouter.instance.tabRequest.removeListener(_onTabRequest);
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
      // Honor any tab change requested before this screen mounted (cold start
      // from a home-screen widget tap).
      _onTabRequest();
    });
    WidgetActionRouter.instance.tabRequest.addListener(_onTabRequest);
  }

  void _onTabRequest() {
    final req = WidgetActionRouter.instance.tabRequest.value;
    if (req == null) return;
    if (req < 0 || req > 4) return;
    if (mounted) {
      setState(() => _selectedIndex = req);
      if (req == 1) {
        _scheduleOpenTick.value++;
      }
    }
    WidgetActionRouter.instance.tabRequest.value = null;
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MoreScreen()),
    );
  }

  static final _desktopNavItems = <_DesktopNavItem>[
    _DesktopNavItem(label: 'MISSIONS', icon: MdiIcons.targetAccount),
    _DesktopNavItem(label: 'SCHEDULE', icon: MdiIcons.calendarClock),
    _DesktopNavItem(label: 'BIO', icon: MdiIcons.heartPulse),
    _DesktopNavItem(label: 'INTEL', icon: MdiIcons.notebookOutline),
    _DesktopNavItem(label: 'WALLET', icon: MdiIcons.walletOutline),
  ];

  Widget _buildDesktopNavRail(Color activeColor) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF08101C),
        border: Border(right: BorderSide(color: JweTheme.lineSoft, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(_desktopNavItems.length, (i) {
            final item = _desktopNavItems[i];
            final on = i == _selectedIndex;
            final color = on ? JweTheme.accentAmber : JweTheme.textMuted;
            return InkWell(
              onTap: () => _onItemTapped(i),
              splashColor: JweTheme.amberSoft,
              highlightColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (on)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: JweTheme.accentAmber,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 22, color: color),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              height: 1.0,
                              color: color,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
        endDrawer: const WellbeingDrawer(),
        body: Row(
          children: [
            if (isLargeScreen) _buildDesktopNavRail(currentTaskColor),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: widgetOptions,
              ),
            ),
          ],
        ),
        bottomNavigationBar: isLargeScreen
            ? null
            : JweBottomNavBar(
                selectedIndex: _selectedIndex,
                activeColor: currentTaskColor,
                onItemTapped: _onItemTapped,
              ),
      ),
    );
  }
}

class _DesktopNavItem {
  final String label;
  final IconData icon;
  const _DesktopNavItem({required this.label, required this.icon});
}