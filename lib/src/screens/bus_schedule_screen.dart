import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/settings/homescreen_widgets_preview_screen.dart';
import 'package:missions/src/screens/settings/bus_network_editor_screen.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/bus/bus_next_card.dart';
import 'package:missions/src/widgets/bus/bus_schedule_grid.dart';

class BusScheduleScreen extends StatefulWidget {
  const BusScheduleScreen({super.key});

  @override
  State<BusScheduleScreen> createState() => _BusScheduleScreenState();
}

class _BusScheduleScreenState extends State<BusScheduleScreen> {
  late String _origin;
  late String _destination;
  late Timer _clockTimer;
  bool _isEditMode = false;
  bool _isLoading = true;
  bool _autoGpsEnabled = true;
  String _filterMode = "ALL"; // "ALL" or "UPCOMING"

  List<BusStop> _allStops = List.from(DefaultBusNetwork.stops);
  List<BusRoute> _allRoutes = DefaultBusNetwork.getRoutes();
  StreamSubscription<BusTransitLiveState>? _liveSub;
  BusTransitLiveState _liveState = const BusTransitLiveState();

  @override
  void initState() {
    super.initState();
    _origin = _allStops.first.name;
    _destination = _allStops[1].name;
    _loadSchedules();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateTime());

    _initGps();
  }

  void _initGps() {
    final locService = BusLocationService.instance;
    _liveSub?.cancel();
    _liveSub = locService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _liveState = state);
      }
    });

    locService.startTracking(
      stops: _allStops,
      activeRoute: _getActiveRoute(),
    );

    if (_autoGpsEnabled) {
      _autoLocateOrigin(silent: true);
    }
  }

  Future<void> _autoLocateOrigin({bool silent = false}) async {
    final pos = await BusLocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      final nearest = BusLocationService.instance.resolveAutoOrigin(_allStops, pos);
      if (nearest != null) {
        setState(() {
          _origin = nearest.name;
          final bestDest = BusLocationService.instance.resolveAutoDestination(
            nearest,
            _allStops,
            _allRoutes,
          );
          if (bestDest != null && bestDest.name != _origin) {
            _destination = bestDest.name;
          }
        });
        BusLocationService.instance.updateContext(
          stops: _allStops,
          activeRoute: _getActiveRoute(),
        );
        _syncWidget();
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-detected nearest stop: ${nearest.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_liveState.locationStatusMessage ?? 'GPS position not available. You can pick stops manually.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  BusRoute? _getActiveRoute() {
    final normOrigin = _origin.toLowerCase().trim();
    final normDest = _destination.toLowerCase().trim();

    return _allRoutes.where((r) {
      final rOrig = r.name.toLowerCase();
      final rDest = r.name.toLowerCase();
      return (rOrig.contains(normOrigin) || r.originId.toLowerCase().contains(normOrigin)) &&
          (rDest.contains(normDest) || r.destinationId.toLowerCase().contains(normDest));
    }).firstOrNull ??
        _allRoutes.where((r) => r.originId == _origin && r.destinationId == _destination).firstOrNull ??
        _buildFallbackDerivedRoute(_origin, _destination);
  }

  BusRoute _buildFallbackDerivedRoute(String origin, String dest) {
    final origStop = _allStops.where((s) => s.name.toUpperCase() == origin.toUpperCase()).firstOrNull;
    final destStop = _allStops.where((s) => s.name.toUpperCase() == dest.toUpperCase()).firstOrNull;

    double distKm = 12.0;
    if (origStop != null && destStop != null) {
      distKm = double.parse(origStop.distanceTo(destStop.latitude, destStop.longitude).toStringAsFixed(1));
    }
    final durationMins = (distKm / 28.0 * 60).round().clamp(10, 120);

    final List<BusSubStop> subStops = [
      BusSubStop(
        name: origin,
        latitude: origStop?.latitude ?? 11.23,
        longitude: origStop?.longitude ?? 76.0,
        distanceFromOriginKm: 0.0,
        timeOffsetMinutes: 0,
      ),
      BusSubStop(
        name: '$origin Sub-Stop 1',
        latitude: (origStop?.latitude ?? 11.23) * 0.7 + (destStop?.latitude ?? 11.21) * 0.3,
        longitude: (origStop?.longitude ?? 76.0) * 0.7 + (destStop?.longitude ?? 75.96) * 0.3,
        distanceFromOriginKm: double.parse((distKm * 0.35).toStringAsFixed(1)),
        timeOffsetMinutes: (durationMins * 0.35).round(),
      ),
      BusSubStop(
        name: '$origin Sub-Stop 2',
        latitude: (origStop?.latitude ?? 11.23) * 0.3 + (destStop?.latitude ?? 11.21) * 0.7,
        longitude: (origStop?.longitude ?? 76.0) * 0.3 + (destStop?.longitude ?? 75.96) * 0.7,
        distanceFromOriginKm: double.parse((distKm * 0.70).toStringAsFixed(1)),
        timeOffsetMinutes: (durationMins * 0.70).round(),
      ),
      BusSubStop(
        name: dest,
        latitude: destStop?.latitude ?? 11.2185,
        longitude: destStop?.longitude ?? 75.9628,
        distanceFromOriginKm: distKm,
        timeOffsetMinutes: durationMins,
      ),
    ];

    final departures = _getDeparturesForRoute(origin, dest);

    return BusRoute(
      id: '${origin}_to_$dest',
      originId: origin,
      destinationId: dest,
      name: '$origin → $dest',
      distanceKm: distKm,
      baseDurationMinutes: durationMins,
      subStops: subStops,
      departures: departures,
    );
  }

  List<String> _getDeparturesForRoute(String origin, String dest) {
    final normOrigin = origin.toLowerCase().trim();
    final normDest = dest.toLowerCase().trim();

    for (final r in _allRoutes) {
      if (r.name.toLowerCase().contains(normOrigin) && r.name.toLowerCase().contains(normDest)) {
        if (r.departures.isNotEmpty) return r.departures;
      }
    }

    return const [
      "06:30 AM", "07:15 AM", "08:00 AM", "08:35 AM", "09:15 AM", "10:00 AM",
      "10:45 AM", "11:30 AM", "12:15 PM", "01:00 PM", "01:45 PM", "02:30 PM",
      "03:15 PM", "04:00 PM", "04:45 PM", "05:30 PM", "06:15 PM", "07:00 PM",
      "07:45 PM", "08:30 PM"
    ];
  }

  Future<void> _loadSchedules() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final settings = provider.settings;

      // 1. Load Custom Stops or Defaults
      if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
        _allStops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
      } else {
        _allStops = List.from(DefaultBusNetwork.stops);
      }

      // 2. Load Custom Routes or Defaults
      if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
        _allRoutes = settings.customBusRoutesJson!.map((e) => BusRoute.fromJson(e)).toList();
      } else {
        _allRoutes = DefaultBusNetwork.getRoutes();
      }

      // 3. Merge custom timetable departures if defined
      if (settings.customBusSchedules != null) {
        for (int i = 0; i < _allRoutes.length; i++) {
          final r = _allRoutes[i];
          final origName = _allStops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
          final dstName = _allStops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
          if (settings.customBusSchedules![origName] != null &&
              settings.customBusSchedules![origName]![dstName] != null) {
            _allRoutes[i] = r.copyWith(departures: settings.customBusSchedules![origName]![dstName]!);
          }
        }
      }

      // Verify origin and destination exist in stops list
      if (!_allStops.any((s) => s.name == _origin) && _allStops.isNotEmpty) {
        _origin = _allStops.first.name;
      }
      if (!_allStops.any((s) => s.name == _destination) && _allStops.length > 1) {
        _destination = _allStops[1].name;
      }

      BusLocationService.instance.updateContext(
        stops: _allStops,
        activeRoute: _getActiveRoute(),
      );
    } catch (e) {
      debugPrint("Error loading schedules: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedules() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final newSettings = AppSettings.fromJson(provider.settings.toJson());

      newSettings.customBusStopsJson = _allStops.map((s) => s.toJson()).toList();
      newSettings.customBusRoutesJson = _allRoutes.map((r) => r.toJson()).toList();

      final Map<String, Map<String, List<String>>> customMap = {};
      for (final r in _allRoutes) {
        final origName = _allStops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final dstName = _allStops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        if (!customMap.containsKey(origName)) {
          customMap[origName] = {};
        }
        customMap[origName]![dstName] = r.departures;
      }
      newSettings.customBusSchedules = customMap;
      provider.setSettings(newSettings);

      _syncWidget();
      setState(() {});
    } catch (e) {
      debugPrint("Error saving schedules: $e");
    }
  }

  void _syncWidget() {
    final nextBus = _findNextBus();
    HomeWidgetService.instance.publishBus(
      origin: _origin,
      destination: _destination,
      nextTime: nextBus?['time'] ?? '08:15 AM',
      nextSubStop: _liveState.nextSubStop?.name ?? '',
      isOnBus: _liveState.isOnBus,
      speedKmh: _liveState.speedKmh.round(),
      minutesRemaining: _liveState.predictedMinutesToDestination ?? nextBus?['minutes'] ?? -1,
    );
  }

  void _updateTime() {
    if (mounted) {
      setState(() {});
      _syncWidget();
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  int _timeToMinutes(String timeStr) {
    try {
      final now = DateTime.now();
      final parsed = DateFormat("hh:mm a").parse(timeStr);
      final combined = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      return combined.hour * 60 + combined.minute;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic>? _findNextBus() {
    final activeRoute = _getActiveRoute();
    final departures = activeRoute?.departures ?? _getDeparturesForRoute(_origin, _destination);
    if (departures.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    String? nextBusTime;
    int smallestDiff = 99999;
    bool isTomorrow = false;

    for (String time in departures) {
      int busMin = _timeToMinutes(time);
      int diff = busMin - currentMinutes;

      if (diff >= 0 && diff < smallestDiff) {
        smallestDiff = diff;
        nextBusTime = time;
      }
    }

    if (nextBusTime == null && departures.isNotEmpty) {
      nextBusTime = departures.first;
      isTomorrow = true;
      int busMin = _timeToMinutes(nextBusTime);
      smallestDiff = (busMin + 24 * 60) - currentMinutes;
    }

    if (nextBusTime != null) {
      return {
        "time": nextBusTime,
        "minutes": smallestDiff,
        "tomorrow": isTomorrow,
      };
    }
    return null;
  }

  void _swapLocations() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
    BusLocationService.instance.updateContext(
      stops: _allStops,
      activeRoute: _getActiveRoute(),
    );
    _syncWidget();
  }

  void _startManualCommute(DateTime start, DateTime finish) {
    final activeRoute = _getActiveRoute();
    if (activeRoute != null) {
      BusLocationService.instance.startManualCommute(
        route: activeRoute,
        startTime: start,
        expectedFinishTime: finish,
      );
      _syncWidget();
    }
  }

  void _stopManualCommute() {
    BusLocationService.instance.stopManualCommute();
    _syncWidget();
  }

  Future<void> _addOrEditTime([String? oldTime]) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (oldTime != null) {
      try {
        final parsed = DateFormat("hh:mm a").parse(oldTime);
        initialTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } catch (_) {}
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: JweTheme.pickerScheme(
            accent: JweTheme.accentAmber,
            surface: JweTheme.panel,
          ),
        ),
        child: child!,
      ),
    );

    if (time != null && mounted) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      final timeStr = DateFormat("hh:mm a").format(dt);

      final route = _getActiveRoute();
      if (route != null) {
        final currentDeps = List<String>.from(route.departures);
        if (oldTime != null) currentDeps.remove(oldTime);
        if (!currentDeps.contains(timeStr)) {
          currentDeps.add(timeStr);
          currentDeps.sort((a, b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));
        }

        final idx = _allRoutes.indexWhere((r) => r.id == route.id);
        if (idx >= 0) {
          _allRoutes[idx] = BusRoute(
            id: route.id,
            originId: route.originId,
            destinationId: route.destinationId,
            name: route.name,
            distanceKm: route.distanceKm,
            baseDurationMinutes: route.baseDurationMinutes,
            subStops: route.subStops,
            departures: currentDeps,
          );
        }
        await _saveSchedules();
      }
    }
  }

  void _removeTime(String time) {
    final route = _getActiveRoute();
    if (route != null) {
      final currentDeps = List<String>.from(route.departures);
      currentDeps.remove(time);

      final idx = _allRoutes.indexWhere((r) => r.id == route.id);
      if (idx >= 0) {
        _allRoutes[idx] = BusRoute(
          id: route.id,
          originId: route.originId,
          destinationId: route.destinationId,
          name: route.name,
          distanceKm: route.distanceKm,
          baseDurationMinutes: route.baseDurationMinutes,
          subStops: route.subStops,
          departures: currentDeps,
        );
      }
      _saveSchedules();
    }
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: JweTheme.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BUS RADAR SETTINGS',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: JweTheme.textWhite,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: JweTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-detect starting point with GPS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Automatically sets nearest bus stop on launch',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
                ),
                value: _autoGpsEnabled,
                activeTrackColor: JweTheme.accentAmber,
                onChanged: (val) {
                  setModalState(() => _autoGpsEnabled = val);
                  setState(() => _autoGpsEnabled = val);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.busStopCovered, color: JweTheme.accentCyan),
                title: Text(
                  'Edit Transit Network & Sub-Stops',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentCyan,
                  ),
                ),
                subtitle: Text(
                  'Manage routes, intermediate sub-stops, distances & timetables',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusNetworkEditorScreen(),
                    ),
                  );
                  _loadSchedules();
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.widgetsOutline, color: JweTheme.accentTeal),
                title: Text(
                  'Preview Android Homescreen Widget',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentTeal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomescreenWidgetsPreviewScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.crosshairsGps, color: JweTheme.accentCyan),
                title: Text(
                  'Refresh GPS Location Now',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.textWhite,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _autoLocateOrigin();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.mapMarkerPlus, color: JweTheme.accentAmber),
                title: Text(
                  'Add Custom Stop',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.textWhite,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddStopDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStopDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          'ADD TRANSIT STOP',
          style: GoogleFonts.rajdhani(
            color: JweTheme.textWhite,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Stop Name (e.g. Kozhikode Stand)',
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: '3-Letter Code (e.g. CLT)',
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: JweTheme.onAccent,
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final code = codeCtrl.text.trim().toUpperCase();
                final newStop = BusStop(
                  id: name.toLowerCase().replaceAll(' ', '_'),
                  name: name.toUpperCase(),
                  shortCode: code.isNotEmpty ? code : name.substring(0, 3).toUpperCase(),
                  latitude: 11.23,
                  longitude: 76.0,
                );
                setState(() {
                  _allStops.add(newStop);
                  _origin = newStop.name;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('ADD STOP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute = _getActiveRoute();
    final nextBus = _findNextBus();
    final allDepartures = activeRoute?.departures ?? _getDeparturesForRoute(_origin, _destination);

    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final filteredDepartures = _filterMode == "UPCOMING"
        ? allDepartures.where((t) => _timeToMinutes(t) >= nowMin).toList()
        : allDepartures;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: JweTheme.bgBase,
      ),
      child: Scaffold(
        backgroundColor: JweTheme.bgBase,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.busClock, color: JweTheme.accentAmber, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  "BUS RADAR",
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: JweTheme.bgBase,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(MdiIcons.busStopCovered, color: JweTheme.accentAmber, size: 20),
              tooltip: "Edit Routes & Sub-Stops",
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusNetworkEditorScreen(),
                  ),
                );
                _loadSchedules();
                setState(() {});
              },
            ),
            IconButton(
              icon: Icon(Icons.my_location, color: JweTheme.accentCyan, size: 20),
              tooltip: "Auto-detect Nearest Stop",
              onPressed: () => _autoLocateOrigin(),
            ),
            IconButton(
              icon: Icon(MdiIcons.cogOutline, color: JweTheme.textMid, size: 20),
              tooltip: "Settings",
              onPressed: _openSettingsDialog,
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: JweTheme.accentAmber))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Origin & Destination Selector Hub
                      _buildSelectorHub(),

                      const SizedBox(height: 14),

                      // Next Bus Card with Live HUD Telemetry & Manual Commute
                      BusNextCard(
                        nextBusData: nextBus,
                        routeInfo: "$_origin → $_destination",
                        activeRoute: activeRoute,
                        liveState: _liveState,
                        onSwap: _swapLocations,
                        onLocate: () => _autoLocateOrigin(),
                        onStartManualCommute: _startManualCommute,
                        onStopManualCommute: _stopManualCommute,
                      ),

                      const SizedBox(height: 18),

                      // Filter & Edit Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                "TIMETABLE",
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textWhite,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${filteredDepartures.length} RUNS',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                    color: JweTheme.accentAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Upcoming vs All Filter Chip
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _filterMode = _filterMode == "ALL" ? "UPCOMING" : "ALL";
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _filterMode == "UPCOMING"
                                        ? JweTheme.accentCyan.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _filterMode == "UPCOMING"
                                          ? JweTheme.accentCyan
                                          : JweTheme.border,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _filterMode == "UPCOMING" ? 'UPCOMING' : 'ALL',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                      color: _filterMode == "UPCOMING"
                                          ? JweTheme.accentCyan
                                          : JweTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (_isEditMode)
                                IconButton(
                                  icon: Icon(MdiIcons.plusBoxOutline, color: JweTheme.accentAmber, size: 20),
                                  onPressed: () => _addOrEditTime(null),
                                ),
                              IconButton(
                                icon: Icon(
                                  _isEditMode ? MdiIcons.check : MdiIcons.pencilOutline,
                                  color: _isEditMode ? JweTheme.accentCyan : JweTheme.textMuted,
                                  size: 19,
                                ),
                                onPressed: () => setState(() => _isEditMode = !_isEditMode),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Departure Times Grid
                      if (filteredDepartures.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: JweTheme.panel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: JweTheme.border),
                          ),
                          child: Text(
                            "NO UPCOMING RUNS REMAINING TODAY.",
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        BusScheduleGrid(
                          scheduleList: filteredDepartures,
                          nextBusTime: nextBus?['time'],
                          isEditMode: _isEditMode,
                          onRemove: _removeTime,
                          onEdit: _addOrEditTime,
                          timeToMinutes: _timeToMinutes,
                        ),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSelectorHub() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStopHorizontalList(
            label: "ORIGIN STATION (DEPARTURE)",
            selectedValue: _origin,
            activeColor: JweTheme.accentAmber,
            onSelect: (val) {
              setState(() => _origin = val);
              BusLocationService.instance.updateContext(
                stops: _allStops,
                activeRoute: _getActiveRoute(),
              );
              _syncWidget();
            },
          ),
          const SizedBox(height: 10),
          _buildStopHorizontalList(
            label: "DESTINATION STATION (ARRIVAL)",
            selectedValue: _destination,
            activeColor: JweTheme.accentCyan,
            onSelect: (val) {
              setState(() => _destination = val);
              BusLocationService.instance.updateContext(
                stops: _allStops,
                activeRoute: _getActiveRoute(),
              );
              _syncWidget();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStopHorizontalList({
    required String label,
    required String selectedValue,
    required Color activeColor,
    required Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9.0,
            letterSpacing: 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _allStops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final stop = _allStops[index];
              final isSelected = stop.name.toUpperCase() == selectedValue.toUpperCase();

              return GestureDetector(
                onTap: () => onSelect(stop.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? activeColor : JweTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stop.shortCode,
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? activeColor : JweTheme.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stop.name.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? JweTheme.textWhite : JweTheme.textMid,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}