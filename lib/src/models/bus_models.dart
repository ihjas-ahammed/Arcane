import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Represents a major transit hub or stop with geographical coordinates.
class BusStop {
  final String id;
  final String name;
  final String shortCode;
  final double latitude;
  final double longitude;
  final bool isMajor;

  const BusStop({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.latitude,
    required this.longitude,
    this.isMajor = true,
  });

  BusStop copyWith({
    String? id,
    String? name,
    String? shortCode,
    double? latitude,
    double? longitude,
    bool? isMajor,
  }) {
    return BusStop(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isMajor: isMajor ?? this.isMajor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortCode': shortCode,
        'latitude': latitude,
        'longitude': longitude,
        'isMajor': isMajor,
      };

  factory BusStop.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? 'Station';
    final formattedName = DefaultBusNetwork.formatPlaceName(rawName);
    return BusStop(
      id: json['id'] as String? ?? 'stop_${formattedName.toLowerCase().replaceAll(' ', '_')}',
      name: formattedName,
      shortCode: json['shortCode'] as String? ??
          (formattedName.length >= 3 ? formattedName.substring(0, 3).toUpperCase() : formattedName.toUpperCase()),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 11.2325,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 75.9961,
      isMajor: json['isMajor'] as bool? ?? true,
    );
  }

  /// Calculate Haversine distance in kilometers to another lat/lng.
  double distanceTo(double lat, double lng) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat - latitude);
    final dLng = _degreesToRadians(lng - longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(latitude)) *
            math.cos(_degreesToRadians(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
}

/// Represents an intermediate point/stop along a bus route.
class BusSubStop {
  final String name;
  final double latitude;
  final double longitude;
  final double distanceFromOriginKm;
  final int timeOffsetMinutes;

  const BusSubStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceFromOriginKm,
    required this.timeOffsetMinutes,
  });

  BusSubStop copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? distanceFromOriginKm,
    int? timeOffsetMinutes,
  }) {
    return BusSubStop(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceFromOriginKm: distanceFromOriginKm ?? this.distanceFromOriginKm,
      timeOffsetMinutes: timeOffsetMinutes ?? this.timeOffsetMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'distanceFromOriginKm': distanceFromOriginKm,
        'timeOffsetMinutes': timeOffsetMinutes,
      };

  factory BusSubStop.fromJson(Map<String, dynamic> json) => BusSubStop(
        name: DefaultBusNetwork.formatPlaceName(json['name'] as String? ?? ''),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 11.2325,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 75.9961,
        distanceFromOriginKm: (json['distanceFromOriginKm'] as num?)?.toDouble() ?? 0.0,
        timeOffsetMinutes: json['timeOffsetMinutes'] as int? ?? 0,
      );
}

/// A directional route between two primary stops.
class BusRoute {
  final String id;
  final String originId;
  final String destinationId;
  final String name;
  final double distanceKm;
  final int baseDurationMinutes;
  final List<BusSubStop> subStops;
  final List<String> departures;

  const BusRoute({
    required this.id,
    required this.originId,
    required this.destinationId,
    required this.name,
    required this.distanceKm,
    required this.baseDurationMinutes,
    this.subStops = const [],
    this.departures = const [],
  });

