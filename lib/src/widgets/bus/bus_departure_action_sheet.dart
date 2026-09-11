import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'bus_speed_distance_dialogs.dart';

/// Shows bottom sheet action menu for an individual departure
Future<void> showBusDepartureActionSheet(
  BuildContext context, {
  required String time,
  required String origin,
  required String destination,
  required BusRoute? route,
  required VoidCallback onInTheBus,
  required VoidCallback onEndTrip,
  required VoidCallback onEditTime,
  required VoidCallback onRemoveTime,
  required Future<void> Function(double newSpeed) onSpeedChanged,
  required Future<void> Function(double newDistance) onDistanceChanged,
}) async {
  final distKm = (route != null && route.distanceKm > 0) ? route.distanceKm : 0.0;
  final routeSpeed = (route != null && route.speedKmh > 0) ? route.speedKmh : DefaultBusNetwork.defaultSpeedKmh;
  final estDurationMins = distKm > 0 ? (distKm / routeSpeed * 60).round() : 0;
  final liveState = BusLocationService.instance.currentState;

  return showModalBottomSheet(
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
              'ROUTE: ${DefaultBusNetwork.formatPlaceName(origin)} → ${DefaultBusNetwork.formatPlaceName(destination)}',
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
                  Expanded(
                    child: Row(
                      children: [
                        Icon(MdiIcons.mapMarkerDistance, size: 15, color: JweTheme.accentCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            distKm > 0
                                ? '${distKm.toStringAsFixed(1)} km · ~$estDurationMins min @ ${routeSpeed.toStringAsFixed(0)} km/h'
                                : 'Distance: Not set (${routeSpeed.toStringAsFixed(0)} km/h)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: JweTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final newSpeed = await showAskSpeedDialog(
                            ctx,
                            origin: origin,
                            destination: destination,
                            currentSpeed: routeSpeed,
                          );
                          if (newSpeed != null && newSpeed > 0) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            await onSpeedChanged(newSpeed);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            'SPEED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: JweTheme.accentCyan,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          final newDist = await showAskDistanceDialog(
                            ctx,
                            origin: origin,
                            destination: destination,
                            currentDistance: distKm > 0 ? distKm : null,
                          );
                          if (newDist != null && newDist > 0) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            await onDistanceChanged(newDist);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            distKm > 0 ? 'DIST' : 'SET DIST',
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
                  'Trip in progress to ${liveState.destinationName ?? destination}. Tap to complete / end trip.',
                  style: GoogleFonts.rajdhani(fontSize: 11.5, color: JweTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onEndTrip();
                },
              ),
            ] else ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(ctx);
                    onInTheBus();
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
                                'Board this run · Track live travel @ ${routeSpeed.toStringAsFixed(0)} km/h on HUD, notification & widgets',
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
                onEditTime();
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
                onRemoveTime();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
