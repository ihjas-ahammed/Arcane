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
import 'package:missions/src/widgets/bus/bus_next_card.dart';
import 'package:missions/src/widgets/bus/bus_route_timeline.dart';
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

  bool _matchesRoute(BusRoute r, String origin, String dest) {
    final normOrigin = origin.toLowerCase().trim();
    final normDest = dest.toLowerCase().trim();

    final rOrigName = _allStops.where((s) => s.id.toLowerCase() == r.originId.toLowerCase()).firstOrNull?.name ?? r.originId;
    final rDestName = _allStops.where((s) => s.id.toLowerCase() == r.destinationId.toLowerCase()).firstOrNull?.name ?? r.destinationId;

    if (rOrigName.toLowerCase().trim() == normOrigin && rDestName.toLowerCase().trim() == normDest) {
      return true;
    }

    if (r.name.contains('→')) {
      final parts = r.name.split('→');
      if (parts.length == 2 &&
          parts[0].trim().toLowerCase() == normOrigin &&
          parts[1].trim().toLowerCase() == normDest) {
        return true;
      }
    } else if (r.name.contains('->')) {
      final parts = r.name.split('->');
      if (parts.length == 2 &&
          parts[0].trim().toLowerCase() == normOrigin &&
          parts[1].trim().toLowerCase() == normDest) {
        return true;
      }
    }

    return false;
  }

  BusRoute? _getActiveRoute() {
    return _allRoutes.where((r) => _matchesRoute(r, _origin, _destination)).firstOrNull ??
        _buildFallbackDerivedRoute(_origin, _destination);
  }

  BusRoute _buildFallbackDerivedRoute(String origin, String dest) {
    final origStop = _allStops.where((s) => s.name.toLowerCase() == origin.toLowerCase()).firstOrNull;
    final destStop = _allStops.where((s) => s.name.toLowerCase() == dest.toLowerCase()).firstOrNull;

    double distKm = 12.0;
    if (origStop != null && destStop != null) {
      distKm = double.parse(origStop.distanceTo(destStop.latitude, destStop.longitude).toStringAsFixed(1));
    }
    final durationMins = (distKm / 28.0 * 60).round().clamp(10, 120);

    final departures = _getDeparturesForRoute(origin, dest);

    return BusRoute(
      id: 'fallback_${origin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_to_${dest.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      originId: origin,
      destinationId: dest,
      name: '${DefaultBusNetwork.formatPlaceName(origin)} → ${DefaultBusNetwork.formatPlaceName(dest)}',
      distanceKm: distKm,
      baseDurationMinutes: durationMins,
      subStops: const [],
      departures: departures,
    );
  }

  List<String> _getDeparturesForRoute(String origin, String dest) {
    final matched = _allRoutes.where((r) => _matchesRoute(r, origin, dest)).firstOrNull;
    if (matched != null && matched.departures.isNotEmpty) {
      return matched.departures;
    }

    final normOrigin = origin.toLowerCase().trim();
    final normDest = dest.toLowerCase().trim();

    final scheduleMap = DefaultBusNetwork.getDefaultScheduleMap();
    for (final k in scheduleMap.keys) {
      if (k.toLowerCase().trim() == normOrigin) {
        for (final k2 in scheduleMap[k]!.keys) {
          if (k2.toLowerCase().trim() == normDest && scheduleMap[k]![k2]!.isNotEmpty) {
            return scheduleMap[k]![k2]!;
          }
        }
      }
    }

    return const [];
  }

  Future<void> _loadSchedules() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final settings = provider.settings;

      // 1. Load Custom Stops or Defaults (Title Case normalized)
      if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
        _allStops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
      } else {
        _allStops = List.from(DefaultBusNetwork.stops);
      }

      // 2. Load Custom Routes or Defaults
      if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
        _allRoutes = settings.customBusRoutesJson!.map((e) {
          final r = BusRoute.fromJson(e);
          return r.copyWith(subStops: const []);
        }).toList();
      } else {
        _allRoutes = DefaultBusNetwork.getRoutes();
      }

      // 3. Build/merge timetable departures
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

      // Run two-way auto derivation
      DefaultBusNetwork.calculateAndFillDerivedSchedules(scheduleMap);

      // Sync scheduleMap into _allRoutes
      for (int i = 0; i < _allRoutes.length; i++) {
        final r = _allRoutes[i];
        final origName = _allStops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final dstName = _allStops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        if (scheduleMap[origName] != null && scheduleMap[origName]![dstName] != null) {
          _allRoutes[i] = r.copyWith(departures: scheduleMap[origName]![dstName]!, subStops: const []);
        }
      }

      // Restore user's focused origin/destination if saved in settings
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

      // If initial DB was empty, save defaults and focus to DB now
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

      // 1. Build scheduleMap strictly directional from _allRoutes
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
    if (liveState.isOnBus) return; // Do not overwrite active transit in widget!

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

  /// Bulk Raw Transmission Editor for editing all departures as text
  void _showRawTransmissionEditor() {
    final activeRoute = _getActiveRoute();
    final departures = List<String>.from(activeRoute?.departures ?? _getDeparturesForRoute(_origin, _destination));
    final controller = TextEditingController(text: departures.join(", "));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          "EDIT TRANSMISSION DATA",
          style: GoogleFonts.chakraPetch(
            color: JweTheme.accentAmber,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ROUTE: ${DefaultBusNetwork.formatPlaceName(_origin)} → ${DefaultBusNetwork.formatPlaceName(_destination)}",
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Paste or edit departure times separated by commas or newlines (e.g. 08:00 AM, 08:15 AM, 01:30 PM). Changes apply specifically to this route direction.",
                style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: JweTheme.bgBase,
                  border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                  hintText: "06:30 AM, 07:15 AM, 08:00 AM...",
                  hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: JweTheme.onAccent,
            ),
            onPressed: () async {
              final raw = controller.text;
              final parsedList = <String>[];

              final tokens = raw.split(RegExp(r'[, \n\r]+'));
              for (final token in tokens) {
                final cleaned = token.trim();
                if (cleaned.isEmpty) continue;
                try {
                  final dt = DateFormat("hh:mm a").parse(cleaned);
                  parsedList.add(DateFormat("hh:mm a").format(dt));
                } catch (_) {
                  try {
                    final dt = DateFormat("HH:mm").parse(cleaned);
                    parsedList.add(DateFormat("hh:mm a").format(dt));
                  } catch (_) {}
                }
              }

              if (parsedList.isNotEmpty) {
                parsedList.sort((a, b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));
                final distinctList = parsedList.toSet().toList();

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
                  Navigator.pop(ctx);
                  await _saveSchedules();
                } else {
                  Navigator.pop(ctx);
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text("SAVE & BROADCAST", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Asks the user for transit distance if not specified
  Future<double?> _askDistanceDialog([double? currentDistance]) async {
    final controller = TextEditingController(
      text: (currentDistance != null && currentDistance > 0)
          ? currentDistance.toStringAsFixed(1)
          : '',
    );

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Row(
          children: [
            Icon(MdiIcons.mapMarkerDistance, color: JweTheme.accentAmber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "ENTER ROUTE DISTANCE",
                style: GoogleFonts.chakraPetch(
                  color: JweTheme.accentAmber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Route distance between ${DefaultBusNetwork.formatPlaceName(_origin)} and ${DefaultBusNetwork.formatPlaceName(_destination)} is needed to calculate travel progress at 20 km/h speed.",
              style: GoogleFonts.rajdhani(
                color: JweTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: "DISTANCE (KM)",
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                hintText: "e.g. 10.5",
                hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5)),
                suffixText: "km",
                suffixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: JweTheme.onAccent,
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: Text("CONFIRM & BOARD", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startInTheBus(String time) async {
    final route = _getActiveRoute();
    double distanceKm = (route?.distanceKm != null && route!.distanceKm > 0) ? route.distanceKm : 0.0;

    // If distance is not given, ask user
    if (distanceKm <= 0.0) {
      final asked = await _askDistanceDialog(null);
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
    final totalDurationMins = (distanceKm / 20.0 * 60).round();

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
      assumedSpeedKmh: 20.0,
      originName: DefaultBusNetwork.formatPlaceName(_origin),
      destinationName: DefaultBusNetwork.formatPlaceName(_destination),
      customDistanceKm: distanceKm,
      departureTime: time,
    );

    if (mounted) {
      setState(() {
        _selectedTime = time;
      });
      showGlobalToast('In the bus! Traveling to ${DefaultBusNetwork.formatPlaceName(_destination)} @ 20 km/h');
    }
  }

  void _handleTimeSelected(String time) {
    setState(() => _selectedTime = time);
    final route = _getActiveRoute();
    final distKm = (route != null && route.distanceKm > 0) ? route.distanceKm : 0.0;
    final estDurationMins = distKm > 0 ? (distKm / 20.0 * 60).round() : 0;
    final liveState = BusLocationService.instance.currentState;

    showModalBottomSheet(
      context: context,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.busClock, size: 20, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text(
                        'DISPATCH: $time',
                        style: GoogleFonts.rajdhani(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: JweTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'ROUTE: ${DefaultBusNetwork.formatPlaceName(_origin)} → ${DefaultBusNetwork.formatPlaceName(_destination)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: JweTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              // Route distance and estimated transit duration
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.mapMarkerDistance, size: 15, color: JweTheme.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          distKm > 0
                              ? '${distKm.toStringAsFixed(1)} km · ~$estDurationMins min @ 20 km/h'
                              : 'Distance: Not set (20 km/h)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final newDist = await _askDistanceDialog(distKm > 0 ? distKm : null);
                        if (newDist != null && newDist > 0 && route != null) {
                          final updated = route.copyWith(distanceKm: newDist);
                          final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
                          if (idx >= 0) {
                            _allRoutes[idx] = updated;
                          } else {
                            _allRoutes.add(updated);
                          }
                          await _saveSchedules();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _handleTimeSelected(time);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          distKm > 0 ? 'CHANGE' : 'SET DISTANCE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: JweTheme.accentAmber,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Option 1: IN THE BUS (Hero Action)
              if (liveState.isOnBus) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(MdiIcons.busStop, color: JweTheme.accentRed, size: 22),
                  ),
                  title: Text(
                    'END TRANSIT TRIP',
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: JweTheme.accentRed,
                    ),
                  ),
                  subtitle: Text(
                    'Trip in progress to ${liveState.destinationName ?? _destination}. Tap to complete / end trip.',
                    style: GoogleFonts.rajdhani(fontSize: 11.5, color: JweTheme.textMuted),
                  ),
                  onTap: () {
                    BusLocationService.instance.stopManualCommute();
                    Navigator.pop(ctx);
                    showGlobalToast('Trip completed / ended');
                  },
                ),
              ] else ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startInTheBus(time);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: JweTheme.accentAmber, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: JweTheme.accentAmber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(MdiIcons.bus, color: JweTheme.onAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IN THE BUS',
                                  style: GoogleFonts.chakraPetch(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: JweTheme.accentAmber,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Board this run · Track live travel @ 20 km/h on HUD, notification & widgets',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: JweTheme.textWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 14, color: JweTheme.accentAmber),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const Divider(height: 24),

              // Option 2: Edit Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.pencilOutline, color: JweTheme.accentCyan, size: 20),
                title: Text(
                  'Edit Departure Time',
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: JweTheme.textWhite),
                ),
                subtitle: Text('Change this timetable run', style: GoogleFonts.rajdhani(fontSize: 11, color: JweTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addOrEditTime(time);
                },
              ),

              // Option 3: Remove Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.trashCanOutline, color: JweTheme.accentRed, size: 20),
                title: Text(
                  'Remove Departure Time',
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: JweTheme.accentRed),
                ),
                subtitle: Text('Delete this run from timetable', style: GoogleFonts.rajdhani(fontSize: 11, color: JweTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeTime(time);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInTheBusCard(BusTransitLiveState liveState) {
    final progress = liveState.progressAlongRoute ?? 0.0;
    final pct = (progress * 100).round();
    final remainingMins = liveState.predictedMinutesToDestination ?? 0;
    final totalKm = liveState.routeDistanceKm ?? liveState.activeRoute?.distanceKm ?? 10.0;
    final coveredKm = totalKm * progress;
    final origin = liveState.originName ?? _origin;
    final dest = liveState.destinationName ?? _destination;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.accentAmber, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JweTheme.accentAmber.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: JweTheme.accentAmber,
                      boxShadow: [
                        BoxShadow(
                          color: JweTheme.accentAmber.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '[ IN THE BUS // TRANSIT ACTIVE ]',
                    style: GoogleFonts.chakraPetch(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: JweTheme.accentAmber,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: JweTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '20 KM/H',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DefaultBusNetwork.formatPlaceName(origin)} → ${DefaultBusNetwork.formatPlaceName(dest)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: JweTheme.textWhite,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: JweTheme.bgBase,
              valueColor: AlwaysStoppedAnimation<Color>(JweTheme.accentAmber),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ETA: ~$remainingMins MIN ($pct%)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentAmber,
                ),
              ),
              Text(
                '${coveredKm.toStringAsFixed(1)} / ${totalKm.toStringAsFixed(1)} KM',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: JweTheme.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentRed,
                    side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    BusLocationService.instance.stopManualCommute();
                    showGlobalToast('Bus commute ended');
                  },
                  icon: Icon(MdiIcons.busStop, size: 16, color: JweTheme.accentRed),
                  label: Text('END TRIP', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.accentCyan,
                  side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onPressed: () async {
                  final newDist = await _askDistanceDialog(totalKm);
                  if (newDist != null && newDist > 0) {
                    final route = _getActiveRoute();
                    if (route != null) {
                      final updated = route.copyWith(distanceKm: newDist);
                      final idx = _allRoutes.indexWhere((r) => _matchesRoute(r, _origin, _destination));
                      if (idx >= 0) {
                        _allRoutes[idx] = updated;
                      }
                      await _saveSchedules();
                      BusLocationService.instance.startManualCommute(
                        route: updated,
                        startTime: liveState.commuteStartTime,
                        assumedSpeedKmh: 20.0,
                        originName: origin,
                        destinationName: dest,
                        customDistanceKm: newDist,
                        departureTime: liveState.selectedDepartureTime,
                      );
                    }
                  }
                },
                icon: Icon(MdiIcons.mapMarkerDistance, size: 16, color: JweTheme.accentCyan),
                label: Text('DISTANCE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Add new transit place / station
  Future<void> _showAddLocationDialog({String? initialName}) async {
    final nameCtrl = TextEditingController(text: initialName ?? "");
    final codeCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          "NEW TRANSIT PLACE",
          style: GoogleFonts.chakraPetch(
            color: JweTheme.accentAmber,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter the name of the place or station to add to your transit network.",
              style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: "PLACE / STATION NAME",
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                hintText: "e.g. Manjeri, Calicut, Kondotty",
                hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
              ),
              onChanged: (val) {
                if (codeCtrl.text.isEmpty || codeCtrl.text.length <= 3) {
                  final cleaned = val.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
                  if (cleaned.isNotEmpty) {
                    codeCtrl.text = cleaned.substring(0, cleaned.length.clamp(1, 3));
                  }
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                labelText: "SHORT CODE (2-4 LETTERS)",
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                hintText: "e.g. MJR, CLT, KDT",
                hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
                counterText: "",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: JweTheme.onAccent,
            ),
            onPressed: () {
              final rawName = nameCtrl.text.trim();
              if (rawName.isEmpty) return;
              final formattedName = DefaultBusNetwork.formatPlaceName(rawName);
              var code = codeCtrl.text.trim().toUpperCase();
              if (code.isEmpty) {
                final cleaned = formattedName.replaceAll(RegExp(r'[^a-zA-Z]'), '');
                code = cleaned.substring(0, cleaned.length.clamp(1, 3)).toUpperCase();
              }
              Navigator.pop(ctx, {"name": formattedName, "code": code});
            },
            child: Text("ADD PLACE", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

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

        // Ensure routes exist connecting new stop to all other stops
        for (final existingStop in _allStops) {
          if (existingStop.id == newStop.id) continue;

          // Route A -> New
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

          // Route New -> A
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

  /// Manage / Edit / Delete an existing place
  Future<void> _showManageStopDialog(BusStop stop) async {
    final isCore = ['ss_college', 'edavannappara', 'areekode'].contains(stop.id.toLowerCase());

    showModalBottomSheet(
      context: context,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MANAGE PLACE: ${stop.name}',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: JweTheme.accentAmber,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.pencilOutline, color: JweTheme.accentCyan),
                title: Text('Edit Place Details', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.textWhite)),
                subtitle: Text('Modify name and short code', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddLocationDialog(initialName: stop.name);
                },
              ),
              if (!isCore)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(MdiIcons.trashCanOutline, color: JweTheme.accentRed),
                  title: Text('Delete Place', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.accentRed)),
                  subtitle: Text('Removes ${stop.name} from transit network', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted)),
                  onTap: () async {
                    Navigator.pop(ctx);
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
                    await _saveSchedules();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed place: ${stop.name}')),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reset to pristine factory defaults
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text("RESTORE DEFAULT TIMETABLES", style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontWeight: FontWeight.bold)),
        content: Text("Reset bus schedule to pristine default timetables for S.S College, Edavannappara, and Areekode? This will overwrite custom edits.", style: GoogleFonts.rajdhani(color: JweTheme.textWhite)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("RESET & FEED DB", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

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

  void _showTransitSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSIT TELEMETRY CONFIG',
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: JweTheme.accentAmber,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.mapMarkerPlus, color: JweTheme.accentAmber),
                title: Text(
                  'Add New Place / Station',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentAmber,
                  ),
                ),
                subtitle: Text(
                  'Add custom cities, towns, colleges, or stops',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLocationDialog();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.codeBrackets, color: JweTheme.accentAmber),
                title: Text(
                  'Raw Transmission Data (Bulk Edit)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentAmber,
                  ),
                ),
                subtitle: Text(
                  'Edit raw comma-separated timetable for active route',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRawTransmissionEditor();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.busStopCovered, color: JweTheme.accentCyan),
                title: Text(
                  'Edit Transit Network',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentCyan,
                  ),
                ),
                subtitle: Text(
                  'Manage routes, stops, distances & two-way timetables',
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
                leading: Icon(MdiIcons.restore, color: JweTheme.accentRed),
                title: Text(
                  'Restore Default Timetables',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.accentRed,
                  ),
                ),
                subtitle: Text(
                  'Re-feed pristine default schedules into DB',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _resetToDefaults();
                },
              ),
            ],
          ),
        ),
      ),
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
                                onPressed: () => _showAddLocationDialog(),
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.codeBrackets, color: JweTheme.accentAmber, size: 18),
                                tooltip: "Raw Transmission Edit",
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _showRawTransmissionEditor,
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
                                onPressed: _showTransitSettingsSheet,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── In Transit Live HUD Card ────────────────────────
                      if (liveState.isOnBus) ...[
                        _buildInTheBusCard(liveState),
                        const SizedBox(height: 14),
                      ],

                      // ── Interactive Stop Selector ───────────────────────
                      _buildSelectorHub(),

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(MdiIcons.clockOutline, size: 14, color: JweTheme.accentAmber),
                              const SizedBox(width: 6),
                              Text(
                                "DISPATCH TIMETABLE",
                                style: GoogleFonts.rajdhani(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: JweTheme.textWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${allDepartures.length} RUNS",
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ROUTE CONFIGURATION",
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: () => _showAddLocationDialog(),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.plus, size: 13, color: JweTheme.accentAmber),
                      const SizedBox(width: 3),
                      Text(
                        "+ ADD PLACE",
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStopHorizontalList(
            label: "ORIGIN STATION (DEPARTURE)",
            selectedValue: _origin,
            activeColor: JweTheme.accentAmber,
            onSelect: (val) {
              setState(() => _origin = val);
              _persistFocus();
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
              _persistFocus();
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
            itemCount: _allStops.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == _allStops.length) {
                return GestureDetector(
                  onTap: () => _showAddLocationDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.08),
                      border: Border.all(
                        color: JweTheme.accentAmber.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.plus, size: 12, color: JweTheme.accentAmber),
                        const SizedBox(width: 4),
                        Text(
                          "ADD PLACE",
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final stop = _allStops[index];
              final isSelected = stop.name.toLowerCase() == selectedValue.toLowerCase();

              return GestureDetector(
                onTap: () => onSelect(stop.name),
                onLongPress: () => _showManageStopDialog(stop),
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
                        DefaultBusNetwork.formatPlaceName(stop.name),
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
