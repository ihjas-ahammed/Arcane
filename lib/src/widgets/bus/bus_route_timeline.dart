import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusRouteProgressTimeline extends StatefulWidget {
  final BusRoute route;
  final String? nextBusDepartureTime;
  final Function(BusSubStop subStop, String predictedEta)? onSubStopSelected;

  const BusRouteProgressTimeline({
    super.key,
    required this.route,
    this.nextBusDepartureTime,
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

    final origName = DefaultBusNetwork.formatPlaceName(
      subStops.isNotEmpty
          ? subStops.first.name
          : (widget.route.name.contains('→')
              ? widget.route.name.split('→').first.trim()
              : widget.route.originId),
    );

    final destName = DefaultBusNetwork.formatPlaceName(
      subStops.isNotEmpty
          ? subStops.last.name
          : (widget.route.name.contains('→')
              ? widget.route.name.split('→').last.trim()
              : widget.route.destinationId),
    );

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
          // Header
          Row(
            children: [
              Icon(MdiIcons.mapMarkerPath, size: 13, color: activeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subStops.isNotEmpty ? 'ROUTE & INTERMEDIATE STOPS' : 'TRANSIT CORRIDOR',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: JweTheme.textMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${widget.route.distanceKm} KM',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Two Dots + Line + Sub-stops Timeline
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

                    // Origin Major Dot (Start)
                    Positioned(
                      left: 0,
                      top: 10,
                      child: SizedBox(
                        width: 48,
                        child: _buildMajorStopDot(
                          name: origName,
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
                          name: destName,
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
                                      : (JweTheme.isLight ? Colors.white : JweTheme.bgDeep),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : activeColor,
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
                  ],
                ),
              );
            },
          ),

          // Selected Sub-Stop info chip
          if (_selectedSubStop != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: activeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(MdiIcons.flagCheckered, size: 13, color: activeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_selectedSubStop!.name} • ${_selectedSubStop!.distanceFromOriginKm} km (~${_selectedSubStop!.timeOffsetMinutes} min)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: JweTheme.textWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.nextBusDepartureTime != null)
                    Text(
                      'ETA: ${widget.route.predictSubStopArrivalTime(widget.nextBusDepartureTime!, _selectedSubStop!)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                ],
              ),
            ),
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
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isStart ? activeColor : JweTheme.bgDeep,
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
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isStart ? Colors.black : activeColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.0,
            color: JweTheme.textWhite,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
