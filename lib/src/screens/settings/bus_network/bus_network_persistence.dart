import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusNetworkPersistence {
  static ({List<BusStop> stops, List<BusRoute> routes}) loadData(AppProvider provider) {
    final settings = provider.settings;
    List<BusStop> stops;
    List<BusRoute> routes;

    // Load custom stops or default
    if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
      stops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
    } else {
      stops = List.from(DefaultBusNetwork.stops);
    }

    // Load custom routes or default
    if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
      routes = settings.customBusRoutesJson!.map((e) => BusRoute.fromJson(e)).toList();
    } else {
      routes = DefaultBusNetwork.getRoutes();
    }

    // Merge any custom schedules
    if (settings.customBusSchedules != null) {
      for (int i = 0; i < routes.length; i++) {
        final r = routes[i];
        final originName = stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final destName = stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        if (settings.customBusSchedules![originName] != null &&
            settings.customBusSchedules![originName]![destName] != null) {
          routes[i] = r.copyWith(departures: settings.customBusSchedules![originName]![destName]!);
        }
      }
    }

    return (stops: stops, routes: routes);
  }

  static Future<void> saveAll({
    required BuildContext context,
    required AppProvider provider,
    required List<BusStop> stops,
    required List<BusRoute> routes,
    required VoidCallback onSaved,
  }) async {
    final newSettings = AppSettings.fromJson(provider.settings.toJson());

    newSettings.customBusStopsJson = stops.map((s) => s.toJson()).toList();
    newSettings.customBusRoutesJson = routes.map((r) => r.toJson()).toList();

    // Map to customBusSchedules for backward compatibility
    final Map<String, Map<String, List<String>>> scheduleMap = {};
    for (final r in routes) {
      final originName = stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
      final destName = stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
      if (!scheduleMap.containsKey(originName)) {
        scheduleMap[originName] = {};
      }
      scheduleMap[originName]![destName] = r.departures;
    }

    // Auto addition of two-way bidirectional data and derived routes
    DefaultBusNetwork.calculateAndFillDerivedSchedules(scheduleMap);

    // Sync back into routes
    for (final orig in scheduleMap.keys) {
      for (final dst in scheduleMap[orig]!.keys) {
        final deps = scheduleMap[orig]![dst]!;
        final idx = routes.indexWhere((r) {
          final rOrig = stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
          final rDst = stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
          return rOrig.toUpperCase() == orig.toUpperCase() && rDst.toUpperCase() == dst.toUpperCase();
        });

        if (idx >= 0) {
          routes[idx] = routes[idx].copyWith(departures: deps);
        } else {
          final origStop = stops.where((s) => s.name.toUpperCase() == orig.toUpperCase()).firstOrNull;
          final dstStop = stops.where((s) => s.name.toUpperCase() == dst.toUpperCase()).firstOrNull;
          routes.add(
            BusRoute(
              id: 'route_${orig.toLowerCase()}_to_${dst.toLowerCase()}',
              originId: origStop?.id ?? orig,
              destinationId: dstStop?.id ?? dst,
              name: '$orig → $dst',
              distanceKm: 12.0,
              speedKmh: DefaultBusNetwork.defaultSpeedKmh,
              baseDurationMinutes: (12.0 / DefaultBusNetwork.defaultSpeedKmh * 60).round(),
              subStops: const [],
              departures: deps,
            ),
          );
        }
      }
    }

    newSettings.customBusStopsJson = stops.map((s) => s.toJson()).toList();
    newSettings.customBusRoutesJson = routes.map((r) => r.toJson()).toList();
    newSettings.customBusSchedules = scheduleMap;

    provider.setSettings(newSettings);

    // Update location service context
    BusLocationService.instance.updateContext(stops: stops);

    // Sync widget
    final firstRoute = routes.firstOrNull;
    if (firstRoute != null) {
      final originName = stops.where((s) => s.id == firstRoute.originId).firstOrNull?.name ?? firstRoute.originId;
      final destName = stops.where((s) => s.id == firstRoute.destinationId).firstOrNull?.name ?? firstRoute.destinationId;
      final nextTime = firstRoute.departures.firstOrNull ?? '08:15 AM';
      HomeWidgetService.instance.publishBus(
        origin: originName,
        destination: destName,
        nextTime: nextTime,
        nextSubStop: '',
        isOnBus: false,
        speedKmh: 0,
        minutesRemaining: firstRoute.baseDurationMinutes,
      );
    }

    onSaved();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transit network & sub-stop data successfully saved!')),
      );
    }
  }

  static void showResetDialog({
    required BuildContext context,
    required VoidCallback onReset,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          "RESET TO DEFAULT?",
          style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This will erase all custom transit stops, custom routes, sub-stops, and timetables, restoring the built-in defaults.",
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onReset();
            },
            child: const Text("RESET ALL", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