  BusRoute copyWith({
    String? id,
    String? originId,
    String? destinationId,
    String? name,
    double? distanceKm,
    int? baseDurationMinutes,
    List<BusSubStop>? subStops,
    List<String>? departures,
  }) {
    return BusRoute(
      id: id ?? this.id,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      name: name ?? this.name,
      distanceKm: distanceKm ?? this.distanceKm,
      baseDurationMinutes: baseDurationMinutes ?? this.baseDurationMinutes,
      subStops: subStops ?? this.subStops,
      departures: departures ?? this.departures,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'originId': originId,
        'destinationId': destinationId,
        'name': name,
        'distanceKm': distanceKm,
        'baseDurationMinutes': baseDurationMinutes,
        'subStops': subStops.map((s) => s.toJson()).toList(),
        'departures': departures,
      };

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    final origId = json['originId'] as String? ?? 'ss_college';
    final destId = json['destinationId'] as String? ?? 'edavannappara';
    final formattedName = rawName.contains('→')
        ? rawName.split('→').map((p) => DefaultBusNetwork.formatPlaceName(p)).join(' → ')
        : DefaultBusNetwork.formatPlaceName(rawName);

    return BusRoute(
      id: json['id'] as String? ?? 'route_${DateTime.now().millisecondsSinceEpoch}',
      originId: origId,
      destinationId: destId,
      name: formattedName.isNotEmpty ? formattedName : '${DefaultBusNetwork.formatPlaceName(origId)} → ${DefaultBusNetwork.formatPlaceName(destId)}',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 10.0,
      baseDurationMinutes: json['baseDurationMinutes'] as int? ?? 25,
      subStops: (json['subStops'] as List<dynamic>?)
              ?.map((e) => BusSubStop.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      departures: (json['departures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Computes estimated arrival time for a specific sub-stop given a bus departure time.
  String predictSubStopArrivalTime(String departureTimeStr, BusSubStop subStop, {double? customSpeedKmh}) {
    try {
      final now = DateTime.now();
      final parsed = DateFormat("hh:mm a").parse(departureTimeStr);
      final depTime = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);

      int offsetMinutes = subStop.timeOffsetMinutes;
      if (customSpeedKmh != null && customSpeedKmh > 5 && distanceKm > 0) {
        final hours = subStop.distanceFromOriginKm / customSpeedKmh;
        offsetMinutes = (hours * 60).round();
      }

      final eta = depTime.add(Duration(minutes: offsetMinutes));
      return DateFormat("hh:mm a").format(eta);
    } catch (_) {
      return departureTimeStr;
    }
  }
}

/// Original pristine bus network data & defaults with clean Capitalized names
class DefaultBusNetwork {
  /// Formats place/station strings to clean Capitalized / Title case
  static String formatPlaceName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower == 's.s college' || lower == 's.s. college' || lower == 'ss college') {
      return 'S.S College';
    }
    if (lower == 'edavannappara') {
      return 'Edavannappara';
    }
    if (lower == 'areekode') {
      return 'Areekode';
    }

    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains('.')) {
        return word
            .split('.')
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1).toLowerCase())
            .join('.');
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static const List<BusStop> stops = [
    BusStop(id: 'ss_college', name: 'S.S College', shortCode: 'SSC', latitude: 11.2325, longitude: 75.9961),
    BusStop(id: 'edavannappara', name: 'Edavannappara', shortCode: 'EDV', latitude: 11.2185, longitude: 75.9628),
    BusStop(id: 'areekode', name: 'Areekode', shortCode: 'ARK', latitude: 11.2384, longitude: 76.0494),
  ];

  static const List<String> departuresSscToEdv = [
    "06:30 AM", "06:35 AM", "06:40 AM", "06:55 AM", "07:20 AM", "07:40 AM",
    "07:55 AM", "08:10 AM", "08:15 AM", "08:30 AM", "08:40 AM", "08:50 AM",
    "09:05 AM", "09:25 AM", "09:40 AM", "10:05 AM", "10:13 AM", "10:18 AM",
    "10:40 AM", "10:50 AM", "11:05 AM", "11:20 AM", "11:38 AM", "11:55 AM",
    "12:03 PM", "12:18 PM", "12:30 PM", "12:40 PM", "01:08 PM", "01:32 PM",
    "01:42 PM", "01:50 PM", "01:55 PM", "02:05 PM", "02:15 PM", "02:25 PM",
    "02:48 PM", "03:00 PM", "03:10 PM", "03:25 PM", "03:40 PM", "04:05 PM",
    "04:20 PM", "04:37 PM", "04:50 PM", "04:55 PM", "05:10 PM", "05:22 PM",
    "05:35 PM", "05:45 PM", "05:53 PM", "05:55 PM", "06:03 PM", "06:13 PM",
    "06:23 PM", "06:35 PM"
  ];

  static const List<String> departuresSscToArk = [
    "07:06 AM", "07:28 AM", "07:43 AM", "07:53 AM", "08:03 AM", "08:20 AM",
    "08:35 AM", "08:50 AM", "09:13 AM", "09:23 AM", "09:35 AM", "09:43 AM",
    "10:02 AM", "10:20 AM", "10:31 AM", "10:35 AM", "10:53 AM", "11:03 AM",
    "11:20 AM", "11:30 AM", "11:38 AM", "11:58 AM", "12:18 PM", "12:28 PM",
    "12:33 PM", "12:43 PM", "12:50 PM", "01:03 PM", "01:11 PM", "01:18 PM",
    "01:31 PM", "01:48 PM", "02:03 PM", "02:16 PM", "02:33 PM", "02:48 PM",
    "03:10 PM", "03:38 PM", "03:48 PM", "03:58 PM", "04:08 PM", "04:16 PM",
    "04:33 PM", "04:50 PM", "04:58 PM", "05:10 PM", "05:18 PM", "05:38 PM",
    "05:43 PM", "06:01 PM", "06:10 PM", "06:18 PM", "06:23 PM", "06:38 PM",
    "06:48 PM", "07:08 PM"
  ];

  static const List<String> departuresEdvToSsc = [
    "08:00 AM", "08:15 AM", "08:35 AM", "08:55 AM", "09:15 AM", "09:30 AM",
    "09:45 AM", "10:10 AM", "10:20 AM", "10:35 AM", "10:50 AM", "11:10 AM",
    "11:25 AM", "11:40 AM", "12:00 PM", "12:15 PM", "12:30 PM", "12:45 PM",
    "01:00 PM", "01:15 PM", "01:30 PM", "01:45 PM", "02:00 PM", "02:15 PM",
    "02:30 PM", "02:45 PM", "03:00 PM", "03:15 PM", "03:30 PM", "03:45 PM",
    "04:00 PM", "04:15 PM", "04:30 PM", "04:45 PM", "05:00 PM", "05:15 PM",
    "05:30 PM", "05:45 PM", "06:00 PM", "06:15 PM", "06:30 PM"
  ];

  /// Pristine default map with Capitalized keys
  static Map<String, Map<String, List<String>>> getDefaultScheduleMap() {
    final map = {
      "S.S College": {
        "Edavannappara": List<String>.from(departuresSscToEdv),
        "Areekode": List<String>.from(departuresSscToArk),
      },
      "Edavannappara": {
        "S.S College": List<String>.from(departuresEdvToSsc),
        "Areekode": <String>[],
      },
      "Areekode": {
        "S.S College": <String>[],
        "Edavannappara": <String>[],
      },
    };
    calculateAndFillDerivedSchedules(map);
    return map;
  }

  /// Calculates derived routes and ensures two-way bidirectional data consistency.
  static void calculateAndFillDerivedSchedules(Map<String, Map<String, List<String>>> schedules) {
    // Normalizes map keys to Title Case while preserving case-insensitive lookups
    String? findKey(String target) {
      final tLow = target.toLowerCase().trim();
      for (final k in schedules.keys) {
        if (k.toLowerCase().trim() == tLow) return k;
      }
      return null;
    }

    final sscKey = findKey("S.S College") ?? "S.S College";
    final edvKey = findKey("Edavannappara") ?? "Edavannappara";
    final arkKey = findKey("Areekode") ?? "Areekode";

    // 1. Edavannappara -> Areekode derived from Edavannappara -> S.S College
    if (schedules[edvKey] != null &&
        schedules[edvKey]![sscKey] != null &&
        schedules[edvKey]![sscKey]!.isNotEmpty) {
      if (schedules[edvKey]![arkKey] == null || schedules[edvKey]![arkKey]!.isEmpty) {
        schedules[edvKey]![arkKey] = schedules[edvKey]![sscKey]!
            .map((t) => addMinutesToTime(t, 0))
            .toList();
      }
    }

    // 2. Areekode -> S.S College and Areekode -> Edavannappara derived from S.S College -> Edavannappara (-2 min)
    if (schedules[sscKey] != null &&
        schedules[sscKey]![edvKey] != null &&
        schedules[sscKey]![edvKey]!.isNotEmpty) {
      if (schedules[arkKey] == null) schedules[arkKey] = {};

      if (schedules[arkKey]![sscKey] == null || schedules[arkKey]![sscKey]!.isEmpty) {
        schedules[arkKey]![sscKey] = schedules[sscKey]![edvKey]!
            .map((t) => addMinutesToTime(t, -2))
            .toList();
      }

      if (schedules[arkKey]![edvKey] == null || schedules[arkKey]![edvKey]!.isEmpty) {
        schedules[arkKey]![edvKey] = schedules[sscKey]![edvKey]!
            .map((t) => addMinutesToTime(t, -2))
            .toList();
      }
    }

    // 3. General Auto-Addition of Two-Way (Bidirectional) Data for custom places & routes
    final allOrigins = List<String>.from(schedules.keys);
    for (final orig in allOrigins) {
      final destMap = schedules[orig];
      if (destMap == null) continue;

      for (final dest in List<String>.from(destMap.keys)) {
        final forwardList = destMap[dest];
        if (forwardList == null || forwardList.isEmpty) continue;

        // Ensure reverse schedule structure exists
        if (!schedules.containsKey(dest)) {
          schedules[dest] = {};
        }

        // If reverse route has no departures, auto-populate two-way return times with reasonable transit spacing
        if (schedules[dest]![orig] == null || schedules[dest]![orig]!.isEmpty) {
          schedules[dest]![orig] = forwardList.map((t) => addMinutesToTime(t, 30)).toList();
        }
      }
    }
  }

  static String addMinutesToTime(String timeStr, int minutesToAdd) {
    try {
      DateTime parsed = DateFormat("hh:mm a").parse(timeStr);
      DateTime newTime = parsed.add(Duration(minutes: minutesToAdd));
      return DateFormat("hh:mm a").format(newTime);
    } catch (_) {
      return timeStr;
    }
  }

  /// Clean routes with NO pre-added intermediate sub-stops (only the places we have)
  static List<BusRoute> getRoutes() {
    final scheduleMap = getDefaultScheduleMap();

    return [
      // 1. S.S College -> Edavannappara
      BusRoute(
        id: 'ssc_to_edv',
        originId: 'ss_college',
        destinationId: 'edavannappara',
        name: 'S.S College → Edavannappara',
        distanceKm: 13.5,
        baseDurationMinutes: 28,
        subStops: const [],
        departures: scheduleMap["S.S College"]?["Edavannappara"] ?? departuresSscToEdv,
      ),

      // 2. Edavannappara -> S.S College
      BusRoute(
        id: 'edv_to_ssc',
        originId: 'edavannappara',
        destinationId: 'ss_college',
        name: 'Edavannappara → S.S College',
        distanceKm: 13.5,
        baseDurationMinutes: 28,
        subStops: const [],
        departures: scheduleMap["Edavannappara"]?["S.S College"] ?? departuresEdvToSsc,
      ),

      // 3. S.S College -> Areekode
      BusRoute(
        id: 'ssc_to_ark',
        originId: 'ss_college',
        destinationId: 'areekode',
        name: 'S.S College → Areekode',
        distanceKm: 8.5,
        baseDurationMinutes: 18,
        subStops: const [],
        departures: scheduleMap["S.S College"]?["Areekode"] ?? departuresSscToArk,
      ),

      // 4. Edavannappara -> Areekode
      BusRoute(
        id: 'edv_to_ark',
        originId: 'edavannappara',
        destinationId: 'areekode',
        name: 'Edavannappara → Areekode',
        distanceKm: 18.0,
        baseDurationMinutes: 35,
        subStops: const [],
        departures: scheduleMap["Edavannappara"]?["Areekode"] ?? departuresEdvToSsc,
      ),

      // 5. Areekode -> S.S College
      BusRoute(
        id: 'ark_to_ssc',
        originId: 'areekode',
        destinationId: 'ss_college',
        name: 'Areekode → S.S College',
        distanceKm: 8.5,
        baseDurationMinutes: 18,
        subStops: const [],
        departures: scheduleMap["Areekode"]?["S.S College"] ?? departuresSscToEdv,
      ),

      // 6. Areekode -> Edavannappara
      BusRoute(
        id: 'ark_to_edv',
        originId: 'areekode',
        destinationId: 'edavannappara',
        name: 'Areekode → Edavannappara',
        distanceKm: 18.0,
        baseDurationMinutes: 35,
        subStops: const [],
        departures: scheduleMap["Areekode"]?["Edavannappara"] ?? departuresSscToEdv,
      ),
    ];
  }
}
