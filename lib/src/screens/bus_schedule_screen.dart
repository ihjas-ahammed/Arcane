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
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/bus/bus_departure_action_sheet.dart';
import 'package:missions/src/widgets/bus/bus_location_dialogs.dart';
import 'package:missions/src/widgets/bus/bus_next_card.dart';
import 'package:missions/src/widgets/bus/bus_raw_transmission_dialog.dart';
import 'package:missions/src/widgets/bus/bus_route_timeline.dart';
import 'package:missions/src/widgets/bus/bus_schedule_grid.dart';
import 'package:missions/src/widgets/bus/bus_speed_distance_dialogs.dart';
import 'package:missions/src/widgets/bus/bus_schedule_operations.dart';
import 'package:missions/src/widgets/bus/bus_stop_selector_hub.dart';
import 'package:missions/src/widgets/bus/bus_timetable_header.dart';
import 'package:missions/src/widgets/bus/in_the_bus_card.dart';
import 'package:missions/src/widgets/bus/transit_settings_sheet.dart';

export 'package:missions/src/widgets/bus/bus_departure_action_sheet.dart';
export 'package:missions/src/widgets/bus/bus_location_dialogs.dart';
export 'package:missions/src/widgets/bus/bus_next_card.dart';
export 'package:missions/src/widgets/bus/bus_raw_transmission_dialog.dart';
export 'package:missions/src/widgets/bus/bus_route_timeline.dart';
export 'package:missions/src/widgets/bus/bus_schedule_grid.dart';
export 'package:missions/src/widgets/bus/bus_speed_distance_dialogs.dart';
export 'package:missions/src/widgets/bus/bus_stop_selector_hub.dart';
export 'package:missions/src/widgets/bus/bus_timetable_header.dart';
export 'package:missions/src/widgets/bus/in_the_bus_card.dart';
export 'package:missions/src/widgets/bus/transit_settings_sheet.dart';

class BusScheduleScreen extends StatefulWidget {
  const BusScheduleScreen({super.key});

  @override
  State<BusScheduleScreen> createState() => _BusScheduleScreenState();
}

class _BusScheduleScreenState extends State<BusScheduleScreen> {
  late String _origin;
  late String _destination;
  late Timer _clockTimer;
  StreamSubscription<BusTransitLiveState>? _transitSub;
  String? _selectedTime;
  bool _isEditMode = false;
  bool _isLoading = true;
  String _filterMode = "ALL"; // "ALL" or "UPCOMING"

  List<BusStop> _allStops = List.from(DefaultBusNetwork.stops);
  List<BusRoute> _allRoutes = DefaultBusNetwork.getRoutes();

