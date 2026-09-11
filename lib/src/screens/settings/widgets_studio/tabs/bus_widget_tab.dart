import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_models.dart';
import '../widgets_studio_resolvers.dart';
import '../widgets_studio_sync.dart';

class BusWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const BusWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<BusWidgetTab> createState() => _BusWidgetTabState();
}

class _BusWidgetTabState extends State<BusWidgetTab> {
  bool _overrideBus = false;
  String _busOrigin = "S.S College";
  String _busDest = "Edavannappara";
  String _busNextTime = "08:15 AM";
  String _busSubStop = "Cheekkode";
  bool _busIsOnBus = true;
  int _busSpeedKmh = 32;
  int _busMinsRemaining = 14;
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final live = WidgetsStudioResolvers.resolveLiveBus(widget.provider);
    final origin = _overrideBus ? _busOrigin : live.origin;
    final destination = _overrideBus ? _busDest : live.destination;
    final nextTime = _overrideBus ? _busNextTime : live.nextTime;
    final nextSubStop = _overrideBus ? _busSubStop : live.nextSubStop;
    final isOnBus = _overrideBus ? _busIsOnBus : live.isOnBus;
    final speed = _overrideBus ? _busSpeedKmh : live.speedKmh;
    final minsRemaining = _overrideBus ? _busMinsRemaining : live.minutesRemaining;

    final currentData = BusWidgetData(
      origin: origin,
      destination: destination,
      nextTime: nextTime,
      nextSubStop: nextSubStop,
      isOnBus: isOnBus,
      speedKmh: speed,
      minutesRemaining: minsRemaining,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideBus,
            child: Center(
              child: BusHomeWidget(
                origin: origin,
                destination: destination,
                nextTime: nextTime,
                nextSubStop: nextSubStop,
                isOnBus: isOnBus,
                speedKmh: speed,
                minutesRemaining: minsRemaining,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StudioActionButtons(
            syncLabel: "SYNC BUS WIDGET",
            isSyncing: _isSyncing,
            onSync: () async {
              setState(() => _isSyncing = true);
              await WidgetsStudioSync.pushBusToAndroid(currentData, context: context);
              if (mounted) setState(() => _isSyncing = false);
            },
            onPin: () => WidgetsStudioSync.pinWidget(
              context,
              HomeWidgetService.instance.requestPinBus,
              "Live Bus Widget",
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideBus,
            onToggleOverride: (val) {
              setState(() {
                _overrideBus = val;
                if (val) {
                  _busOrigin = live.origin;
                  _busDest = live.destination;
                  _busNextTime = live.nextTime;
                  _busSubStop = live.nextSubStop;
                  _busIsOnBus = live.isOnBus;
                  _busSpeedKmh = live.speedKmh;
                  _busMinsRemaining = live.minutesRemaining;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text("Is On Bus (Transit Active)", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  subtitle: Text("Toggles live transit beacon & sub-stop ETA", style: TextStyle(color: JweTheme.textMuted, fontSize: 10)),
                  value: _busIsOnBus,
                  activeTrackColor: JweTheme.accentTeal,
                  onChanged: (val) => setState(() => _busIsOnBus = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Origin Stop",
                  initialValue: _busOrigin,
                  onChanged: (val) => setState(() => _busOrigin = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Destination Stop",
                  initialValue: _busDest,
                  onChanged: (val) => setState(() => _busDest = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Next Sub-Stop",
                  initialValue: _busSubStop,
                  onChanged: (val) => setState(() => _busSubStop = val),
                ),
                const SizedBox(height: 8),
                StudioTextField(
                  label: "Next Bus Time",
                  initialValue: _busNextTime,
                  onChanged: (val) => setState(() => _busNextTime = val),
                ),
                const SizedBox(height: 12),
                Text("Speed: $_busSpeedKmh km/h", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _busSpeedKmh.toDouble(),
                  min: 0,
                  max: 80,
                  divisions: 16,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _busSpeedKmh = v.round()),
                ),
                Text("Minutes Remaining: $_busMinsRemaining min", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _busMinsRemaining.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  activeColor: JweTheme.accentAmber,
                  onChanged: (v) => setState(() => _busMinsRemaining = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
