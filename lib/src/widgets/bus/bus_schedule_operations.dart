import 'package:intl/intl.dart';
import 'package:missions/src/models/bus_models.dart';

class BusScheduleOperations {
  static int timeToMinutes(String timeStr) {
    try {
      final now = DateTime.now();
      final parsed = DateFormat("hh:mm a").parse(timeStr);
      final combined = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      return combined.hour * 60 + combined.minute;
    } catch (_) {
      return 0;
    }
  }

  static bool matchesRoute(BusRoute r, String origin, String dest, List<BusStop> allStops) {
    final normOrigin = origin.toLowerCase().trim();
    final normDest = dest.toLowerCase().trim();

    final rOrigName = allStops.where((s) => s.id.toLowerCase() == r.originId.toLowerCase()).firstOrNull?.name ?? r.originId;
    final rDestName = allStops.where((s) => s.id.toLowerCase() == r.destinationId.toLowerCase()).firstOrNull?.name ?? r.destinationId;

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

  static List<String> getDeparturesForRoute({
    required String origin,
    required String dest,
    required List<BusRoute> allRoutes,
    required List<BusStop> allStops,
  }) {
    final normOrigin = origin.toLowerCase().trim();
    final normDest = dest.toLowerCase().trim();

    for (final r in allRoutes) {
      if (matchesRoute(r, origin, dest, allStops) && r.departures.isNotEmpty) {
        return r.departures;
      }
    }

    final defaultMap = DefaultBusNetwork.getDefaultScheduleMap();
    for (final k in defaultMap.keys) {
      if (k.toLowerCase().trim() == normOrigin) {
        for (final k2 in defaultMap[k]!.keys) {
          if (k2.toLowerCase().trim() == normDest) {
            return defaultMap[k]![k2]!;
          }
        }
      }
    }

    return const [];
  }

  static BusRoute buildFallbackDerivedRoute({
    required String origin,
    required String dest,
    required List<BusStop> allStops,
    required List<BusRoute> allRoutes,
  }) {
    final origStop = allStops.where((s) => s.name.toLowerCase() == origin.toLowerCase()).firstOrNull;
    final destStop = allStops.where((s) => s.name.toLowerCase() == dest.toLowerCase()).firstOrNull;

    double distKm = 12.0;
    if (origStop != null && destStop != null) {
      distKm = double.parse(origStop.distanceTo(destStop.latitude, destStop.longitude).toStringAsFixed(1));
    }
    final durationMins = (distKm / DefaultBusNetwork.defaultSpeedKmh * 60).round().clamp(10, 120);

    final departures = getDeparturesForRoute(
      origin: origin,
      dest: dest,
      allRoutes: allRoutes,
      allStops: allStops,
    );

    return BusRoute(
      id: 'derived_${origin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_to_${dest.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      originId: origin,
      destinationId: dest,
      name: '$origin → $dest',
      distanceKm: distKm,
      baseDurationMinutes: durationMins,
      subStops: const [],
      departures: departures,
    );
  }

  static Map<String, dynamic>? findNextBus({
    required BusRoute? activeRoute,
    required String origin,
    required String dest,
    required List<BusRoute> allRoutes,
    required List<BusStop> allStops,
  }) {
    final departures = activeRoute?.departures ??
        getDeparturesForRoute(
          origin: origin,
          dest: dest,
          allRoutes: allRoutes,
          allStops: allStops,
        );
    if (departures.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    String? nextBusTime;
    int smallestDiff = 99999;
    bool isTomorrow = false;

    for (String time in departures) {
      int busMin = timeToMinutes(time);
      int diff = busMin - currentMinutes;

      if (diff >= 0 && diff < smallestDiff) {
        smallestDiff = diff;
        nextBusTime = time;
      }
    }

    if (nextBusTime == null && departures.isNotEmpty) {
      nextBusTime = departures.first;
      isTomorrow = true;
      int busMin = timeToMinutes(nextBusTime);
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
}
