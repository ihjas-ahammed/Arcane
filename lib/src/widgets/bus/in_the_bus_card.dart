import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class InTheBusCard extends StatelessWidget {
  final BusTransitLiveState liveState;
  final String origin;
  final String destination;
  final VoidCallback onEndTrip;
  final VoidCallback onChangeSpeed;
  final VoidCallback onChangeDistance;

  const InTheBusCard({
    super.key,
    required this.liveState,
    required this.origin,
    required this.destination,
    required this.onEndTrip,
    required this.onChangeSpeed,
    required this.onChangeDistance,
  });

  @override
  Widget build(BuildContext context) {
    final progress = liveState.progressAlongRoute ?? 0.0;
    final pct = (progress * 100).round();
    final remainingMins = liveState.predictedMinutesToDestination ?? 0;
    final totalKm = liveState.routeDistanceKm ?? liveState.activeRoute?.distanceKm ?? 10.0;
    final coveredKm = totalKm * progress;
    final originName = liveState.originName ?? origin;
    final destName = liveState.destinationName ?? destination;

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
                  '${(liveState.speedKmh > 0 ? liveState.speedKmh : (liveState.activeRoute?.speedKmh ?? DefaultBusNetwork.defaultSpeedKmh)).toStringAsFixed(0)} KM/H',
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
            '${DefaultBusNetwork.formatPlaceName(originName)} → ${DefaultBusNetwork.formatPlaceName(destName)}',
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
                  onPressed: onEndTrip,
                  icon: Icon(MdiIcons.busStop, size: 16, color: JweTheme.accentRed),
                  label: Text('END TRIP', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.accentCyan,
                  side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onPressed: onChangeSpeed,
                icon: Icon(MdiIcons.speedometer, size: 15, color: JweTheme.accentCyan),
                label: Text('SPEED', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.accentAmber,
                  side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onPressed: onChangeDistance,
                icon: Icon(MdiIcons.mapMarkerDistance, size: 15, color: JweTheme.accentAmber),
                label: Text('DISTANCE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
