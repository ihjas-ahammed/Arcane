import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Hub component for selecting transit origin and destination stops
class BusStopSelectorHub extends StatelessWidget {
  final List<BusStop> allStops;
  final String origin;
  final String destination;
  final ValueChanged<String> onSelectOrigin;
  final ValueChanged<String> onSelectDestination;
  final VoidCallback onAddPlace;
  final ValueChanged<BusStop> onManageStop;

  const BusStopSelectorHub({
    super.key,
    required this.allStops,
    required this.origin,
    required this.destination,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onAddPlace,
    required this.onManageStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ROUTE CONFIGURATION",
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: onAddPlace,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.plus, size: 13, color: JweTheme.accentAmber),
                      const SizedBox(width: 3),
                      Text(
                        "+ ADD PLACE",
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStopHorizontalList(
            label: "ORIGIN STATION (DEPARTURE)",
            selectedValue: origin,
            activeColor: JweTheme.accentAmber,
            onSelect: onSelectOrigin,
          ),
          const SizedBox(height: 10),
          _buildStopHorizontalList(
            label: "DESTINATION STATION (ARRIVAL)",
            selectedValue: destination,
            activeColor: JweTheme.accentCyan,
            onSelect: onSelectDestination,
          ),
        ],
      ),
    );
  }

  Widget _buildStopHorizontalList({
    required String label,
    required String selectedValue,
    required Color activeColor,
    required Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9.0,
            letterSpacing: 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allStops.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == allStops.length) {
                return GestureDetector(
                  onTap: onAddPlace,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.08),
                      border: Border.all(
                        color: JweTheme.accentAmber.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.plus, size: 12, color: JweTheme.accentAmber),
                        const SizedBox(width: 4),
                        Text(
                          "ADD PLACE",
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final stop = allStops[index];
              final isSelected = stop.name.toLowerCase() == selectedValue.toLowerCase();

              return GestureDetector(
                onTap: () => onSelect(stop.name),
                onLongPress: () => onManageStop(stop),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? activeColor : JweTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stop.shortCode,
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? activeColor : JweTheme.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DefaultBusNetwork.formatPlaceName(stop.name),
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? JweTheme.textWhite : JweTheme.textMid,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
