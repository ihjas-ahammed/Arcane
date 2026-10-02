import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_provider.dart';
import '../../services/assistant_routing_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/jwe_theme.dart';
import '../../widgets/valorant/valorant_button.dart';

/// Screen allowing the operator to inspect all installed applications, filter
/// by search query and category, inspect all declared Activities inside a
/// selected app, and assign a specific Activity as the Bluetooth voice target.
class CustomAssistantPickerScreen extends StatefulWidget {
  const CustomAssistantPickerScreen({super.key});

  @override
  State<CustomAssistantPickerScreen> createState() => _CustomAssistantPickerScreenState();
}

class _CustomAssistantPickerScreenState extends State<CustomAssistantPickerScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<InstalledAppInfo> _allApps = [];
  List<InstalledAppInfo> _filteredApps = [];
  bool _isLoadingApps = true;

  InstalledAppInfo? _selectedApp;
  List<AppActivityInfo> _appActivities = [];
  List<AppActivityInfo> _filteredActivities = [];
  bool _isLoadingActivities = false;

  AppActivityInfo? _selectedActivity; // null means "Default Launch / Voice Mode"
  String _activeFilter = 'all'; // 'all', 'user', 'assistants'
  String _searchQuery = '';
  Map<String, dynamic>? _recordedTapInfo;
  Map<String, dynamic>? _unlockGestureInfo;
  bool _canDrawOverlays = true;
  String _calibrationMethod = 'reticle'; // 'reticle', 'touch_sensor', 'auto_detect', 'manual_coords'
  String _overlayWindowType = 'auto'; // 'auto', 'application', 'accessibility'
  double _manualXRatio = 0.5;
  double _manualYRatio = 0.85;
  bool _showManualTuner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AssistantRoutingService.instance.canDrawOverlays().then((can) {
        if (mounted) setState(() => _canDrawOverlays = can);
      });
      _refreshUnlockGestureInfo();
      if (_selectedApp != null) {
        _refreshRecordedTapInfo(_selectedApp!.package);
      }
    }
  }

  Future<void> _refreshUnlockGestureInfo() async {
    final info = await AssistantRoutingService.instance.getUnlockGestureInfo();
    if (mounted) {
      setState(() => _unlockGestureInfo = info);
    }
  }

  Future<void> _loadInitialState() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final customPkg = appProvider.settings.bluetoothAssistantCustomPackage.trim();
    final customAct = appProvider.settings.bluetoothAssistantCustomActivity.trim();

    final canDraw = await AssistantRoutingService.instance.canDrawOverlays();
    final method = await AssistantRoutingService.instance.getCalibrationMethod();
    final winType = await AssistantRoutingService.instance.getOverlayWindowType();
    final unlockInfo = await AssistantRoutingService.instance.getUnlockGestureInfo();

    setState(() => _isLoadingApps = true);
    final apps = await AssistantRoutingService.instance.getAllInstalledApps();

    if (!mounted) return;
    setState(() {
      _canDrawOverlays = canDraw;
      _calibrationMethod = method;
      _overlayWindowType = winType;
      _unlockGestureInfo = unlockInfo;
      _allApps = apps;
      _isLoadingApps = false;
      _applyAppFilter();

      // Pre-select if already configured
      if (customPkg.isNotEmpty) {
        final match = apps.where((a) => a.package == customPkg);
        if (match.isNotEmpty) {
          _selectedApp = match.first;
          _loadActivitiesForApp(_selectedApp!, preselectActivityName: customAct);
        }
      }
    });
  }

  void _applyAppFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filteredApps = _allApps.where((app) {
        final matchesQuery = q.isEmpty ||
            app.label.toLowerCase().contains(q) ||
            app.package.toLowerCase().contains(q);

        if (!matchesQuery) return false;

        if (_activeFilter == 'user') {
          return !app.isSystem;
        } else if (_activeFilter == 'assistants') {
          final isAssist = app.label.toLowerCase().contains('assist') ||
              app.label.toLowerCase().contains('ai') ||
              app.label.toLowerCase().contains('chat') ||
              app.package.toLowerCase().contains('chatgpt') ||
              app.package.toLowerCase().contains('claude') ||
              app.package.toLowerCase().contains('copilot') ||
              app.package.toLowerCase().contains('perplexity') ||
              app.package.toLowerCase().contains('google') ||
              app.package.toLowerCase().contains('voice');
          return isAssist;
        }
        return true;
      }).toList();
    });
  }

  void _applyActivityFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filteredActivities = _appActivities.where((act) {
        if (q.isEmpty) return true;
        return act.label.toLowerCase().contains(q) ||
            act.name.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _loadActivitiesForApp(InstalledAppInfo app, {String? preselectActivityName}) async {
    setState(() {
      _selectedApp = app;
      _isLoadingActivities = true;
      _selectedActivity = null;
      _searchController.clear();
      _searchQuery = '';
    });

    final activities = await AssistantRoutingService.instance.getAppActivities(app.package);

    if (!mounted) return;
    AppActivityInfo? preselected;
    if (preselectActivityName != null && preselectActivityName.isNotEmpty) {
      final match = activities.where((a) => a.name == preselectActivityName);
      if (match.isNotEmpty) {
        preselected = match.first;
      }
    }

    setState(() {
      _appActivities = activities;
      _filteredActivities = activities;
      _selectedActivity = preselected;
      _isLoadingActivities = false;
    });
    _refreshRecordedTapInfo(app.package);
  }

  Future<void> _refreshRecordedTapInfo(String pkg) async {
    final info = await AssistantRoutingService.instance.getRecordedTapInfo(pkg);
    if (!mounted) return;
    setState(() {
      _recordedTapInfo = info;
      if (info != null) {
        _manualXRatio = (info['xRatio'] as num?)?.toDouble() ?? 0.5;
        _manualYRatio = (info['yRatio'] as num?)?.toDouble() ?? 0.85;
      }
    });
  }

  void _backToAppList() {
    setState(() {
      _selectedApp = null;
      _appActivities = [];
      _filteredActivities = [];
      _selectedActivity = null;
      _searchController.clear();
      _searchQuery = '';
      _applyAppFilter();
    });
  }

  Future<void> _saveSelection() async {
    if (_selectedApp == null) return;
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    final pkg = _selectedApp!.package;
    final act = _selectedActivity?.name ?? '';

    setState(() {
      appProvider.settings.bluetoothAssistantRedirectTarget = 'custom';
      appProvider.settings.bluetoothAssistantCustomPackage = pkg;
      appProvider.settings.bluetoothAssistantCustomActivity = act;
    });
    appProvider.setSettings(appProvider.settings);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bluetooth_assistant_redirect_target', 'custom');
    await prefs.setString('bluetooth_assistant_custom_package', pkg);
    await prefs.setString('bluetooth_assistant_custom_activity', act);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          act.isEmpty
              ? 'Saved Custom Assistant: ${_selectedApp!.label}'
              : 'Saved Custom Assistant: ${_selectedApp!.label} (${_selectedActivity!.simpleName})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, true);
  }

  Future<void> _testLaunch() async {
    if (_selectedApp == null) return;
    final actName = _selectedActivity?.name;

    final launched = await AssistantRoutingService.instance.launchVoiceMode(
      _selectedApp!.package,
      activity: actName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? 'Target launched successfully in voice mode.'
              : 'Failed to launch target activity.',
        ),
        backgroundColor: launched
            ? (JweTheme.isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple)
            : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = JweTheme.isLight;
    final bgColor = isLight ? JweTheme.bgCanvas : AppTheme.fhBgDeepDark;
    final panelColor = isLight ? JweTheme.panel : AppTheme.fhBgDark;
    final cardColor = isLight ? JweTheme.panel2 : AppTheme.fhBgMedium;
    final borderColor = isLight ? JweTheme.border : AppTheme.fhAccentPurple.withValues(alpha: 0.3);
    final primaryTextColor = isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary;
    final secondaryTextColor = isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary;
    final accentColor = isLight ? JweTheme.accentCyan : AppTheme.fhAccentPurple;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _selectedApp != null ? Icons.arrow_back : Icons.close,
            color: primaryTextColor,
          ),
          onPressed: () {
            if (_selectedApp != null) {
              _backToAppList();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedApp == null ? "SELECT CUSTOM APP" : "SELECT ACTIVITY",
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            Text(
              _selectedApp == null
                  ? "Choose an installed app for Bluetooth redirection"
                  : "${_selectedApp!.label} (${_selectedApp!.package})",
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedApp != null)
            IconButton(
              icon: Icon(Icons.rocket_launch, color: accentColor),
              tooltip: "Test Launch",
              onPressed: _testLaunch,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: panelColor,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(color: primaryTextColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _selectedApp == null
                        ? "Search applications or packages..."
                        : "Search activities in ${_selectedApp!.label}...",
                    hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 20, color: accentColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: secondaryTextColor),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              if (_selectedApp == null) {
                                _applyAppFilter();
                              } else {
                                _applyActivityFilter();
                              }
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentColor, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                    if (_selectedApp == null) {
                      _applyAppFilter();
                    } else {
                      _applyActivityFilter();
                    }
                  },
                ),

                // Filter Chips (Only in App list mode)
                if (_selectedApp == null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFilterChip('all', 'ALL APPS (${_allApps.length})', accentColor, primaryTextColor, secondaryTextColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('user', 'USER APPS', accentColor, primaryTextColor, secondaryTextColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('assistants', 'ASSISTANTS / AI', accentColor, primaryTextColor, secondaryTextColor),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Main Content View
          Expanded(
            child: _selectedApp == null
                ? _buildAppListView(panelColor, cardColor, borderColor, primaryTextColor, secondaryTextColor, accentColor)
                : _buildActivityListView(panelColor, cardColor, borderColor, primaryTextColor, secondaryTextColor, accentColor),
          ),

          // Bottom Action Bar (when App is selected)
          if (_selectedApp != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panelColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "SELECTED TARGET",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _selectedActivity == null
                                ? "${_selectedApp!.label} (Auto Voice)"
                                : "${_selectedApp!.label} · ${_selectedActivity!.simpleName}",
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ValorantButton(
                      label: "CONFIRM TARGET",
                      icon: Icons.check,
                      color: accentColor,
                      onPressed: _saveSelection,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color accentColor, Color primaryTextColor, Color secondaryTextColor) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = key);
        _applyAppFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : secondaryTextColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : secondaryTextColor,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildAppListView(
    Color panelColor,
    Color cardColor,
    Color borderColor,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    if (_isLoadingApps) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: accentColor),
            const SizedBox(height: 12),
            Text("SCANNING INSTALLED APPS...", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
          ],
        ),
      );
    }

    if (_filteredApps.isEmpty) {
      return Center(
        child: Text("NO APPLICATIONS MATCH SEARCH", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredApps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        final initial = app.label.isNotEmpty ? app.label[0].toUpperCase() : '?';

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _loadActivitiesForApp(app),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // App Initial Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),

                // App details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              app.label,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (app.isSystem) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: secondaryTextColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "SYS",
                                style: TextStyle(color: secondaryTextColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.package,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 10,
                          fontFamily: 'RobotoMono',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityListView(
    Color panelColor,
    Color cardColor,
    Color borderColor,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    if (_isLoadingActivities) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: accentColor),
            const SizedBox(height: 12),
            Text("EXTRACTING DECLARED ACTIVITIES...", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // App header bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.apps, color: accentColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedApp!.label,
                      style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _selectedApp!.package,
                      style: TextStyle(color: secondaryTextColor, fontSize: 10, fontFamily: 'RobotoMono'),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _backToAppList,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text("CHANGE", style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: accentColor),
              ),
            ],
          ),
        ),
        // First-Time Tap Recording Card for external AI
        _buildRecordedTapCard(panelColor, cardColor, borderColor, primaryTextColor, secondaryTextColor, accentColor),

        // Lock Screen Unlock Gesture Card
        _buildUnlockGestureCard(panelColor, cardColor, borderColor, primaryTextColor, secondaryTextColor, accentColor),

        // Default Auto Voice option
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedActivity = null),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _selectedActivity == null ? accentColor.withValues(alpha: 0.12) : cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedActivity == null ? accentColor : borderColor,
                width: _selectedActivity == null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_mode,
                  color: _selectedActivity == null ? accentColor : secondaryTextColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Default Launch & Voice Auto-Detect",
                        style: TextStyle(
                          color: _selectedActivity == null ? accentColor : primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Automatically triggers voice assist or app main entrypoint with voice extras.",
                        style: TextStyle(color: secondaryTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Radio<AppActivityInfo?>(
                  value: null,
                  groupValue: _selectedActivity,
                  activeColor: accentColor,
                  onChanged: (val) => setState(() => _selectedActivity = null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            "DECLARED ACTIVITIES (${_filteredActivities.length})",
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),

        if (_filteredActivities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                "No declared activities match query",
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
            ),
          )
        else
          ..._filteredActivities.map((act) {
            final isSelected = _selectedActivity?.name == act.name;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selectedActivity = act),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor.withValues(alpha: 0.12) : cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? accentColor : borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        act.isVoiceOrAssist ? Icons.mic : (act.exported ? Icons.open_in_new : Icons.lock_outline),
                        color: act.isVoiceOrAssist ? accentColor : secondaryTextColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    act.simpleName,
                                    style: TextStyle(
                                      color: isSelected ? accentColor : primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (act.isVoiceOrAssist) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "VOICE",
                                      style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                if (act.exported) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "EXPORTED",
                                      style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.name,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Radio<AppActivityInfo?>(
                        value: act,
                        groupValue: _selectedActivity,
                        activeColor: accentColor,
                        onChanged: (val) => setState(() => _selectedActivity = val),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _startRecording(Color accentColor) async {
    if (_selectedApp == null) return;
    final pkg = _selectedApp!.package;
    final label = _selectedApp!.label;

    if (_calibrationMethod == 'manual_coords') {
      setState(() => _showManualTuner = true);
      return;
    }

    final ok = await AssistantRoutingService.instance.startRecordingTap(pkg, method: _calibrationMethod);
    if (ok && mounted) {
      final hint = _calibrationMethod == 'reticle'
          ? "Drag the crosshair reticle over the mic button and tap [✓ LOCK TARGET]"
          : (_calibrationMethod == 'touch_sensor'
              ? "Touch Sensor active: Tap the mic button once on screen"
              : "Tap the voice/mic button inside $label, then tap [SAVE]");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Calibrating $label: $hint"),
          backgroundColor: accentColor,
          duration: const Duration(seconds: 4),
        ),
      );
      await AssistantRoutingService.instance.launchPackage(pkg);
    }
  }

  Widget _buildRecordedTapCard(
    Color panelColor,
    Color cardColor,
    Color borderColor,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    final isRecorded = _recordedTapInfo != null;
    final info = _recordedTapInfo;
    final xPct = ((info?['xRatio'] as num? ?? _manualXRatio) * 100).toInt();
    final yPct = ((info?['yRatio'] as num? ?? _manualYRatio) * 100).toInt();
    final tag = info?['viewId'] ?? info?['desc'] ?? (info != null ? 'Coordinates ($xPct%, $yPct%)' : '');

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRecorded
            ? (JweTheme.isLight ? Colors.green.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.08))
            : cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRecorded
              ? (JweTheme.isLight ? Colors.green.withValues(alpha: 0.7) : Colors.green.withValues(alpha: 0.6))
              : accentColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Permission Alert Banner ─────────────────────────────────────────
          if (!_canDrawOverlays) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? const Color(0xFFFFF3E0) : const Color(0x33FFA726),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: JweTheme.isLight ? const Color(0xFFF57C00) : const Color(0xFFFFA726),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: JweTheme.isLight ? const Color(0xFFE65100) : const Color(0xFFFFB74D),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OVERLAY PERMISSION REQUIRED",
                          style: TextStyle(
                            color: JweTheme.isLight ? const Color(0xFFE65100) : const Color(0xFFFFB74D),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Grant 'Display over other apps' so Arcane can draw crosshairs and sensors over target apps.",
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await AssistantRoutingService.instance.openOverlaySettings();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: JweTheme.isLight ? const Color(0xFFE65100) : const Color(0xFFFFB74D),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text("GRANT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          // ── Status Header ───────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                isRecorded ? Icons.check_circle : Icons.gps_fixed,
                color: isRecorded ? (JweTheme.isLight ? const Color(0xFF1B5E20) : Colors.green) : accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRecorded ? "VOICE SWITCH AUTO-TAP ACTIVE" : "CALIBRATE VOICE SWITCH TAP",
                  style: TextStyle(
                    color: isRecorded ? (JweTheme.isLight ? const Color(0xFF1B5E20) : Colors.green) : accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isRecorded
                ? "Saved Target: $tag\nArcane will automatically click this voice switch via touch gesture whenever triggered."
                : "Choose a calibration tracking method below to record the microphone/voice button in this application:",
            style: TextStyle(color: secondaryTextColor, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12),

          // ── Calibration Method Selector ─────────────────────────────────────
          Text(
            "INPUT TRACKING METHOD",
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMethodChip(
                id: 'reticle',
                label: '🎯 Reticle',
                subtitle: 'Draggable crosshair (Overcomes app touch block)',
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              _buildMethodChip(
                id: 'touch_sensor',
                label: '👆 Touch Sensor',
                subtitle: 'One-tap transparent coordinate interceptor',
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              _buildMethodChip(
                id: 'auto_detect',
                label: '🔍 Auto-Detect',
                subtitle: 'Accessibility click event listener',
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              _buildMethodChip(
                id: 'manual_coords',
                label: '📐 Manual Coords',
                subtitle: 'Normalized X% & Y% slider tuner',
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Window Type & Advanced Tuning ───────────────────────────────────
          Row(
            children: [
              Text(
                "OVERLAY TYPE: ",
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              DropdownButton<String>(
                value: _overlayWindowType,
                underline: const SizedBox.shrink(),
                isDense: true,
                dropdownColor: panelColor,
                style: TextStyle(color: primaryTextColor, fontSize: 11),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text("Auto (Recommended)")),
                  DropdownMenuItem(value: 'application', child: Text("System Alert Window")),
                  DropdownMenuItem(value: 'accessibility', child: Text("Accessibility Overlay")),
                ],
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _overlayWindowType = val);
                  await AssistantRoutingService.instance.setOverlayWindowType(val);
                },
              ),
              const Spacer(),
              if (isRecorded)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showManualTuner = !_showManualTuner);
                  },
                  icon: Icon(_showManualTuner ? Icons.expand_less : Icons.tune, size: 14),
                  label: Text(_showManualTuner ? "HIDE TUNER" : "TWEAK COORDS", style: const TextStyle(fontSize: 10.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
            ],
          ),

          // ── Manual Coordinate Tuner Sliders ─────────────────────────────────
          if (_showManualTuner || _calibrationMethod == 'manual_coords') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "MANUAL COORDINATE TUNER",
                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "X: ${(_manualXRatio * 100).toInt()}%  |  Y: ${(_manualYRatio * 100).toInt()}%",
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 10.5,
                          fontFamily: 'RobotoMono',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 38,
                        child: Text("X Pos", style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _manualXRatio.clamp(0.01, 0.99),
                          min: 0.01,
                          max: 0.99,
                          activeColor: accentColor,
                          onChanged: (v) => setState(() => _manualXRatio = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 38,
                        child: Text("Y Pos", style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _manualYRatio.clamp(0.01, 0.99),
                          min: 0.01,
                          max: 0.99,
                          activeColor: accentColor,
                          onChanged: (v) => setState(() => _manualYRatio = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (_selectedApp == null) return;
                            await AssistantRoutingService.instance.setManualCoordinates(
                              _selectedApp!.package,
                              _manualXRatio,
                              _manualYRatio,
                            );
                            await _refreshRecordedTapInfo(_selectedApp!.package);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Saved tap coordinates: (${(_manualXRatio * 100).toInt()}%, ${(_manualYRatio * 100).toInt()}%)",
                                  ),
                                  backgroundColor: accentColor,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save, size: 13),
                          label: const Text("APPLY COORDS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: JweTheme.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (_selectedApp == null) return;
                            await AssistantRoutingService.instance.launchVoiceMode(_selectedApp!.package);
                          },
                          icon: const Icon(Icons.play_arrow, size: 14),
                          label: const Text("TEST TAP", style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryTextColor,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Action Buttons ──────────────────────────────────────────────────
          Row(
            children: [
              if (isRecorded) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_selectedApp == null) return;
                      await AssistantRoutingService.instance.launchVoiceMode(_selectedApp!.package);
                    },
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text("TEST TAP", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startRecording(accentColor),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text("RECALIBRATE", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_selectedApp == null) return;
                      await AssistantRoutingService.instance.clearRecordedTap(_selectedApp!.package);
                      await _refreshRecordedTapInfo(_selectedApp!.package);
                    },
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text("CLEAR", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => _startRecording(accentColor),
                    icon: const Icon(Icons.adjust, size: 14),
                    label: const Text("CALIBRATE MIC TAP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: JweTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_selectedApp == null) return;
                      await AssistantRoutingService.instance.launchPackage(_selectedApp!.package);
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text("TEST LAUNCH", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip({
    required String id,
    required String label,
    required String subtitle,
    required Color accentColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final isSelected = _calibrationMethod == id;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        setState(() {
          _calibrationMethod = id;
          if (id == 'manual_coords') _showManualTuner = true;
        });
        await AssistantRoutingService.instance.setCalibrationMethod(id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.16) : cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : primaryTextColor,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockGestureCard(
    Color panelColor,
    Color cardColor,
    Color borderColor,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    final isUnlockRecorded = _unlockGestureInfo != null;
    final info = _unlockGestureInfo;
    final fromPct = info != null ? (((info['startY'] as num?)?.toDouble() ?? 0.85) * 100).toInt() : 85;
    final toPct = info != null ? (((info['endY'] as num?)?.toDouble() ?? 0.20) * 100).toInt() : 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlockRecorded
            ? (JweTheme.isLight ? Colors.green.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.08))
            : cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnlockRecorded
              ? (JweTheme.isLight ? Colors.green.withValues(alpha: 0.7) : Colors.green.withValues(alpha: 0.6))
              : accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUnlockRecorded ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: isUnlockRecorded
                    ? (JweTheme.isLight ? const Color(0xFF1B5E20) : Colors.green)
                    : accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUnlockRecorded
                      ? "LOCK SCREEN UNLOCK GESTURE ACTIVE"
                      : "LOCK SCREEN UNLOCK CALIBRATION",
                  style: TextStyle(
                    color: isUnlockRecorded
                        ? (JweTheme.isLight ? const Color(0xFF1B5E20) : Colors.green)
                        : accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (isUnlockRecorded)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.redAccent,
                  tooltip: "Clear Unlock Gesture",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await AssistantRoutingService.instance.clearUnlockGesture();
                    await _refreshUnlockGestureInfo();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cleared lock screen unlock gesture.")),
                      );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isUnlockRecorded
                ? "Two-Step Automated Movement:\n"
                  "  1. Screen auto-unlock (Swipe Up: $fromPct% → $toPct%)\n"
                  "  2. Launch assistant & auto-click voice switch"
                : "When external assistant is triggered while device is locked (smartwatch/Bluetooth):\n"
                  "Arcane will automatically execute two movements:\n"
                  "  1. Unlock screen (Swipe Up)\n"
                  "  2. Click voice switch inside external assistant",
            style: TextStyle(color: secondaryTextColor, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmAndStartUnlockCalibration(accentColor),
                  icon: Icon(isUnlockRecorded ? Icons.refresh : Icons.swipe_up, size: 15),
                  label: Text(
                    isUnlockRecorded ? "RECALIBRATE" : "CALIBRATE UNLOCK",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: JweTheme.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (isUnlockRecorded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await AssistantRoutingService.instance.testUnlockGesture();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? "Testing unlock sequence..." : "Failed to trigger test."),
                            backgroundColor: accentColor,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 15),
                    label: const Text("TEST UNLOCK", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndStartUnlockCalibration(Color accentColor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.isLight ? JweTheme.panel : AppTheme.fhBgDark,
        title: Row(
          children: [
            Icon(Icons.screen_lock_portrait, color: accentColor, size: 22),
            const SizedBox(width: 8),
            Text(
              "CALIBRATE UNLOCK GESTURE",
              style: TextStyle(
                color: JweTheme.isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "How calibration works:\n\n"
          "1. Arcane will lock your screen.\n"
          "2. The screen will turn on with a tactical banner.\n"
          "3. Perform your unlock movement (e.g. swipe up).\n"
          "4. Once your screen unlocks, Arcane automatically records and saves the gesture.\n\n"
          "Make sure Arcane is switched ON in Accessibility Settings.",
          style: TextStyle(
            color: JweTheme.isLight ? JweTheme.textMid : AppTheme.fhTextSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: JweTheme.onAccent,
            ),
            child: const Text("LOCK & RECORD", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final started = await AssistantRoutingService.instance.startRecordingUnlockGesture();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not start calibration. Ensure Arcane has Accessibility enabled."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
