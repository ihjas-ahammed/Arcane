import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusRoutesTab extends StatelessWidget {
  final List<BusRoute> routes;
  final List<BusStop> stops;
  final Function(BusRoute route) onOpenRouteEditor;
  final Function(String routeId) onDeleteRoute;
  final Function(BusRoute newRoute) onAddRoute;

  const BusRoutesTab({
    super.key,
    required this.routes,
    required this.stops,
    required this.onOpenRouteEditor,
    required this.onDeleteRoute,
    required this.onAddRoute,
  });

  void showAddRouteDialog(BuildContext context) {
    if (stops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 transit stops first!')),
      );
      return;
    }

    String originId = stops.first.id;
    String destId = stops[1].id;
    final distCtrl = TextEditingController(text: "12.0");
    final speedCtrl = TextEditingController(text: DefaultBusNetwork.defaultSpeedKmh.toStringAsFixed(0));
    final durCtrl = TextEditingController(text: "14");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: JweTheme.panel,
          title: Text(
            "CREATE NEW ROUTE",
            style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: originId,
                  dropdownColor: JweTheme.panel,
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                  decoration: const InputDecoration(labelText: "Origin Stop"),
                  items: stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => originId = val);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: destId,
                  dropdownColor: JweTheme.panel,
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                  decoration: const InputDecoration(labelText: "Destination Stop"),
                  items: stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => destId = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: distCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                  decoration: const InputDecoration(labelText: "Total Distance (km)"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: speedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                  decoration: const InputDecoration(labelText: "Route Speed (km/h)"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: durCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                  decoration: const InputDecoration(labelText: "Base Duration (mins)"),
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
                final origName = stops.where((s) => s.id == originId).firstOrNull?.name ?? originId;
                final dstName = stops.where((s) => s.id == destId).firstOrNull?.name ?? destId;
                final dist = double.tryParse(distCtrl.text) ?? 10.0;
                final speed = double.tryParse(speedCtrl.text) ?? DefaultBusNetwork.defaultSpeedKmh;
                final dur = int.tryParse(durCtrl.text) ?? (dist / speed * 60).round();

                final newRoute = BusRoute(
                  id: 'route_${DateTime.now().millisecondsSinceEpoch}',
                  originId: originId,
                  destinationId: destId,
                  name: '$origName → $dstName',
                  distanceKm: dist,
                  speedKmh: speed,
                  baseDurationMinutes: dur,
                  subStops: const [],
                  departures: [],
                );

                Navigator.pop(ctx);
                onAddRoute(newRoute);
              },
              child: const Text("CREATE & CONFIGURE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
              "CONFIGURED ROUTES (${routes.length})",
              style: GoogleFonts.rajdhani(
                color: JweTheme.textWhite,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            TextButton.icon(
              icon: Icon(MdiIcons.plus, size: 14, color: JweTheme.accentTeal),
              label: Text("ADD ROUTE", style: TextStyle(color: JweTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => showAddRouteDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...routes.map((r) => _buildRouteCard(r)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRouteCard(BusRoute route) {
    final originStop = stops.where((s) => s.id == route.originId).firstOrNull?.name ?? route.originId;
    final destStop = stops.where((s) => s.id == route.destinationId).firstOrNull?.name ?? route.destinationId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onOpenRouteEditor(route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        route.name.isNotEmpty ? route.name : "$originStop → $destStop",
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: JweTheme.accentRed),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => onDeleteRoute(route.id),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildBadge("${route.distanceKm.toStringAsFixed(1)} km", JweTheme.accentTeal),
                    const SizedBox(width: 8),
                    _buildBadge("${route.speedKmh.toStringAsFixed(0)} km/h", JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    _buildBadge("${route.baseDurationMinutes} mins", JweTheme.textMuted),
                    const SizedBox(width: 8),
                    _buildBadge("${route.subStops.length} sub-stops", route.subStops.isEmpty ? JweTheme.accentRed : JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    _buildBadge("${route.departures.length} trips", JweTheme.accentAmber),
                  ],
                ),
                if (route.subStops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Sub-stops: ${route.subStops.map((s) => s.name).join(' → ')}",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
