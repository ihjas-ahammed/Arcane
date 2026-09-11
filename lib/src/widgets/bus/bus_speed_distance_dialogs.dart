import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Prompts user to input route distance in km
Future<double?> showAskDistanceDialog(
  BuildContext context, {
  required String origin,
  required String destination,
  double? currentDistance,
}) async {
  final controller = TextEditingController(
    text: (currentDistance != null && currentDistance > 0)
        ? currentDistance.toStringAsFixed(1)
        : '',
  );

  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Row(
        children: [
          Icon(MdiIcons.mapMarkerDistance, color: JweTheme.accentAmber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "ENTER ROUTE DISTANCE",
              style: GoogleFonts.chakraPetch(
                color: JweTheme.accentAmber,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Route distance between ${DefaultBusNetwork.formatPlaceName(origin)} and ${DefaultBusNetwork.formatPlaceName(destination)} is needed to calculate travel progress.",
            style: GoogleFonts.rajdhani(
              color: JweTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: "DISTANCE (KM)",
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              hintText: "e.g. 10.5",
              hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5)),
              suffixText: "km",
              suffixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: JweTheme.bgBase,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: JweTheme.onAccent,
          ),
          onPressed: () {
            final val = double.tryParse(controller.text.trim());
            if (val != null && val > 0) {
              Navigator.pop(ctx, val);
            }
          },
          child: Text("CONFIRM & BOARD", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

/// Prompts user to input assumed route transit speed in km/h
Future<double?> showAskSpeedDialog(
  BuildContext context, {
  required String origin,
  required String destination,
  double? currentSpeed,
}) async {
  final controller = TextEditingController(
    text: (currentSpeed != null && currentSpeed > 0)
        ? currentSpeed.toStringAsFixed(0)
        : DefaultBusNetwork.defaultSpeedKmh.toStringAsFixed(0),
  );

  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Row(
        children: [
          Icon(MdiIcons.speedometer, color: JweTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "ROUTE TRANSIT SPEED",
              style: GoogleFonts.chakraPetch(
                color: JweTheme.accentCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Set transit speed in km/h for ${DefaultBusNetwork.formatPlaceName(origin)} → ${DefaultBusNetwork.formatPlaceName(destination)}. Default is 50 km/h.",
            style: GoogleFonts.rajdhani(
              color: JweTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: "SPEED (KM/H)",
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              hintText: "e.g. 50",
              hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5)),
              suffixText: "km/h",
              suffixStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: JweTheme.bgBase,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentCyan,
            foregroundColor: JweTheme.onAccent,
          ),
          onPressed: () {
            final val = double.tryParse(controller.text.trim());
            if (val != null && val > 0) {
              Navigator.pop(ctx, val);
            }
          },
          child: Text("CONFIRM SPEED", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
