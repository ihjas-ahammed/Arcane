import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/services/notification_service.dart';

class BusTransitLiveState {
  final bool isTracking;
  final Position? currentPosition;
  final double speedKmh;
  final BusStop? nearestStop;
  final double? distanceToNearestStopKm;
  final bool isOnBus;
  final bool isManualCommute;
  final DateTime? commuteStartTime;
  final DateTime? commuteExpectedFinishTime;
  final BusRoute? activeRoute;
  final String? originName;
  final String? destinationName;
  final double? routeDistanceKm;
  final String? selectedDepartureTime;
  final BusSubStop? currentSubStop;
  final BusSubStop? nextSubStop;
  final double? progressAlongRoute; // 0.0 .. 1.0
  final int? predictedMinutesToNextStop;
  final int? predictedMinutesToDestination;
  final String? locationStatusMessage;

  const BusTransitLiveState({
    this.isTracking = false,
    this.currentPosition,
    this.speedKmh = 0.0,
    this.nearestStop,
    this.distanceToNearestStopKm,
    this.isOnBus = false,
    this.isManualCommute = false,
    this.commuteStartTime,
    this.commuteExpectedFinishTime,
    this.activeRoute,
    this.originName,
    this.destinationName,
    this.routeDistanceKm,
    this.selectedDepartureTime,
    this.currentSubStop,
    this.nextSubStop,
    this.progressAlongRoute,
    this.predictedMinutesToNextStop,
    this.predictedMinutesToDestination,
    this.locationStatusMessage,
  });
}

class BusLocationService {
  BusLocationService._();
  static final BusLocationService instance = BusLocationService._();

  StreamSubscription<Position>? _positionSub;
  Timer? _manualCommuteTimer;
  final _stateController = StreamController<BusTransitLiveState>.broadcast();
  Stream<BusTransitLiveState> get stateStream => _stateController.stream;

  BusTransitLiveState _currentState = const BusTransitLiveState();
  BusTransitLiveState get currentState => _currentState;

  List<BusStop> _availableStops = DefaultBusNetwork.stops;
  BusRoute? _currentRoute;
  double _rollingAvgSpeedKmh = 30.0;

  void updateContext({
    required List<BusStop> stops,
    BusRoute? activeRoute,
    double? customAvgSpeedKmh,
  }) {
    _availableStops = stops;
    _currentRoute = activeRoute;
    if (customAvgSpeedKmh != null && customAvgSpeedKmh > 5) {
      _rollingAvgSpeedKmh = customAvgSpeedKmh;
    }
  }

