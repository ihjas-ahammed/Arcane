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

class _CustomAssistantPickerScreenState extends State<CustomAssistantPickerScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final customPkg = appProvider.settings.bluetoothAssistantCustomPackage.trim();
    final customAct = appProvider.settings.bluetoothAssistantCustomActivity.trim();

    setState(() => _isLoadingApps = true);
    final apps = await AssistantRoutingService.instance.getAllInstalledApps();

    if (!mounted) return;
    setState(() {
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
        const SizedBox(height: 12),

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
}
