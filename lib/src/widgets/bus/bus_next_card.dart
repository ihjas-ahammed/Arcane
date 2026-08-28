import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusNextCard extends StatelessWidget {
  final Map<String, dynamic>? nextBusData;
  final String routeInfo;
  final BusRoute? activeRoute;
  final VoidCallback? onSwap;
  final VoidCallback? onOpenSchedule;

  const BusNextCard({
    super.key,
    required this.nextBusData,
    required this.routeInfo,
    this.activeRoute,
    this.onSwap,
    this.onOpenSchedule,
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

  @override
  Widget build(BuildContext context) {
    final activeColor = JweTheme.accentAmber;
    final hasBus = nextBusData != null;
    final formattedRoute = routeInfo.contains('→')
        ? routeInfo.split('→').map((p) => DefaultBusNetwork.formatPlaceName(p)).join(' → ')
        : DefaultBusNetwork.formatPlaceName(routeInfo);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: JweTheme.border.withValues(alpha: 0.8),
          width: 1.0,
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
          // Header Status Bar
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NEXT BUS DEPARTURE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: JweTheme.textMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (onSwap != null)
                GestureDetector(
                  onTap: onSwap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.swapHorizontal, size: 12, color: activeColor),
                        const SizedBox(width: 4),
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

          // Route Headline (Title Case, NOT all-caps)
          Row(
            children: [
              Icon(MdiIcons.busSide, size: 16, color: activeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formattedRoute,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
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
          if (hasBus) ...[
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.routes, size: 13, color: JweTheme.textMid),
                    const SizedBox(width: 4),
                    Text(
                      '${activeRoute?.departures.length ?? 0} RUNS CONFIGURED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: JweTheme.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (activeRoute != null && activeRoute!.distanceKm > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.mapMarkerDistance, size: 13, color: JweTheme.textMid),
                      const SizedBox(width: 4),
                      Text(
                        '~${activeRoute!.distanceKm} KM',
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
        ],
      ),
    );
  }
}