  /// Multi-tier location resolution:
  /// 1. Instantaneous check on `getLastKnownPosition()` (0 ms latency).
  /// 2. Fast `getCurrentPosition()` with medium accuracy (Wi-Fi/Cell/GPS fused provider).
  /// 3. Zero-crash fallback when GPS satellite fix is unavailable indoors.
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = true;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 2),
          onTimeout: () => true,
        );
      } catch (_) {
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        _emitState(_currentState = BusTransitLiveState(
          isTracking: false,
          nearestStop: _currentState.nearestStop,
          locationStatusMessage: 'Location services disabled',
        ));
        return null;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => LocationPermission.denied,
        );
      } catch (_) {}

      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission().timeout(
            const Duration(seconds: 4),
            onTimeout: () => LocationPermission.denied,
          );
        } catch (_) {}
      }

      if (permission == LocationPermission.deniedForever) {
        _emitState(_currentState = BusTransitLiveState(
          isTracking: false,
          nearestStop: _currentState.nearestStop,
          locationStatusMessage: 'Location permission disabled in system settings',
        ));
        return null;
      }

      // Step 1: Immediately retrieve and process cached last known position
      Position? bestPos;
      try {
        bestPos = await Geolocator.getLastKnownPosition();
        if (bestPos != null) {
          _processPosition(bestPos);
        }
      } catch (e) {
        debugPrint('[BusLocationService] getLastKnownPosition: $e');
      }

      // Step 2: Attempt to obtain fresh position with medium accuracy (fast Fused provider)
      try {
        const settings = LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 7),
        );
        final freshPos = await Geolocator.getCurrentPosition(locationSettings: settings);
        _processPosition(freshPos);
        return freshPos;
      } catch (e) {
        debugPrint('[BusLocationService] fresh position note: $e');
        if (bestPos != null) {
          return bestPos; // Graceful zero-failure fallback
        }
      }

      if (bestPos != null) return bestPos;

      _emitState(_currentState = BusTransitLiveState(
        isTracking: true,
        nearestStop: _currentState.nearestStop,
        locationStatusMessage: 'Acquiring GPS fix...',
      ));
      return null;
    } catch (e) {
      debugPrint('[BusLocationService] getCurrentPosition error: $e');
      return null;
    }
  }

  /// Start real-time position stream
  Future<void> startTracking({
    List<BusStop>? stops,
    BusRoute? activeRoute,
  }) async {
    if (stops != null) _availableStops = stops;
    if (activeRoute != null) _currentRoute = activeRoute;

    try {
      // 1. Initial quick check
      getCurrentPosition();

      // 2. Start ongoing stream without blocking
      await _positionSub?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 15,
      );

      _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) => _processPosition(position),
        onError: (err) {
          debugPrint('[BusLocationService] stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('[BusLocationService] startTracking error: $e');
    }
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _emitState(_currentState = BusTransitLiveState(
      isTracking: false,
      nearestStop: _currentState.nearestStop,
      locationStatusMessage: 'Tracking stopped',
    ));
  }

  /// Manually set / simulate user location to a specific stop
  void setManualStop(BusStop stop, {BusRoute? route}) {
    if (route != null) _currentRoute = route;
    _currentState = BusTransitLiveState(
      isTracking: true,
      nearestStop: stop,
      distanceToNearestStopKm: 0.0,
      isOnBus: false,
      activeRoute: _currentRoute,
      locationStatusMessage: 'Set to ${stop.name}',
    );
    _emitState(_currentState);
  }

  /// Manual On-Bus Commute Tracker: computes progress and ETAs from start time and finish time.
  /// Defaults to 20 km/h assumed speed per user instruction.
  void startManualCommute({
    required BusRoute route,
    DateTime? startTime,
    DateTime? expectedFinishTime,
    double assumedSpeedKmh = 20.0,
    String? originName,
    String? destinationName,
    double? customDistanceKm,
    String? departureTime,
  }) {
    _currentRoute = route;
    final now = DateTime.now();
    final start = startTime ?? now;
    final distanceKm = customDistanceKm ?? (route.distanceKm > 0 ? route.distanceKm : 10.0);
    // Speed assumption = 20 km/h -> Duration (mins) = (distance / 20) * 60
    final durationMins = math.max(1, (distanceKm / assumedSpeedKmh * 60).round());
    final finish = expectedFinishTime ?? start.add(Duration(minutes: durationMins));

    final orig = originName ?? DefaultBusNetwork.formatPlaceName(route.originId);
    final dest = destinationName ?? DefaultBusNetwork.formatPlaceName(route.destinationId);

    _manualCommuteTimer?.cancel();
    _tickManualCommute(
      route: route,
      start: start,
      finish: finish,
      assumedSpeedKmh: assumedSpeedKmh,
      distanceKm: distanceKm,
      origin: orig,
      destination: dest,
      departureTime: departureTime,
    );

    _manualCommuteTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _tickManualCommute(
        route: route,
        start: start,
        finish: finish,
        assumedSpeedKmh: assumedSpeedKmh,
        distanceKm: distanceKm,
        origin: orig,
        destination: dest,
        departureTime: departureTime,
      );
    });
  }

  void _tickManualCommute({
    required BusRoute route,
    required DateTime start,
    required DateTime finish,
    required double assumedSpeedKmh,
    required double distanceKm,
    required String origin,
    required String destination,
    String? departureTime,
  }) {
    final now = DateTime.now();
    final totalSec = math.max(1, finish.difference(start).inSeconds);
    final elapsedSec = now.difference(start).inSeconds.clamp(0, totalSec);
    final progress = (elapsedSec / totalSec).clamp(0.0, 1.0);
    final remainingMins = math.max(0, ((totalSec - elapsedSec) / 60).ceil());

    // Resolve intermediate sub-stop according to progress ratio
    BusSubStop? currSubStop;
    BusSubStop? nextSubStop;
    int? minsToNext;

    if (route.subStops.isNotEmpty) {
      final subStops = route.subStops;
      final totalKm = distanceKm > 0 ? distanceKm : 1.0;
      final currentTraveledKm = totalKm * progress;

      int curIdx = 0;
      for (int i = 0; i < subStops.length; i++) {
        if (subStops[i].distanceFromOriginKm <= currentTraveledKm) {
          curIdx = i;
        }
      }
      currSubStop = subStops[curIdx];
      if (curIdx < subStops.length - 1) {
        nextSubStop = subStops[curIdx + 1];
        final remainingDistToNext = math.max(0.1, nextSubStop.distanceFromOriginKm - currentTraveledKm);
        minsToNext = math.max(1, (remainingDistToNext / assumedSpeedKmh * 60).round());
      } else {
        nextSubStop = subStops.last;
        minsToNext = 0;
      }
    }

    final isOnBus = progress < 1.0;
    final progressPct = (progress * 100).round();

    _currentState = BusTransitLiveState(
      isTracking: true,
      isOnBus: isOnBus,
      isManualCommute: true,
      commuteStartTime: start,
      commuteExpectedFinishTime: finish,
      speedKmh: isOnBus ? assumedSpeedKmh : 0.0,
      activeRoute: route,
      originName: origin,
      destinationName: destination,
      routeDistanceKm: distanceKm,
      selectedDepartureTime: departureTime,
      currentSubStop: currSubStop,
      nextSubStop: nextSubStop,
      progressAlongRoute: progress,
      predictedMinutesToNextStop: minsToNext,
      predictedMinutesToDestination: remainingMins,
      locationStatusMessage: isOnBus
          ? 'In the Bus (~${remainingMins}m remaining)'
          : 'Arrived at $destination',
    );
    _emitState(_currentState);

    // Update ongoing notification
    if (isOnBus) {
      NotificationService.instance.showBusTransitNotification(
        origin: origin,
        destination: destination,
        progress: progress,
        minutesRemaining: remainingMins,
        speedKmh: assumedSpeedKmh,
      );
    } else {
      NotificationService.instance.cancelBusTransitNotification();
    }

    // Update homescreen widget
    HomeWidgetService.instance.publishBus(
      origin: origin,
      destination: destination,
      nextTime: departureTime ?? DateFormat('hh:mm a').format(start),
      nextSubStop: nextSubStop?.name ?? '',
      isOnBus: isOnBus,
      speedKmh: isOnBus ? assumedSpeedKmh.round() : 0,
      minutesRemaining: remainingMins,
      progressPct: progressPct,
    );
  }

  void stopManualCommute() {
    _manualCommuteTimer?.cancel();
    _manualCommuteTimer = null;
    final prevOrigin = _currentState.originName ?? _currentRoute?.originId ?? 'S.S College';
    final prevDest = _currentState.destinationName ?? _currentRoute?.destinationId ?? 'Edavannappara';
    _currentState = BusTransitLiveState(
      isTracking: _currentState.isTracking,
      currentPosition: _currentState.currentPosition,
      nearestStop: _currentState.nearestStop,
      isOnBus: false,
      isManualCommute: false,
      activeRoute: _currentRoute,
      locationStatusMessage: 'Commute ended',
    );
    _emitState(_currentState);

    NotificationService.instance.cancelBusTransitNotification();
    HomeWidgetService.instance.publishBus(
      origin: DefaultBusNetwork.formatPlaceName(prevOrigin),
      destination: DefaultBusNetwork.formatPlaceName(prevDest),
      nextTime: _currentRoute?.departures.firstOrNull ?? '08:15 AM',
      isOnBus: false,
      speedKmh: 0,
      minutesRemaining: -1,
      progressPct: 0,
    );
  }

  void _processPosition(Position pos) {
    if (_currentState.isManualCommute) return;

    double speedKmh = math.max(0.0, pos.speed * 3.6);

    BusStop? nearest;
    double minDistanceKm = double.infinity;
    for (final stop in _availableStops) {
      final d = stop.distanceTo(pos.latitude, pos.longitude);
      if (d < minDistanceKm) {
        minDistanceKm = d;
        nearest = stop;
      }
    }

    bool isOnBus = speedKmh >= 15.0;
    if (speedKmh > 10.0 && speedKmh < 90.0) {
      _rollingAvgSpeedKmh = (_rollingAvgSpeedKmh * 0.8) + (speedKmh * 0.2);
    }

    BusSubStop? currSubStop;
    BusSubStop? nextSubStop;
    double? progressAlongRoute;
    int? minsToNext;
    int? minsToDest;

    if (_currentRoute != null && _currentRoute!.subStops.isNotEmpty) {
      final subStops = _currentRoute!.subStops;
      final totalKm = _currentRoute!.distanceKm;

      int closestIdx = 0;
      double closestSubStopDist = double.infinity;
      for (int i = 0; i < subStops.length; i++) {
        final d = _haversineKm(
          pos.latitude,
          pos.longitude,
          subStops[i].latitude,
          subStops[i].longitude,
        );
        if (d < closestSubStopDist) {
          closestSubStopDist = d;
          closestIdx = i;
        }
      }

      currSubStop = subStops[closestIdx];
      if (closestIdx < subStops.length - 1) {
        nextSubStop = subStops[closestIdx + 1];
      } else {
        nextSubStop = subStops.last;
      }

      if (totalKm > 0) {
        progressAlongRoute = (currSubStop.distanceFromOriginKm / totalKm).clamp(0.0, 1.0);
      }

      final effSpeed = math.max(15.0, speedKmh > 5 ? speedKmh : _rollingAvgSpeedKmh);
      final distToNextKm = _haversineKm(
        pos.latitude,
        pos.longitude,
        nextSubStop.latitude,
        nextSubStop.longitude,
      );
      minsToNext = math.max(1, (distToNextKm / effSpeed * 60).round());

      final distToDestKm = _haversineKm(
        pos.latitude,
        pos.longitude,
        subStops.last.latitude,
        subStops.last.longitude,
      );
      minsToDest = math.max(1, (distToDestKm / effSpeed * 60).round());
    }

    _currentState = BusTransitLiveState(
      isTracking: true,
      currentPosition: pos,
      speedKmh: speedKmh,
      nearestStop: nearest,
      distanceToNearestStopKm: minDistanceKm.isFinite ? minDistanceKm : null,
      isOnBus: isOnBus,
      activeRoute: _currentRoute,
      currentSubStop: currSubStop,
      nextSubStop: nextSubStop,
      progressAlongRoute: progressAlongRoute,
      predictedMinutesToNextStop: minsToNext,
      predictedMinutesToDestination: minsToDest,
      locationStatusMessage: isOnBus ? 'In Transit (~${speedKmh.toStringAsFixed(0)} km/h)' : 'GPS Active',
    );

    _emitState(_currentState);
  }

  void _emitState(BusTransitLiveState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  BusStop? resolveAutoOrigin(List<BusStop> stops, Position? pos) {
    if (pos == null || stops.isEmpty) return null;
    BusStop? closest;
    double minDist = double.infinity;
    for (final s in stops) {
      final d = s.distanceTo(pos.latitude, pos.longitude);
      if (d < minDist) {
        minDist = d;
        closest = s;
      }
    }
    return closest;
  }

  BusStop? resolveAutoDestination(
    BusStop origin,
    List<BusStop> stops,
    List<BusRoute> routes, {
    String? defaultDestId,
  }) {
    if (defaultDestId != null) {
      final found = stops.where((s) => s.id == defaultDestId).firstOrNull;
      if (found != null && found.id != origin.id) return found;
    }

    final route = routes.where((r) => r.originId == origin.id).firstOrNull;
    if (route != null) {
      return stops.where((s) => s.id == route.destinationId).firstOrNull;
    }

    return stops.where((s) => s.id != origin.id).firstOrNull;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void dispose() {
    _manualCommuteTimer?.cancel();
    _positionSub?.cancel();
    _stateController.close();
  }
}
