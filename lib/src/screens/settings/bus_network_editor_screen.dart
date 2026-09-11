import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

export 'bus_network/bus_network.dart';
import 'bus_network/bus_network.dart';


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
    final data = BusNetworkPersistence.loadData(provider);
    _stops = data.stops;
    _routes = data.routes;
  }

  Future<void> _saveAll() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await BusNetworkPersistence.saveAll(
      context: context,
      provider: provider,
      stops: _stops,
      routes: _routes,
      onSaved: () {
        if (mounted) setState(() => _hasUnsavedChanges = false);
      },
    );
  }

  void _resetToDefault() {
    BusNetworkPersistence.showResetDialog(
      context: context,
      onReset: () {
        setState(() {
          _stops = List.from(DefaultBusNetwork.stops);
          _routes = DefaultBusNetwork.getRoutes();
          _hasUnsavedChanges = true;
        });
        _saveAll();
      },
    );
  }

  void _openRouteEditor(BusRoute initialRoute) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => RouteDetailEditorScreen(
          route: initialRoute,
          stops: _stops,
          onSave: (updated) {
            setState(() {
              final idx = _routes.indexWhere((r) => r.id == updated.id);
              if (idx >= 0) {
                _routes[idx] = updated;
              } else {
                _routes.add(updated);
              }
              _hasUnsavedChanges = true;
            });
            _saveAll();
          },
        ),
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
            children: [
              Icon(MdiIcons.busStop, color: JweTheme.accentAmber, size: 20),
              const SizedBox(width: 8),
              Text(
                'TRANSIT NETWORK STUDIO',
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 17,
                ),
              ),
              if (_hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: JweTheme.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: JweTheme.accentAmber, width: 0.8),
                  ),
                  child: Text(
                    "MODIFIED",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: JweTheme.accentRed, size: 20),
              tooltip: "Reset to Built-in Defaults",
              onPressed: _resetToDefault,
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.save, size: 16, color: Colors.black),
              label: const Text('SAVE ALL', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _saveAll,
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: JweTheme.accentAmber,
            labelColor: JweTheme.accentAmber,
            unselectedLabelColor: JweTheme.textMuted,
            labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "ROUTES & TRIPS (${_routes.length})"),
              Tab(text: "STOPS (${_stops.length})"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            BusRoutesTab(
              routes: _routes,
              stops: _stops,
              onOpenRouteEditor: _openRouteEditor,
              onDeleteRoute: (routeId) {
                setState(() {
                  _routes.removeWhere((r) => r.id == routeId);
                  _hasUnsavedChanges = true;
                });
              },
              onAddRoute: (newRoute) {
                _openRouteEditor(newRoute);
              },
            ),
            BusStopsTab(
              stops: _stops,
              onAddStop: (newStop) {
                setState(() {
                  _stops.add(newStop);
                  _hasUnsavedChanges = true;
                });
              },
              onEditStop: (index, updatedStop) {
                setState(() {
                  _stops[index] = updatedStop;
                  _hasUnsavedChanges = true;
                });
              },
              onDeleteStop: (stopId) {
                setState(() {
                  _stops.removeWhere((item) => item.id == stopId);
                  _hasUnsavedChanges = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
