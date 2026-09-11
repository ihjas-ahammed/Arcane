import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class RouteDetailEditorScreen extends StatefulWidget {
  final BusRoute route;
  final List<BusStop> stops;
  final Function(BusRoute) onSave;

  const RouteDetailEditorScreen({
    super.key,
    required this.route,
    required this.stops,
    required this.onSave,
  });

  @override
  State<RouteDetailEditorScreen> createState() => _RouteDetailEditorScreenState();
}

class _RouteDetailEditorScreenState extends State<RouteDetailEditorScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _speedCtrl;
  late TextEditingController _durCtrl;
  late List<BusSubStop> _subStops;
  late List<String> _departures;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.route.name);
    _distCtrl = TextEditingController(text: widget.route.distanceKm.toString());
    _speedCtrl = TextEditingController(text: widget.route.speedKmh.toStringAsFixed(0));
    _durCtrl = TextEditingController(text: widget.route.baseDurationMinutes.toString());
    _subStops = List.from(widget.route.subStops);
    _departures = List.from(widget.route.departures);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _distCtrl.dispose();
    _speedCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  void _saveRoute() {
    final dist = double.tryParse(_distCtrl.text) ?? widget.route.distanceKm;
    final speed = double.tryParse(_speedCtrl.text) ?? widget.route.speedKmh;
    final dur = int.tryParse(_durCtrl.text) ?? widget.route.baseDurationMinutes;

    final updated = widget.route.copyWith(
      name: _nameCtrl.text.trim(),
      distanceKm: dist,
      speedKmh: speed > 0 ? speed : DefaultBusNetwork.defaultSpeedKmh,
      baseDurationMinutes: dur,
      subStops: _subStops,
      departures: _departures,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  void _showAddOrEditSubStop(BusSubStop? subStop, int? index) {
    final isNew = subStop == null;
    final nameCtrl = TextEditingController(text: subStop?.name ?? '');
    final distCtrl = TextEditingController(text: subStop?.distanceFromOriginKm.toString() ?? '0.0');
    final offsetCtrl = TextEditingController(text: subStop?.timeOffsetMinutes.toString() ?? '0');
    final latCtrl = TextEditingController(text: subStop?.latitude.toString() ?? '11.2325');
    final lngCtrl = TextEditingController(text: subStop?.longitude.toString() ?? '75.9961');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          isNew ? "ADD SUB-STOP" : "EDIT SUB-STOP",
          style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Sub-Stop Name (e.g. Poovathikkal)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: distCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Distance from Origin (km)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: offsetCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                decoration: const InputDecoration(labelText: "Time Offset from Start (minutes)"),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final dist = double.tryParse(distCtrl.text) ?? 0.0;
              final offset = int.tryParse(offsetCtrl.text) ?? 0;
              final lat = double.tryParse(latCtrl.text) ?? 11.2325;
              final lng = double.tryParse(lngCtrl.text) ?? 75.9961;

              final newSub = BusSubStop(
                name: name,
                latitude: lat,
                longitude: lng,
                distanceFromOriginKm: dist,
                timeOffsetMinutes: offset,
              );

              setState(() {
                if (isNew) {
                  _subStops.add(newSub);
                } else if (index != null) {
                  _subStops[index] = newSub;
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(isNew ? "ADD" : "UPDATE", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddDepartureDialog(String? initialTime, int? index) {
    TimeOfDay tod = TimeOfDay.now();
    if (initialTime != null) {
      try {
        final parsed = DateFormat("hh:mm a").parse(initialTime);
        tod = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } catch (_) {}
    }

    showTimePicker(
      context: context,
      initialTime: tod,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentAmber, surface: JweTheme.panel),
        ),
        child: child!,
      ),
    ).then((picked) {
      if (picked != null) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        final formatted = DateFormat("hh:mm a").format(dt);

        setState(() {
          if (index != null) {
            _departures[index] = formatted;
          } else {
            _departures.add(formatted);
          }
          _sortDepartures();
        });
      }
    });
  }

  void _sortDepartures() {
    _departures.sort((a, b) {
      try {
        final da = DateFormat("hh:mm a").parse(a);
        final db = DateFormat("hh:mm a").parse(b);
        return (da.hour * 60 + da.minute).compareTo(db.hour * 60 + db.minute);
      } catch (_) {
        return 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: JweTheme.bgBase),
      child: Scaffold(
        backgroundColor: JweTheme.bgBase,
        appBar: AppBar(
          backgroundColor: JweTheme.bgBase,
          elevation: 0,
          title: Text(
            "EDIT ROUTE & SUB-STOPS",
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.check, size: 16, color: Colors.black),
              label: const Text('APPLY', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _saveRoute,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Route metadata
            Text("ROUTE METADATA", style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
              decoration: const InputDecoration(labelText: "Route Name (e.g. S.S College → Edavannappara)"),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _distCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: const InputDecoration(labelText: "Distance (km)"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _speedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: const InputDecoration(labelText: "Speed (km/h)"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _durCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: const InputDecoration(labelText: "Duration (m)"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SUB-STOPS LIST (REORDERABLE)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "INTERMEDIATE SUB-STOPS (${_subStops.length})",
                  style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                TextButton.icon(
                  icon: Icon(MdiIcons.plus, size: 14, color: JweTheme.accentCyan),
                  label: Text("ADD SUB-STOP", style: TextStyle(color: JweTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddOrEditSubStop(null, null),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Drag to reorder sequence. Progress bars and live ETAs follow this exact order.",
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 10),

            if (_subStops.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.border),
                ),
                child: Text(
                  "No sub-stops defined yet. Tap '+ ADD SUB-STOP' to add intermediate checkpoints.",
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subStops.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _subStops.removeAt(oldIndex);
                    _subStops.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, idx) {
                  final s = _subStops[idx];
                  return Container(
                    key: ValueKey("substop_${s.name}_$idx"),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: JweTheme.panel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: JweTheme.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${idx + 1}.",
                          style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                "${s.distanceFromOriginKm.toStringAsFixed(1)} km  •  +${s.timeOffsetMinutes}m offset",
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(MdiIcons.pencilOutline, size: 14, color: JweTheme.textMuted),
                          onPressed: () => _showAddOrEditSubStop(s, idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 14, color: JweTheme.accentRed),
                          onPressed: () => setState(() => _subStops.removeAt(idx)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.drag_handle, size: 16, color: JweTheme.textMuted),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // TIMETABLE DEPARTURES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "DEPARTURE TIMETABLE (${_departures.length})",
                  style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(MdiIcons.sortClockAscendingOutline, size: 16, color: JweTheme.accentTeal),
                      tooltip: "Sort Times",
                      onPressed: () => setState(() => _sortDepartures()),
                    ),
                    TextButton.icon(
                      icon: Icon(MdiIcons.plus, size: 14, color: JweTheme.accentAmber),
                      label: Text("ADD TIME", style: TextStyle(color: JweTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddDepartureDialog(null, null),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _departures.asMap().entries.map((entry) {
                final idx = entry.key;
                final time = entry.value;
                return GestureDetector(
                  onTap: () => _showAddDepartureDialog(time, idx),
                  child: Chip(
                    backgroundColor: JweTheme.panel,
                    side: BorderSide(color: JweTheme.border),
                    label: Text(time, style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11)),
                    deleteIcon: Icon(Icons.close, size: 12, color: JweTheme.accentRed),
                    onDeleted: () => setState(() => _departures.removeAt(idx)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