  @override
  void initState() {
    super.initState();
    _origin = _allStops.first.name;
    _destination = _allStops.length > 1 ? _allStops[1].name : _allStops.first.name;
    _loadSchedules();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateTime());
    _transitSub = BusLocationService.instance.stateStream.listen((state) {
      if (mounted) setState(() {});
    });
  }

  bool _matchesRoute(BusRoute r, String origin, String dest) =>
      BusScheduleOperations.matchesRoute(r, origin, dest, _allStops);

  BusRoute? _getActiveRoute() {
    return _allRoutes.where((r) => _matchesRoute(r, _origin, _destination)).firstOrNull ??
        _buildFallbackDerivedRoute(_origin, _destination);
  }

  BusRoute _buildFallbackDerivedRoute(String origin, String dest) =>
      BusScheduleOperations.buildFallbackDerivedRoute(
        origin: origin,
        dest: dest,
        allStops: _allStops,
        allRoutes: _allRoutes,
      );

  List<String> _getDeparturesForRoute(String origin, String dest) =>
      BusScheduleOperations.getDeparturesForRoute(
        origin: origin,
        dest: dest,
        allRoutes: _allRoutes,
        allStops: _allStops,
      );

  Future<void> _loadSchedules() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final settings = provider.settings;

      if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
        _allStops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
      } else {
        _allStops = List.from(DefaultBusNetwork.stops);
      }

      if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
        _allRoutes = settings.customBusRoutesJson!.map((e) {
          final r = BusRoute.fromJson(e);
          return r.copyWith(subStops: const []);
        }).toList();
      } else {
        _allRoutes = DefaultBusNetwork.getRoutes();
      }

      final Map<String, Map<String, List<String>>> scheduleMap = {};
      if (settings.customBusSchedules != null && settings.customBusSchedules!.isNotEmpty) {
        settings.customBusSchedules!.forEach((k, v) {
          final formattedK = DefaultBusNetwork.formatPlaceName(k);
          scheduleMap[formattedK] = {};
          v.forEach((k2, v2) {
            scheduleMap[formattedK]![DefaultBusNetwork.formatPlaceName(k2)] = List<String>.from(v2);
          });
        });
      } else {
        final defaultMap = DefaultBusNetwork.getDefaultScheduleMap();
        defaultMap.forEach((k, v) {
          scheduleMap[k] = Map<String, List<String>>.from(v);
        });
      }

      DefaultBusNetwork.calculateAndFillDerivedSchedules(scheduleMap);

      for (int i = 0; i < _allRoutes.length; i++) {
        final r = _allRoutes[i];
        final origName = _allStops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final dstName = _allStops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        if (scheduleMap[origName] != null && scheduleMap[origName]![dstName] != null) {
          _allRoutes[i] = r.copyWith(departures: scheduleMap[origName]![dstName]!, subStops: const []);
        }
      }

      if (settings.lastSelectedBusOrigin != null &&
          _allStops.any((s) => s.name.toLowerCase() == settings.lastSelectedBusOrigin!.toLowerCase())) {
        _origin = _allStops.firstWhere((s) => s.name.toLowerCase() == settings.lastSelectedBusOrigin!.toLowerCase()).name;
      } else if (_allStops.isNotEmpty) {
        _origin = _allStops.first.name;
      }

      if (settings.lastSelectedBusDestination != null &&
          _allStops.any((s) => s.name.toLowerCase() == settings.lastSelectedBusDestination!.toLowerCase())) {
        _destination = _allStops.firstWhere((s) => s.name.toLowerCase() == settings.lastSelectedBusDestination!.toLowerCase()).name;
      } else if (_allStops.length > 1) {
        _destination = _allStops[1].name;
      }

      if (settings.customBusSchedules == null || settings.customBusSchedules!.isEmpty) {
        final newSettings = AppSettings.fromJson(settings.toJson());
        newSettings.customBusSchedules = scheduleMap;
        newSettings.customBusStopsJson = _allStops.map((s) => s.toJson()).toList();
        newSettings.customBusRoutesJson = _allRoutes.map((r) => r.toJson()).toList();
        newSettings.lastSelectedBusOrigin = _origin;
        newSettings.lastSelectedBusDestination = _destination;
        provider.setSettings(newSettings);
      }

      _syncWidget();
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

      final Map<String, Map<String, List<String>>> customMap = {};
      for (final r in _allRoutes) {
        final origName = _allStops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final dstName = _allStops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        final formOrig = DefaultBusNetwork.formatPlaceName(origName);
        final formDst = DefaultBusNetwork.formatPlaceName(dstName);
        if (!customMap.containsKey(formOrig)) {
          customMap[formOrig] = {};
        }
        customMap[formOrig]![formDst] = List<String>.from(r.departures);
      }

      newSettings.customBusStopsJson = _allStops.map((s) => s.toJson()).toList();
      newSettings.customBusRoutesJson = _allRoutes.map((r) => r.toJson()).toList();
      newSettings.customBusSchedules = customMap;
      newSettings.lastSelectedBusOrigin = _origin;
      newSettings.lastSelectedBusDestination = _destination;

      provider.setSettings(newSettings);

      _syncWidget();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error saving schedules: $e");
    }
  }

  void _persistFocus() {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final newSettings = AppSettings.fromJson(provider.settings.toJson());
      newSettings.lastSelectedBusOrigin = _origin;
      newSettings.lastSelectedBusDestination = _destination;
      provider.setSettings(newSettings);
    } catch (_) {}
  }

  void _syncWidget() {
    final liveState = BusLocationService.instance.currentState;
    if (liveState.isOnBus) return;

    final nextBus = _findNextBus();
    HomeWidgetService.instance.publishBus(
      origin: DefaultBusNetwork.formatPlaceName(_origin),
      destination: DefaultBusNetwork.formatPlaceName(_destination),
      nextTime: nextBus?['time'] ?? '08:15 AM',
      nextSubStop: '',
      isOnBus: false,
      speedKmh: 0,
      minutesRemaining: nextBus?['minutes'] ?? -1,
      progressPct: 0,
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
    _transitSub?.cancel();
    super.dispose();
  }

  int _timeToMinutes(String timeStr) => BusScheduleOperations.timeToMinutes(timeStr);

  Map<String, dynamic>? _findNextBus() => BusScheduleOperations.findNextBus(
        activeRoute: _getActiveRoute(),
        origin: _origin,
        dest: _destination,
        allRoutes: _allRoutes,
        allStops: _allStops,
      );

  void _swapLocations() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
    _persistFocus();
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

        final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
        if (idx >= 0) {
          _allRoutes[idx] = route.copyWith(departures: currentDeps, subStops: const []);
        } else {
          _allRoutes.add(
            BusRoute(
              id: 'route_${_origin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_to_${_destination.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              originId: _origin,
              destinationId: _destination,
              name: '$_origin → $_destination',
              distanceKm: route.distanceKm,
              baseDurationMinutes: route.baseDurationMinutes,
              subStops: const [],
              departures: currentDeps,
            ),
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

      final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
      if (idx >= 0) {
        _allRoutes[idx] = route.copyWith(departures: currentDeps, subStops: const []);
      }
      _saveSchedules();
    }
  }

  Future<void> _startInTheBus(String time) async {
    final route = _getActiveRoute();
    double distanceKm = (route?.distanceKm != null && route!.distanceKm > 0) ? route.distanceKm : 0.0;
    final speedKmh = (route?.speedKmh != null && route!.speedKmh > 0)
        ? route.speedKmh
        : DefaultBusNetwork.defaultSpeedKmh;

    if (distanceKm <= 0.0) {
      final asked = await showAskDistanceDialog(
        context,
        origin: _origin,
        destination: _destination,
      );
      if (asked == null || asked <= 0) return;
      distanceKm = asked;
      if (route != null) {
        final updated = route.copyWith(distanceKm: distanceKm);
        final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
        if (idx >= 0) {
          _allRoutes[idx] = updated;
        } else {
          _allRoutes.add(updated);
        }
        await _saveSchedules();
      }
    }

    final now = DateTime.now();
    final depMin = _timeToMinutes(time);
    final nowMin = now.hour * 60 + now.minute;
    final totalDurationMins = (distanceKm / speedKmh * 60).round();

    DateTime startTime;
    if (nowMin >= depMin && (nowMin - depMin) < totalDurationMins) {
      startTime = DateTime(now.year, now.month, now.day, depMin ~/ 60, depMin % 60);
    } else {
      startTime = now;
    }

    final activeRoute = route ?? _buildFallbackDerivedRoute(_origin, _destination);
    BusLocationService.instance.startManualCommute(
      route: activeRoute,
      startTime: startTime,
      assumedSpeedKmh: speedKmh,
      originName: DefaultBusNetwork.formatPlaceName(_origin),
      destinationName: DefaultBusNetwork.formatPlaceName(_destination),
      customDistanceKm: distanceKm,
      departureTime: time,
    );

    if (mounted) {
      setState(() {
        _selectedTime = time;
      });
      showGlobalToast('In the bus! Traveling to ${DefaultBusNetwork.formatPlaceName(_destination)} @ ${speedKmh.toStringAsFixed(0)} km/h');
    }
  }

  void _handleTimeSelected(String time) {
    setState(() => _selectedTime = time);
    final route = _getActiveRoute();

    showBusDepartureActionSheet(
      context,
      time: time,
      origin: _origin,
      destination: _destination,
      route: route,
      onInTheBus: () => _startInTheBus(time),
      onEndTrip: () {
        BusLocationService.instance.stopManualCommute();
        showGlobalToast('Trip completed / ended');
      },
      onEditTime: () => _addOrEditTime(time),
      onRemoveTime: () => _removeTime(time),
      onSpeedChanged: (newSpeed) async {
        if (route != null) {
          final updated = route.copyWith(speedKmh: newSpeed);
          final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
          if (idx >= 0) {
            _allRoutes[idx] = updated;
          } else {
            _allRoutes.add(updated);
          }
          await _saveSchedules();
          _handleTimeSelected(time);
        }
      },
      onDistanceChanged: (newDist) async {
        if (route != null) {
          final updated = route.copyWith(distanceKm: newDist);
          final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
          if (idx >= 0) {
            _allRoutes[idx] = updated;
          } else {
            _allRoutes.add(updated);
          }
          await _saveSchedules();
          _handleTimeSelected(time);
        }
      },
    );
  }

  Future<void> _handleAddNewPlace([String? initialName]) async {
    final result = await showAddLocationDialog(context, initialName: initialName);
    if (result != null && result["name"] != null && result["name"]!.isNotEmpty) {
      final name = DefaultBusNetwork.formatPlaceName(result["name"]!);
      final code = result["code"] ?? (name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase());

      if (!_allStops.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        final newStop = BusStop(
          id: 'stop_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}',
          name: name,
          shortCode: code,
          latitude: 11.23,
          longitude: 76.0,
        );

        setState(() {
          _allStops.add(newStop);
          _destination = newStop.name;
        });

        for (final existingStop in _allStops) {
          if (existingStop.id == newStop.id) continue;

          final hasForward = _allRoutes.any((r) =>
              (r.originId.toLowerCase() == existingStop.id.toLowerCase() || r.originId.toLowerCase() == existingStop.name.toLowerCase()) &&
              (r.destinationId.toLowerCase() == newStop.id.toLowerCase() || r.destinationId.toLowerCase() == newStop.name.toLowerCase()));
          if (!hasForward) {
            _allRoutes.add(
              BusRoute(
                id: 'route_${existingStop.id}_to_${newStop.id}',
                originId: existingStop.name,
                destinationId: newStop.name,
                name: '${existingStop.name} → ${newStop.name}',
                distanceKm: 12.0,
                baseDurationMinutes: 25,
                subStops: const [],
                departures: const [],
              ),
            );
          }

          final hasReverse = _allRoutes.any((r) =>
              (r.originId.toLowerCase() == newStop.id.toLowerCase() || r.originId.toLowerCase() == newStop.name.toLowerCase()) &&
              (r.destinationId.toLowerCase() == existingStop.id.toLowerCase() || r.destinationId.toLowerCase() == existingStop.name.toLowerCase()));
          if (!hasReverse) {
            _allRoutes.add(
              BusRoute(
                id: 'route_${newStop.id}_to_${existingStop.id}',
                originId: newStop.name,
                destinationId: existingStop.name,
                name: '${newStop.name} → ${existingStop.name}',
                distanceKm: 12.0,
                baseDurationMinutes: 25,
                subStops: const [],
                departures: const [],
              ),
            );
          }
        }

        _persistFocus();
        await _saveSchedules();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added new place: $name ($code)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleManageStop(BusStop stop) async {
    await showManageStopDialog(
      context,
      stop: stop,
      onEdit: () => _handleAddNewPlace(stop.name),
      onDelete: () async {
        setState(() {
          _allStops.removeWhere((s) => s.id == stop.id);
          _allRoutes.removeWhere((r) =>
              r.originId.toLowerCase() == stop.id.toLowerCase() ||
              r.destinationId.toLowerCase() == stop.id.toLowerCase() ||
              r.name.toLowerCase().contains(stop.name.toLowerCase()));
          if (_origin.toLowerCase() == stop.name.toLowerCase() && _allStops.isNotEmpty) {
            _origin = _allStops.first.name;
          }
          if (_destination.toLowerCase() == stop.name.toLowerCase() && _allStops.length > 1) {
            _destination = _allStops[1].name;
          }
        });
        _persistFocus();
        _saveSchedules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed place: ${stop.name}')),
          );
        }
      },
    );
  }

  Future<void> _handleResetDefaults() async {
    final confirmed = await showResetTimetablesDialog(context);
    if (confirmed == true && mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final newSettings = AppSettings.fromJson(provider.settings.toJson());

      _allStops = List.from(DefaultBusNetwork.stops);
      _allRoutes = DefaultBusNetwork.getRoutes();

      final defaultMap = DefaultBusNetwork.getDefaultScheduleMap();
      newSettings.customBusSchedules = defaultMap;
      newSettings.customBusStopsJson = _allStops.map((s) => s.toJson()).toList();
      newSettings.customBusRoutesJson = _allRoutes.map((r) => r.toJson()).toList();

      _origin = _allStops.first.name;
      _destination = _allStops.length > 1 ? _allStops[1].name : _allStops.first.name;
      newSettings.lastSelectedBusOrigin = _origin;
      newSettings.lastSelectedBusDestination = _destination;

      provider.setSettings(newSettings);

      _syncWidget();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pristine default bus schedules restored and fed to DB.")),
      );
    }
  }

  void _openTransitSettings() {
    showTransitSettingsSheet(
      context,
      onAddPlace: () => _handleAddNewPlace(),
      onRawTransmission: _openRawTransmission,
      onEditNetwork: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusNetworkEditorScreen()),
        );
        _loadSchedules();
        setState(() {});
      },
      onPreviewWidgets: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomescreenWidgetsPreviewScreen()),
        );
      },
      onResetDefaults: _handleResetDefaults,
    );
  }

  void _openRawTransmission() {
    final activeRoute = _getActiveRoute();
    final departures = List<String>.from(activeRoute?.departures ?? _getDeparturesForRoute(_origin, _destination));

    showRawTransmissionDialog(
      context,
      origin: _origin,
      destination: _destination,
      departures: departures,
      timeToMinutes: _timeToMinutes,
      onSave: (distinctList) async {
        final route = _getActiveRoute();
        if (route != null) {
          final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
          if (idx >= 0) {
            _allRoutes[idx] = route.copyWith(departures: distinctList, subStops: const []);
          } else {
            _allRoutes.add(
              BusRoute(
                id: 'route_${_origin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_to_${_destination.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
                originId: _origin,
                destinationId: _destination,
                name: '$_origin → $_destination',
                distanceKm: route.distanceKm,
                baseDurationMinutes: route.baseDurationMinutes,
                subStops: const [],
                departures: distinctList,
              ),
            );
          }
          await _saveSchedules();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextBus = _findNextBus();
    final activeRoute = _getActiveRoute();
    final liveState = BusLocationService.instance.currentState;
    final allDepartures = activeRoute?.departures ?? _getDeparturesForRoute(_origin, _destination);

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final filteredDepartures = _filterMode == "UPCOMING"
        ? allDepartures.where((t) => _timeToMinutes(t) >= currentMinutes).toList()
        : allDepartures;

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: JweTheme.accentAmber))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // ── Tactical Header Bar ─────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back, color: JweTheme.textWhite, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "ARCANE TRANSIT RADAR",
                                        style: GoogleFonts.rajdhani(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: JweTheme.accentAmber,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        "LIVE BUS TELEMETRY & DISPATCH",
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 8.0,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: JweTheme.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(MdiIcons.mapMarkerPlus, color: JweTheme.accentAmber, size: 18),
                                tooltip: "Add Place",
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => _handleAddNewPlace(),
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.codeBrackets, color: JweTheme.accentAmber, size: 18),
                                tooltip: "Raw Transmission Edit",
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _openRawTransmission,
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.swapVertical, color: JweTheme.accentCyan, size: 18),
                                tooltip: "Swap Direction",
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _swapLocations,
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.cogOutline, color: JweTheme.textMid, size: 18),
                                tooltip: "Transit Config",
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _openTransitSettings,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── In Transit Live HUD Card ────────────────────────
                      if (liveState.isOnBus) ...[
                        InTheBusCard(
                          liveState: liveState,
                          origin: _origin,
                          destination: _destination,
                          onEndTrip: () {
                            BusLocationService.instance.stopManualCommute();
                            showGlobalToast('Trip completed / ended');
                          },
                          onChangeSpeed: () async {
                            final route = _getActiveRoute();
                            final curSpeed = (route?.speedKmh != null && route!.speedKmh > 0)
                                ? route.speedKmh
                                : DefaultBusNetwork.defaultSpeedKmh;
                            final newSpeed = await showAskSpeedDialog(
                              context,
                              origin: _origin,
                              destination: _destination,
                              currentSpeed: curSpeed,
                            );
                            if (newSpeed != null && newSpeed > 0 && route != null) {
                              final updated = route.copyWith(speedKmh: newSpeed);
                              final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
                              if (idx >= 0) {
                                _allRoutes[idx] = updated;
                              } else {
                                _allRoutes.add(updated);
                              }
                              await _saveSchedules();
                            }
                          },
                          onChangeDistance: () async {
                            final route = _getActiveRoute();
                            final curDist = (route?.distanceKm != null && route!.distanceKm > 0)
                                ? route.distanceKm
                                : 0.0;
                            final newDist = await showAskDistanceDialog(
                              context,
                              origin: _origin,
                              destination: _destination,
                              currentDistance: curDist > 0 ? curDist : null,
                            );
                            if (newDist != null && newDist > 0 && route != null) {
                              final updated = route.copyWith(distanceKm: newDist);
                              final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
                              if (idx >= 0) {
                                _allRoutes[idx] = updated;
                              } else {
                                _allRoutes.add(updated);
                              }
                              await _saveSchedules();
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Interactive Stop Selector ───────────────────────
                      BusStopSelectorHub(
                        allStops: _allStops,
                        origin: _origin,
                        destination: _destination,
                        onSelectOrigin: (val) {
                          setState(() => _origin = val);
                          _persistFocus();
                          _syncWidget();
                        },
                        onSelectDestination: (val) {
                          setState(() => _destination = val);
                          _persistFocus();
                          _syncWidget();
                        },
                        onAddPlace: () => _handleAddNewPlace(),
                        onManageStop: _handleManageStop,
                      ),

                      const SizedBox(height: 14),

                      // ── Live Next Bus Card ──────────────────────────────
                      BusNextCard(
                        nextBusData: nextBus,
                        routeInfo: '${DefaultBusNetwork.formatPlaceName(_origin)} → ${DefaultBusNetwork.formatPlaceName(_destination)}',
                        activeRoute: activeRoute,
                        onSwap: _swapLocations,
                        onInTheBus: nextBus != null ? () => _handleTimeSelected(nextBus['time']) : null,
                      ),

                      const SizedBox(height: 14),

                      // ── Clean Route Progress Bar
                      if (activeRoute != null)
                        BusRouteProgressTimeline(
                          route: activeRoute,
                          nextBusDepartureTime: nextBus?['time'],
                        ),

                      const SizedBox(height: 14),

                      // ── Departures Timetable Header ─────────────────────
                      BusTimetableHeader(
                        runsCount: allDepartures.length,
                        filterMode: _filterMode,
                        isEditMode: _isEditMode,
                        onToggleFilterMode: () {
                          setState(() {
                            _filterMode = _filterMode == "ALL" ? "UPCOMING" : "ALL";
                          });
                        },
                        onToggleEditMode: () => setState(() => _isEditMode = !_isEditMode),
                        onAddTime: () => _addOrEditTime(null),
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
                          selectedTime: _selectedTime,
                          isEditMode: _isEditMode,
                          onRemove: _removeTime,
                          onEdit: _addOrEditTime,
                          onSelectTime: _handleTimeSelected,
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
}
