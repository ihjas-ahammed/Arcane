import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusNetworkEditorScreen extends StatefulWidget {
  const BusNetworkEditorScreen({super.key});

  @override
  State<BusNetworkEditorScreen> createState() => _BusNetworkEditorScreenState();
}

class _BusNetworkEditorScreenState extends State<BusNetworkEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<BusStop> _stops;
  late List<BusRoute> _routes;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final settings = provider.settings;

    // Load custom stops or default
    if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
      _stops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
    } else {
      _stops = List.from(DefaultBusNetwork.stops);
    }

    // Load custom routes or default
    if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
      _routes = settings.customBusRoutesJson!.map((e) => BusRoute.fromJson(e)).toList();
    } else {
      _routes = DefaultBusNetwork.getRoutes();
    }

    // Merge any custom schedules
    if (settings.customBusSchedules != null) {
      for (int i = 0; i < _routes.length; i++) {
        final r = _routes[i];
        final originName = _stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
        final destName = _stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
        if (settings.customBusSchedules![originName] != null &&
            settings.customBusSchedules![originName]![destName] != null) {
          _routes[i] = r.copyWith(departures: settings.customBusSchedules![originName]![destName]!);
        }
      }
    }
  }

  Future<void> _saveAll() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final newSettings = AppSettings.fromJson(provider.settings.toJson());

    newSettings.customBusStopsJson = _stops.map((s) => s.toJson()).toList();
    newSettings.customBusRoutesJson = _routes.map((r) => r.toJson()).toList();

    // Map to customBusSchedules for backward compatibility
    final Map<String, Map<String, List<String>>> scheduleMap = {};
    for (final r in _routes) {
      final originName = _stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
      final destName = _stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
      if (!scheduleMap.containsKey(originName)) {
        scheduleMap[originName] = {};
      }
      scheduleMap[originName]![destName] = r.departures;
    }

    // Auto addition of two-way bidirectional data and derived routes
    DefaultBusNetwork.calculateAndFillDerivedSchedules(scheduleMap);

    // Sync back into _routes
    for (final orig in scheduleMap.keys) {
      for (final dst in scheduleMap[orig]!.keys) {
        final deps = scheduleMap[orig]![dst]!;
        final idx = _routes.indexWhere((r) {
          final rOrig = _stops.where((s) => s.id == r.originId).firstOrNull?.name ?? r.originId;
          final rDst = _stops.where((s) => s.id == r.destinationId).firstOrNull?.name ?? r.destinationId;
          return rOrig.toUpperCase() == orig.toUpperCase() && rDst.toUpperCase() == dst.toUpperCase();
        });

        if (idx >= 0) {
          _routes[idx] = _routes[idx].copyWith(departures: deps);
        } else {
          final origStop = _stops.where((s) => s.name.toUpperCase() == orig.toUpperCase()).firstOrNull;
          final dstStop = _stops.where((s) => s.name.toUpperCase() == dst.toUpperCase()).firstOrNull;
          _routes.add(
            BusRoute(
              id: 'route_${orig.toLowerCase()}_to_${dst.toLowerCase()}',
              originId: origStop?.id ?? orig,
              destinationId: dstStop?.id ?? dst,
              name: '$orig → $dst',
              distanceKm: 12.0,
              baseDurationMinutes: 25,
              subStops: const [],
              departures: deps,
            ),
          );
        }
      }
    }

    newSettings.customBusStopsJson = _stops.map((s) => s.toJson()).toList();
    newSettings.customBusRoutesJson = _routes.map((r) => r.toJson()).toList();
    newSettings.customBusSchedules = scheduleMap;

    provider.setSettings(newSettings);

    // Update location service context
    BusLocationService.instance.updateContext(stops: _stops);

    // Sync widget
    final firstRoute = _routes.firstOrNull;
    if (firstRoute != null) {
      final originName = _stops.where((s) => s.id == firstRoute.originId).firstOrNull?.name ?? firstRoute.originId;
      final destName = _stops.where((s) => s.id == firstRoute.destinationId).firstOrNull?.name ?? firstRoute.destinationId;
      final nextTime = firstRoute.departures.firstOrNull ?? '08:15 AM';
      HomeWidgetService.instance.publishBus(
        origin: originName,
        destination: destName,
        nextTime: nextTime,
        nextSubStop: '',
        isOnBus: false,
        speedKmh: 0,
        minutesRemaining: firstRoute.baseDurationMinutes,
      );
    }

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transit network & sub-stop data successfully saved!')),
      );
    }
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          "RESET TO DEFAULTS",
          style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This will reset all routes, sub-stops, stops, and departure times to their factory default values.",
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _stops = List.from(DefaultBusNetwork.stops);
                _routes = DefaultBusNetwork.getRoutes();
                _hasUnsavedChanges = true;
              });
              _saveAll();
            },
            child: const Text("RESET ALL", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: JweTheme.bgBase,
      ),
      child: Scaffold(
        backgroundColor: JweTheme.bgBase,
        appBar: AppBar(
          backgroundColor: JweTheme.bgBase,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.busStopCovered, color: JweTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _hasUnsavedChanges ? 'TRANSIT DATA EDITOR *' : 'TRANSIT DATA EDITOR',
                  style: GoogleFonts.rajdhani(
                    color: _hasUnsavedChanges ? JweTheme.accentAmber : JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.restore, color: JweTheme.accentRed, size: 20),
              tooltip: 'Reset to Defaults',
              onPressed: _resetToDefault,
            ),
            TextButton.icon(
              icon: const Icon(Icons.save, size: 15, color: Colors.black),
              label: const Text('SAVE', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _saveAll,
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: JweTheme.accentAmber,
            labelColor: JweTheme.accentAmber,
            unselectedLabelColor: JweTheme.textMuted,
            labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "ROUTES & SUB-STOPS"),
              Tab(text: "TRANSIT STOPS"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRoutesTab(),
            _buildStopsTab(),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: ROUTES & SUB-STOPS ───────────────────────────────────────────────
  Widget _buildRoutesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "CONFIGURED ROUTES (${_routes.length})",
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
              onPressed: _showAddRouteDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._routes.map((r) => _buildRouteCard(r)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRouteCard(BusRoute route) {
    final originStop = _stops.where((s) => s.id == route.originId).firstOrNull?.name ?? route.originId;
    final destStop = _stops.where((s) => s.id == route.destinationId).firstOrNull?.name ?? route.destinationId;

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
          onTap: () => _openRouteEditor(route),
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
                      onPressed: () {
                        setState(() {
                          _routes.removeWhere((r) => r.id == route.id);
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildBadge("${route.distanceKm.toStringAsFixed(1)} km", JweTheme.accentTeal),
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

  // ── ROUTE & SUB-STOPS DETAIL SCREEN ─────────────────────────────────────────
  void _openRouteEditor(BusRoute initialRoute) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _RouteDetailEditorScreen(
          route: initialRoute,
          stops: _stops,
          onSave: (updatedRoute) {
            setState(() {
              final idx = _routes.indexWhere((r) => r.id == updatedRoute.id);
              if (idx != -1) {
                _routes[idx] = updatedRoute;
              } else {
                _routes.add(updatedRoute);
              }
              _hasUnsavedChanges = true;
            });
            _saveAll();
          },
        ),
      ),
    );
  }

  void _showAddRouteDialog() {
    if (_stops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 transit stops first!')),
      );
      return;
    }

    String originId = _stops.first.id;
    String destId = _stops[1].id;
    final distCtrl = TextEditingController(text: "12.0");
    final durCtrl = TextEditingController(text: "25");

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
                  items: _stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
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
                  items: _stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
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
                final origName = _stops.where((s) => s.id == originId).firstOrNull?.name ?? originId;
                final dstName = _stops.where((s) => s.id == destId).firstOrNull?.name ?? destId;
                final dist = double.tryParse(distCtrl.text) ?? 10.0;
                final dur = int.tryParse(durCtrl.text) ?? 20;

                final newRoute = BusRoute(
                  id: 'route_${DateTime.now().millisecondsSinceEpoch}',
                  originId: originId,
                  destinationId: destId,
                  name: '$origName → $dstName',
                  distanceKm: dist,
                  baseDurationMinutes: dur,
                  subStops: const [],
                  departures: [],
                );

                Navigator.pop(ctx);
                _openRouteEditor(newRoute);
              },
              child: const Text("CREATE & CONFIGURE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: TRANSIT STOPS ───────────────────────────────────────────────────
  Widget _buildStopsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TRANSIT STOPS (${_stops.length})",
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
              onPressed: () => _showEditStopDialog(null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._stops.map((s) => _buildStopTile(s)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStopTile(BusStop stop) {
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
            onPressed: () => _showEditStopDialog(stop),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: JweTheme.accentRed),
            onPressed: () {
              setState(() {
                _stops.removeWhere((item) => item.id == stop.id);
                _hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showEditStopDialog(BusStop? stop) {
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

              setState(() {
                if (isNew) {
                  _stops.add(BusStop(
                    id: 'stop_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    shortCode: code,
                    latitude: lat,
                    longitude: lng,
                  ));
                } else {
                  final idx = _stops.indexWhere((s) => s.id == stop.id);
                  if (idx != -1) {
                    _stops[idx] = stop.copyWith(
                      name: name,
                      shortCode: code,
                      latitude: lat,
                      longitude: lng,
                    );
                  }
                }
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
            },
            child: Text(isNew ? "ADD" : "UPDATE", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE & SUB-STOPS DETAIL & REORDERABLE EDITOR
// ─────────────────────────────────────────────────────────────────────────────

class _RouteDetailEditorScreen extends StatefulWidget {
  final BusRoute route;
  final List<BusStop> stops;
  final Function(BusRoute) onSave;

  const _RouteDetailEditorScreen({
    required this.route,
    required this.stops,
    required this.onSave,
  });

  @override
  State<_RouteDetailEditorScreen> createState() => _RouteDetailEditorScreenState();
}

class _RouteDetailEditorScreenState extends State<_RouteDetailEditorScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _durCtrl;
  late List<BusSubStop> _subStops;
  late List<String> _departures;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.route.name);
    _distCtrl = TextEditingController(text: widget.route.distanceKm.toString());
    _durCtrl = TextEditingController(text: widget.route.baseDurationMinutes.toString());
    _subStops = List.from(widget.route.subStops);
    _departures = List.from(widget.route.departures);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _distCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  void _saveRoute() {
    final dist = double.tryParse(_distCtrl.text) ?? widget.route.distanceKm;
    final dur = int.tryParse(_durCtrl.text) ?? widget.route.baseDurationMinutes;

    final updated = widget.route.copyWith(
      name: _nameCtrl.text.trim(),
      distanceKm: dist,
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
              decoration: const InputDecoration(labelText: "Route Name"),
            ),
            const SizedBox(height: 8),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _durCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: const InputDecoration(labelText: "Duration (mins)"),
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
