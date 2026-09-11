import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusStopsTab extends StatelessWidget {
  final List<BusStop> stops;
  final Function(BusStop newStop) onAddStop;
  final Function(int index, BusStop updatedStop) onEditStop;
  final Function(String stopId) onDeleteStop;

  const BusStopsTab({
    super.key,
    required this.stops,
    required this.onAddStop,
    required this.onEditStop,
    required this.onDeleteStop,
  });

  void showEditStopDialog(BuildContext context, BusStop? stop) {
    final isNew = stop == null;
    final nameCtrl = TextEditingController(text: stop?.name ?? '');
    final codeCtrl = TextEditingController(text: stop?.shortCode ?? '');
    final latCtrl = TextEditingController(text: stop?.latitude.toString() ?? '11.2325');
    final lngCtrl = TextEditingController(text: stop?.longitude.toString() ?? '75.9961');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          isNew ? "ADD TRANSIT STOP" : "EDIT TRANSIT STOP",
          style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Stop Name (e.g. S.S College)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codeCtrl,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "3-Letter Code (e.g. SSC)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: latCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Latitude"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Longitude"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentAmber, foregroundColor: Colors.black),
            onPressed: () {
              final rawName = nameCtrl.text.trim();
              if (rawName.isEmpty) return;
              final name = DefaultBusNetwork.formatPlaceName(rawName);
              final code = codeCtrl.text.trim().isNotEmpty
                  ? codeCtrl.text.trim().toUpperCase()
                  : name.replaceAll(RegExp(r'[^a-zA-Z]'), '').substring(0, math.min(3, name.length)).toUpperCase();
              final lat = double.tryParse(latCtrl.text) ?? 11.2325;
              final lng = double.tryParse(lngCtrl.text) ?? 75.9961;

              if (isNew) {
                onAddStop(BusStop(
                  id: 'stop_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  shortCode: code,
                  latitude: lat,
                  longitude: lng,
                ));
              } else {
                final idx = stops.indexWhere((s) => s.id == stop.id);
                if (idx != -1) {
                  onEditStop(
                    idx,
                    stop.copyWith(
                      name: name,
                      shortCode: code,
                      latitude: lat,
                      longitude: lng,
                    ),
                  );
                }
              }
              Navigator.pop(ctx);
            },
            child: Text(isNew ? "ADD" : "UPDATE", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TRANSIT STOPS (${stops.length})",
              style: GoogleFonts.rajdhani(
                color: JweTheme.textWhite,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            TextButton.icon(
              icon: Icon(MdiIcons.plus, size: 14, color: JweTheme.accentTeal),
              label: Text("ADD STOP", style: TextStyle(color: JweTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => showEditStopDialog(context, null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...stops.map((s) => _buildStopTile(context, s)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStopTile(BuildContext context, BusStop stop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: JweTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: JweTheme.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stop.shortCode,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentAmber,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Lat: ${stop.latitude.toStringAsFixed(4)}, Lng: ${stop.longitude.toStringAsFixed(4)}",
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 16, color: JweTheme.textMuted),
            onPressed: () => showEditStopDialog(context, stop),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: JweTheme.accentRed),
            onPressed: () => onDeleteStop(stop.id),
          ),
        ],
      ),
    );
  }
}
