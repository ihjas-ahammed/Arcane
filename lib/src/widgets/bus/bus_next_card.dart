import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/bus/bus_route_timeline.dart';

class BusNextCard extends StatelessWidget {
  final Map<String, dynamic>? nextBusData;
  final String routeInfo;
  final BusRoute? activeRoute;
  final BusTransitLiveState? liveState;
  final VoidCallback? onSwap;
  final VoidCallback? onLocate;
  final VoidCallback? onOpenSchedule;
  final Function(DateTime startTime, DateTime finishTime)? onStartManualCommute;
  final VoidCallback? onStopManualCommute;

  const BusNextCard({
    super.key,
    required this.nextBusData,
    required this.routeInfo,
    this.activeRoute,
    this.liveState,
    this.onSwap,
    this.onLocate,
    this.onOpenSchedule,
    this.onStartManualCommute,
    this.onStopManualCommute,
  });

  String _formatTimeRemaining(int minutes) {
    if (minutes <= 0) return "Due Now";
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return "${h}h ${m}m";
    }
  }

  void _showStartCommuteDialog(BuildContext context) {
    if (activeRoute == null) return;
    final now = DateTime.now();
    final durationMins = activeRoute!.baseDurationMinutes > 0 ? activeRoute!.baseDurationMinutes : 28;
    final defaultFinish = now.add(Duration(minutes: durationMins));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Row(
          children: [
            Icon(MdiIcons.busAlert, color: JweTheme.accentTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BOARD BUS // MANUAL COMMUTE',
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Route: ${activeRoute!.name}',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '• Start Time: ${DateFormat("hh:mm a").format(now)}\n'
              '• Estimated Duration: $durationMins minutes\n'
              '• Expected Arrival: ${DateFormat("hh:mm a").format(defaultFinish)}',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Commute progress and intermediate sub-stops will update dynamically in real time.',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
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
              backgroundColor: JweTheme.accentTeal,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onStartManualCommute?.call(now, defaultFinish);
            },
            child: const Text('ENGAGE COMMUTE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = JweTheme.accentAmber;
    final isOnBus = liveState?.isOnBus ?? false;
    final isTracking = liveState?.isTracking ?? false;
    final isManual = liveState?.isManualCommute ?? false;
    final speed = liveState?.speedKmh ?? 0.0;
    final hasBus = nextBusData != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOnBus
              ? JweTheme.accentTeal.withValues(alpha: 0.8)
              : JweTheme.border.withValues(alpha: 0.8),
          width: isOnBus ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Bar (Flexible to prevent any overflow)
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnBus ? JweTheme.accentTeal : activeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOnBus ? (isManual ? 'MANUAL COMMUTE // ON BUS' : 'TRANSIT ACTIVE // ON BUS') : 'NEXT PROTOCOL DEPARTURE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isOnBus ? JweTheme.accentTeal : JweTheme.textMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (onLocate != null)
                GestureDetector(
                  onTap: onLocate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: JweTheme.isLight ? JweTheme.bgDeep : Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTracking ? Icons.my_location : Icons.location_searching,
                          size: 11,
                          color: isTracking ? JweTheme.accentCyan : JweTheme.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isTracking ? 'GPS' : 'LOCATE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: isTracking ? JweTheme.accentCyan : JweTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (onSwap != null)
                GestureDetector(
                  onTap: onSwap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.swapHorizontal, size: 11, color: activeColor),
                        const SizedBox(width: 3),
                        Text(
                          'SWAP',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Route Headline
          Row(
            children: [
              Icon(MdiIcons.busSide, size: 16, color: isOnBus ? JweTheme.accentTeal : activeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  routeInfo.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: JweTheme.textWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Main Time Display
          if (isOnBus && (liveState?.predictedMinutesToDestination != null)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    "ETA ~${liveState!.predictedMinutesToDestination} MIN",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentTeal,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onStopManualCommute,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withValues(alpha: 0.15),
                      border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "DISENGAGE",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentRed,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (hasBus) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  nextBusData!['time'],
                  style: GoogleFonts.jetBrainsMono(
                    color: activeColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                if (nextBusData!['tomorrow'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "TOMORROW",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentRed,
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatTimeRemaining(nextBusData!['minutes']).toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: activeColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                if (!isOnBus && onStartManualCommute != null)
                  GestureDetector(
                    onTap: () => _showStartCommuteDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.15),
                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.busAlert, size: 12, color: JweTheme.accentTeal),
                          const SizedBox(width: 4),
                          Text(
                            "ON BUS",
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentTeal,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "NO SCHEDULED BUS FOR THIS ROUTE",
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // Telemetry details bar
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: JweTheme.isLight ? const Color(0xFFF3EFE7) : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.speedometer, size: 13, color: JweTheme.textMid),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          speed > 0
                              ? '${speed.toStringAsFixed(0)} KM/H'
                              : (isOnBus ? 'TRANSIT' : 'STATIC'),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (liveState?.nearestStop != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.crosshairsGps, size: 13, color: JweTheme.textMid),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'NEAR ${liveState!.nearestStop!.shortCode}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: JweTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (activeRoute != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.mapMarkerDistance, size: 13, color: JweTheme.textMid),
                      const SizedBox(width: 4),
                      Text(
                        '${activeRoute!.distanceKm} KM',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          color: JweTheme.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Embedded Sub-Stops Timeline
          if (activeRoute != null && activeRoute!.subStops.isNotEmpty) ...[
            const SizedBox(height: 12),
            BusRouteProgressTimeline(
              route: activeRoute!,
              nextBusDepartureTime: nextBusData?['time'],
              liveState: liveState,
            ),
          ],
        ],
      ),
    );
  }
}