import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/widgets/header_widget.dart';
import 'package:arcane/src/widgets/middle_panel_widget.dart'; // This will be adapted
import 'package:arcane/src/widgets/player_stats_drawer.dart';
import 'package:arcane/src/widgets/task_navigation_drawer.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/views/artifact_shop_view.dart';
import 'package:arcane/src/widgets/views/blacksmith_view.dart';
import 'package:arcane/src/widgets/views/game_view.dart';
import 'package:arcane/src/widgets/views/task_details_view.dart';
import 'package:arcane/src/widgets/views/park_view.dart'; // New Park View
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0; // For BottomNavigationBar or TabBar
  late GameProvider _gameProvider;
  final ScrollController _scrollController = ScrollController();
  bool _isUsernameDialogShowing = false;
  late TabController _tabController; // Add TabController

  final List<Map<String, dynamic>> _views = [
    {
      'label': 'MISSIONS',
      'value': 'task-details',
      'icon': MdiIcons.clipboardListOutline
    },
    {
      'label': 'ARMORY',
      'value': 'artifact-shop',
      'icon': MdiIcons.storefrontOutline
    },
    {'label': 'FORGE', 'value': 'blacksmith', 'icon': MdiIcons.hammerWrench},
    {'label': 'ARENA', 'value': 'game', 'icon': MdiIcons.swordCross},
    {'label': 'PARK', 'value': 'park', 'icon': MdiIcons.tree}, // Changed Park Icon
  ];

  @override
  void initState() {
    super.initState();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);

    _tabController = TabController(length: _views.length, vsync: this);

    _selectedIndex =
        _views.indexWhere((view) => view['value'] == _gameProvider.currentView);
    if (_selectedIndex == -1) {
      _selectedIndex = 0;
      _gameProvider.setCurrentView(_views[0]['value'] as String);
    }
    _tabController.index = _selectedIndex; // Set initial tab index

    // Listen to tab controller changes to update provider
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _selectedIndex) {
        // Only update if the index is actually changing by user interaction or a direct set.
        // Avoid redundant updates when _selectedIndex is already in sync.
        return;
      }
      setState(() {
        _selectedIndex = _tabController.index;
      });
      _gameProvider.setCurrentView(_views[_selectedIndex]['value'] as String);
      print(
          "[HomeScreen] TabController Listener: Updated selectedIndex to $_selectedIndex for view ${_views[_selectedIndex]['value']}");
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gameProvider.selectedTaskId == null &&
          _gameProvider.mainTasks.isNotEmpty) {
        _gameProvider.setSelectedTaskId(_gameProvider.mainTasks.first.id);
      }
      _checkAndPromptForUsername(_gameProvider);
    });
    _gameProvider.addListener(_handleProviderForUsernamePrompt);
    _gameProvider.addListener(_handleCurrentViewChangeFromProvider);

    print(
        "[HomeScreen] initState: Initial selectedIndex: $_selectedIndex, currentView: ${_gameProvider.currentView}");
  }

  void _handleProviderForUsernamePrompt() {
    _checkAndPromptForUsername(
        Provider.of<GameProvider>(context, listen: false));
  }

  void _handleCurrentViewChangeFromProvider() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final newIndex =
        _views.indexWhere((view) => view['value'] == gameProvider.currentView);
    if (newIndex != -1 && newIndex != _selectedIndex) {
      if (mounted) {
        setState(() {
          _selectedIndex = newIndex;
        });
        _tabController.animateTo(newIndex); // Animate to the new tab
        print(
            "[HomeScreen] _handleCurrentViewChangeFromProvider: Updated selectedIndex to $newIndex for view ${gameProvider.currentView}");
      }
    } else if (newIndex == -1 &&
        _views.indexWhere((v) => v['value'] == gameProvider.currentView) ==
            -1) {
      if (mounted && _selectedIndex != 0) {
        setState(() {
          _selectedIndex = 0;
        });
        _tabController.animateTo(0); // Animate to the first tab
        print(
            "[HomeScreen] _handleCurrentViewChangeFromProvider: currentView '${gameProvider.currentView}' not in tabs, defaulting to index 0.");
      }
    }
  }

  void _checkAndPromptForUsername(GameProvider gameProvider) {
    if (mounted &&
        gameProvider.isUsernameMissing &&
        gameProvider.currentUser != null &&
        !_isUsernameDialogShowing &&
        !gameProvider.authLoading &&
        !gameProvider.isDataLoadingAfterLogin) {
      print("[HomeScreen] Prompting for username.");
      setState(() {
        _isUsernameDialogShowing = true;
      });
      _showUsernameDialog(context, gameProvider).then((_) {
        if (mounted) {
          setState(() {
            _isUsernameDialogShowing = false;
          });
        }
      });
    }
  }

  Future<void> _showUsernameDialog(
      BuildContext context, GameProvider gameProvider) async {
    final TextEditingController usernameController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    print("[HomeScreen] Showing username dialog.");
    final Color currentAccentColor =
        gameProvider.getSelectedTask()?.taskColor ??
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
                  print(
                      "[HomeScreen] Username dialog confirmed with: $newUsername");
                  await gameProvider.updateUserDisplayName(newUsername);
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

  void _onItemTapped(int index) {
    if (index < 0 || index >= _views.length) return;
    print(
        "[HomeScreen] _onItemTapped: index $index, view value: ${_views[index]['value']}");
    setState(() {
      _selectedIndex = index;
    });
    _gameProvider.setCurrentView(_views[index]['value'] as String);
     _tabController.animateTo(index); // Sync TabController on BottomNav tap for smaller screens
  }

  @override
  void dispose() {
    _gameProvider.removeListener(_handleProviderForUsernamePrompt);
    _gameProvider.removeListener(_handleCurrentViewChangeFromProvider);
    _scrollController.dispose();
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;

    final gameProvider = context.watch<GameProvider>();
    final Color currentTaskColor =
        gameProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;
    final ThemeData dynamicTheme =
        AppTheme.getThemeData(primaryAccent: currentTaskColor);

    print(
        "[HomeScreen] build: SelectedIndex: $_selectedIndex, CurrentView from provider: ${gameProvider.currentView}");

    return Theme(
      data: dynamicTheme,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              HeaderWidget(
                  currentViewLabel: _views.isNotEmpty &&
                          _selectedIndex >= 0 &&
                          _selectedIndex < _views.length
                      ? _views[_selectedIndex]['label'] as String
                      : "MISSIONS"),
              Expanded(
                child: isLargeScreen
                    ? Row(
                        children: [
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
                            child: Column(
                              // New: Column for TabBar and TabBarView
                              children: [
                                Container(
                                  color: dynamicTheme.cardTheme.color,
                                  child: TabBar(
                                    controller: _tabController,
                                    isScrollable: false,
                                    indicatorColor:
                                        dynamicTheme.colorScheme.secondary,
                                    labelColor:
                                        dynamicTheme.colorScheme.secondary,
                                    unselectedLabelColor: dynamicTheme
                                        .textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                    tabs: _views.map((view) {
                                      return Tab(
                                        icon: Icon(view['icon'] as IconData),
                                        text: view['label'] as String,
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Expanded(
                                  // Ensure TabBarView takes remaining space
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: _views
                                        .map<Widget>((v) => MiddlePanelWidget(
                                            selectedIndex: _views.indexOf(v),
                                            views: _views
                                                .map<Widget>((v) =>
                                                    _getViewWidget(
                                                        v['value'] as String))
                                                .toList()))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 320,
                            decoration: BoxDecoration(
                              color: dynamicTheme.cardTheme.color,
                              border: Border(
                                  left: BorderSide(
                                      color: dynamicTheme.dividerTheme.color ??
                                          AppTheme.fhBorderColor,
                                      width: 1)),
                            ),
                            child: const PlayerStatsDrawer(),
                          ),
                        ],
                      )
                    : MiddlePanelWidget(
                        selectedIndex: _selectedIndex,
                        views: _views
                            .map<Widget>(
                                (v) => _getViewWidget(v['value'] as String))
                            .toList()),
              ),
            ],
          ),
        ),
        drawer: isLargeScreen ? null : const TaskNavigationDrawer(),
        endDrawer: isLargeScreen ? null : const PlayerStatsDrawer(),
        bottomNavigationBar: isLargeScreen
            ? null
            : BottomNavigationBar(
                items: _views.map((view) {
                  return BottomNavigationBarItem(
                    icon: Icon(view['icon'] as IconData),
                    label: view['label'] as String,
                  );
                }).toList(),
                currentIndex: _selectedIndex.clamp(0, _views.length - 1),
                onTap: _onItemTapped,
              ),
      ),
    );
  }

  Widget _getViewWidget(String viewValue) {
    switch (viewValue) {
      case 'task-details':
        return const TaskDetailsView();
      case 'artifact-shop':
        return const ArtifactShopView();
      case 'blacksmith':
        return const BlacksmithView();
      case 'game':
        return const GameView();
      case 'park': // New Park View
        return const ParkView(); 
      default:
        if (_views.isNotEmpty) {
          return _getViewWidget(_views[0]['value'] as String);
        }
        return const Center(child: Text('Unknown View'));
    }
  }
}
