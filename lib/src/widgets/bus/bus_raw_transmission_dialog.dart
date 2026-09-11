import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Bulk Raw Transmission Editor for editing all departures as text
Future<void> showRawTransmissionDialog(
  BuildContext context, {
  required String origin,
  required String destination,
  required List<String> departures,
  required ValueChanged<List<String>> onSave,
  required int Function(String) timeToMinutes,
}) async {
  final controller = TextEditingController(text: departures.join(", "));

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Text(
        "EDIT TRANSMISSION DATA",
        style: GoogleFonts.chakraPetch(
          color: JweTheme.accentAmber,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ROUTE: ${DefaultBusNetwork.formatPlaceName(origin)} → ${DefaultBusNetwork.formatPlaceName(destination)}",
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Paste or edit departure times separated by commas or newlines (e.g. 08:00 AM, 08:15 AM, 01:30 PM). Changes apply specifically to this route direction.",
              style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                hintText: "06:30 AM, 07:15 AM, 08:00 AM...",
                hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: JweTheme.onAccent,
          ),
          onPressed: () {
            final raw = controller.text;
            final parsedList = <String>[];

            final tokens = raw.split(RegExp(r'[, \n\r]+'));
            for (final token in tokens) {
              final cleaned = token.trim();
              if (cleaned.isEmpty) continue;
              try {
                final dt = DateFormat("hh:mm a").parse(cleaned);
                parsedList.add(DateFormat("hh:mm a").format(dt));
              } catch (_) {
                try {
                  final dt = DateFormat("HH:mm").parse(cleaned);
                  parsedList.add(DateFormat("hh:mm a").format(dt));
                } catch (_) {}
              }
            }

            if (parsedList.isNotEmpty) {
              parsedList.sort((a, b) => timeToMinutes(a).compareTo(timeToMinutes(b)));
              final distinctList = parsedList.toSet().toList();
              Navigator.pop(ctx);
              onSave(distinctList);
            } else {
              Navigator.pop(ctx);
            }
          },
          child: Text("SAVE & BROADCAST", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
