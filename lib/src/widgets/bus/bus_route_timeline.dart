import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusRouteProgressTimeline extends StatefulWidget {
  final BusRoute route;
  final String? nextBusDepartureTime;
  final BusTransitLiveState? liveState;
  final Function(BusSubStop subStop, String predictedEta)? onSubStopSelected;

  const BusRouteProgressTimeline({
    super.key,
    required this.route,
    this.nextBusDepartureTime,
    this.liveState,
    this.onSubStopSelected,
  });

  @override
  State<BusRouteProgressTimeline> createState() => _BusRouteProgressTimelineState();
}

class _BusRouteProgressTimelineState extends State<BusRouteProgressTimeline> {
  BusSubStop? _selectedSubStop;

  @override
  Widget build(BuildContext context) {
    final subStops = widget.route.subStops;
    final totalKm = widget.route.distanceKm > 0 ? widget.route.distanceKm : 1.0;
    final activeColor = JweTheme.accentAmber;
    final live = widget.liveState;
    final isOnBus = live?.isOnBus ?? false;
    final progress = live?.progressAlongRoute ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with live status
          Row(
            children: [
              Icon(
                isOnBus ? MdiIcons.busAlert : MdiIcons.mapMarkerPath,
                size: 13,
                color: isOnBus ? JweTheme.accentTeal : activeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOnBus ? 'LIVE TRANSIT CORRIDOR' : 'ROUTE & SUB-STOPS RADAR',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isOnBus ? JweTheme.accentTeal : JweTheme.textMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (live?.isTracking == true) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isOnBus ? JweTheme.accentTeal : activeColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnBus ? JweTheme.accentTeal : activeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnBus ? '${live?.speedKmh.toStringAsFixed(0)} KM/H' : 'RADAR LOCK',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: isOnBus ? JweTheme.accentTeal : activeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Two Dots + Line + Sub-stops interactive Timeline
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              const paddingX = 24.0;
              final trackWidth = w - (paddingX * 2);

              return SizedBox(
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background track line
                    Positioned(
                      left: paddingX,
                      right: paddingX,
                      top: 18,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: JweTheme.isLight ? const Color(0xFFDDD7CC) : Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Active progress fill if on bus
                    if (isOnBus && progress > 0)
                      Positioned(
                        left: paddingX,
                        top: 18,
                        child: Container(
                          width: trackWidth * progress.clamp(0.0, 1.0),
                          height: 3,
                          decoration: BoxDecoration(
                            color: JweTheme.accentTeal,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: JweTheme.accentTeal.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Origin Major Dot (Start)
                    Positioned(
                      left: 0,
                      top: 10,
                      child: SizedBox(
                        width: 48,
                        child: _buildMajorStopDot(
                          name: subStops.isNotEmpty ? subStops.first.name : 'Origin',
                          isStart: true,
                          activeColor: activeColor,
                        ),
                      ),
                    ),

                    // Destination Major Dot (End)
                    Positioned(
                      right: 0,
                      top: 10,
                      child: SizedBox(
                        width: 48,
                        child: _buildMajorStopDot(
                          name: subStops.isNotEmpty ? subStops.last.name : 'Dest',
                          isStart: false,
                          activeColor: activeColor,
                        ),
                      ),
                    ),

                    // Intermediate Sub-Stop Dots
                    if (subStops.length > 2)
                      ...subStops.sublist(1, subStops.length - 1).map((sub) {
                        final ratio = (sub.distanceFromOriginKm / totalKm).clamp(0.08, 0.92);
                        final xPos = paddingX + (trackWidth * ratio) - 7;
                        final isSelected = _selectedSubStop?.name == sub.name;
                        final isCurrentOrPassed = isOnBus && (ratio <= progress);

                        return Positioned(
                          left: xPos,
                          top: 13,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _selectedSubStop = sub);
                              final eta = widget.nextBusDepartureTime != null
                                  ? widget.route.predictSubStopArrivalTime(widget.nextBusDepartureTime!, sub)
                                  : '--:--';
                              widget.onSubStopSelected?.call(sub, eta);
                            },
                            child: Tooltip(
                              message: '${sub.name} (~${sub.timeOffsetMinutes}m)',
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? activeColor
                                      : (isCurrentOrPassed
                                          ? JweTheme.accentTeal
                                          : (JweTheme.isLight ? Colors.white : JweTheme.bgDeep)),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : (isCurrentOrPassed ? JweTheme.accentTeal : activeColor),
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: activeColor.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    // Live GPS Pulse beacon if tracking
                    if (isOnBus && progress > 0)
                      Positioned(
                        left: paddingX + (trackWidth * progress.clamp(0.0, 1.0)) - 8,
                        top: 11,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: JweTheme.accentTeal,
                            boxShadow: [
                              BoxShadow(
                                color: JweTheme.accentTeal.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.directions_bus, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Sub-stop Selected Prediction Card
          if (_selectedSubStop != null) ...[
            const SizedBox(height: 6),
            _buildSubStopPredictionCard(_selectedSubStop!, activeColor),
          ],
        ],
      ),
    );
  }

  Widget _buildMajorStopDot({
    required String name,
    required bool isStart,
    required Color activeColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isStart ? activeColor : JweTheme.panel,
            border: Border.all(color: activeColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isStart ? JweTheme.onAccent : activeColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name.length > 7 ? '${name.substring(0, 6)}..' : name,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: JweTheme.textMid,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSubStopPredictionCard(BusSubStop sub, Color activeColor) {
    final nextDep = widget.nextBusDepartureTime;
    final eta = nextDep != null
        ? widget.route.predictSubStopArrivalTime(nextDep, sub)
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: activeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.mapMarkerRadius, size: 13, color: activeColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sub.name.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: JweTheme.textWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.distanceFromOriginKm} km • ~${sub.timeOffsetMinutes}m transit',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.0,
                    color: JweTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ETA $eta',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
              Text(
                'NEXT RUN',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.0,
                  letterSpacing: 0.8,
                  color: JweTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
