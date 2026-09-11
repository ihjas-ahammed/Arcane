import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import '../widgets_studio_controls.dart';
import '../widgets_studio_models.dart';
import '../widgets_studio_resolvers.dart';
import '../widgets_studio_sync.dart';

class JournalWidgetTab extends StatefulWidget {
  final AppProvider provider;

  const JournalWidgetTab({
    super.key,
    required this.provider,
  });

  @override
  State<JournalWidgetTab> createState() => _JournalWidgetTabState();
}

class _JournalWidgetTabState extends State<JournalWidgetTab> {
  bool _overrideJournal = false;
  int _journalCount = 3;
  bool _journalWake = true;
  bool _journalMorn = true;
  bool _journalAft = false;
  bool _journalEve = false;
  bool _journalNight = false;
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final live = WidgetsStudioResolvers.resolveLiveJournal(widget.provider);
    final count = _overrideJournal ? _journalCount : live.count;
    final wake = _overrideJournal ? _journalWake : live.wake;
    final morn = _overrideJournal ? _journalMorn : live.morn;
    final aft = _overrideJournal ? _journalAft : live.aft;
    final eve = _overrideJournal ? _journalEve : live.eve;
    final night = _overrideJournal ? _journalNight : live.night;

    final currentData = JournalWidgetData(
      count: count,
      wake: wake,
      morn: morn,
      aft: aft,
      eve: eve,
      night: night,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideJournal,
            child: Center(
              child: JournalHomeWidget(
                count: count,
                wake: wake,
                morn: morn,
                aft: aft,
                eve: eve,
                night: night,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StudioActionButtons(
            syncLabel: "SYNC JOURNAL WIDGET",
            isSyncing: _isSyncing,
            onSync: () async {
              setState(() => _isSyncing = true);
              await WidgetsStudioSync.pushJournalToAndroid(currentData, context: context);
              if (mounted) setState(() => _isSyncing = false);
            },
            onPin: () => WidgetsStudioSync.pinWidget(
              context,
              HomeWidgetService.instance.requestPinJournal,
              "Journal Widget",
            ),
          ),
          const SizedBox(height: 20),
          StudioTestControlsAccordion(
            isOverriding: _overrideJournal,
            onToggleOverride: (val) {
              setState(() {
                _overrideJournal = val;
                if (val) {
                  _journalCount = live.count;
                  _journalWake = live.wake;
                  _journalMorn = live.morn;
                  _journalAft = live.aft;
                  _journalEve = live.eve;
                  _journalNight = live.night;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudioTextField(
                  label: "Entry Count",
                  initialValue: _journalCount.toString(),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) setState(() => _journalCount = parsed);
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text("WAKE Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalWake,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalWake = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("MORN Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalMorn,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalMorn = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("AFT Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalAft,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalAft = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("EVE Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalEve,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalEve = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("NIGHT Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalNight,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalNight = v ?? false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
