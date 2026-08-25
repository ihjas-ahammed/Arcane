import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';

class HomescreenWidgetsPreviewScreen extends StatefulWidget {
  const HomescreenWidgetsPreviewScreen({super.key});

  @override
  State<HomescreenWidgetsPreviewScreen> createState() => _HomescreenWidgetsPreviewScreenState();
}

class _HomescreenWidgetsPreviewScreenState extends State<HomescreenWidgetsPreviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. Bus Widget Test State
  String _busOrigin = "S.S College";
  String _busDest = "EDAVANNAPPARA";
  String _busNextTime = "08:15 AM";
  String _busSubStop = "CHEEKKODE";
  bool _busIsOnBus = true;
  int _busSpeedKmh = 32;
  int _busMinsRemaining = 14;

  // 2. Task Widget Test State
  String _taskTitle = "DESIGN NEURAL ARCHITECTURE";
  String _taskSubtitle = "PHOENIX PROTOCOL // DEEP WORK";
  String _taskCapacity = "2h40 / 4h30";
  double _taskProgress = 0.65;
  bool _taskIsRunning = true;
  bool _taskIsPhoenix = true;
  final bool _taskIsCheckpoint = false;
  final int _taskAccumulatedSeconds = 1800;

  // 3. Finance Widget Test State
  double _financeBalance = 24500.0;
  double _financeSpentToday = 450.0;
  double _financeMonthSpend = 4200.0;
  int _financeBudgetPct = 42;

  // 4. Journal Widget Test State
  int _journalCount = 3;
  bool _journalWake = true;
  bool _journalMorn = true;
  bool _journalAft = false;
  bool _journalEve = false;
  bool _journalNight = false;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pushBusToAndroid() async {
    setState(() => _isSyncing = true);
    await HomeWidgetService.instance.publishBus(
      origin: _busOrigin,
      destination: _busDest,
      nextTime: _busNextTime,
      nextSubStop: _busSubStop,
      isOnBus: _busIsOnBus,
      speedKmh: _busSpeedKmh,
      minutesRemaining: _busMinsRemaining,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushTaskToAndroid() async {
    setState(() => _isSyncing = true);
    await HomeWidgetService.instance.publishTask(
      hasTask: true,
      title: _taskTitle,
      subtitle: _taskSubtitle,
      isRunning: _taskIsRunning,
      isCheckpoint: _taskIsCheckpoint,
      accumulatedSeconds: _taskAccumulatedSeconds,
      progress: _taskProgress,
      isPhoenix: _taskIsPhoenix,
      capacity: _taskCapacity,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushFinanceToAndroid() async {
    setState(() => _isSyncing = true);
    await HomeWidgetService.instance.publishFinance(
      balance: _financeBalance,
      todaySpend: _financeSpentToday,
      monthSpend: _financeMonthSpend,
      budgetPct: _financeBudgetPct,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finance Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushJournalToAndroid() async {
    setState(() => _isSyncing = true);
    await HomeWidgetService.instance.publishJournal(
      count: _journalCount,
      wake: _journalWake,
      morn: _journalMorn,
      aft: _journalAft,
      eve: _journalEve,
      night: _journalNight,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushAllToAndroid() async {
    setState(() => _isSyncing = true);
    await _pushBusToAndroid();
    await _pushTaskToAndroid();
    await _pushFinanceToAndroid();
    await _pushJournalToAndroid();
    if (mounted) {
      setState(() => _isSyncing = false);
    }
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
              Icon(MdiIcons.widgetsOutline, color: JweTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'WIDGETS STUDIO',
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
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
            TextButton.icon(
              icon: _isSyncing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.sync, size: 16, color: Colors.black),
              label: const Text('SYNC ALL', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _isSyncing ? null : _pushAllToAndroid,
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: JweTheme.accentAmber,
            labelColor: JweTheme.accentAmber,
            unselectedLabelColor: JweTheme.textMuted,
            labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "1. BUS TRANSIT"),
              Tab(text: "2. ACTIVE TASK"),
              Tab(text: "3. FINANCE"),
              Tab(text: "4. JOURNAL"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBusWidgetTab(),
            _buildTaskWidgetTab(),
            _buildFinanceWidgetTab(),
            _buildJournalWidgetTab(),
          ],
        ),
      ),
    );
  }

  // ── BUS WIDGET TAB ──────────────────────────────────────────────────────────
  Widget _buildBusWidgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            child: Center(
              child: BusHomeWidget(
                origin: _busOrigin,
                destination: _busDest,
                nextTime: _busNextTime,
                nextSubStop: _busSubStop,
                isOnBus: _busIsOnBus,
                speedKmh: _busSpeedKmh,
                minutesRemaining: _busMinsRemaining,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncButton(
            label: "SYNC BUS WIDGET TO HOMESCREEN",
            onPressed: _pushBusToAndroid,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("INTERACTIVE TEST CONTROLS"),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text("Is On Bus (Transit Active)", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
            subtitle: Text("Toggles live transit beacon & sub-stop ETA", style: TextStyle(color: JweTheme.textMuted, fontSize: 10)),
            value: _busIsOnBus,
            activeTrackColor: JweTheme.accentTeal,
            onChanged: (val) => setState(() => _busIsOnBus = val),
          ),
          const SizedBox(height: 8),
          _buildTextField("Origin Stop", _busOrigin, (val) => setState(() => _busOrigin = val)),
          const SizedBox(height: 8),
          _buildTextField("Destination Stop", _busDest, (val) => setState(() => _busDest = val)),
          const SizedBox(height: 8),
          _buildTextField("Next Sub-Stop", _busSubStop, (val) => setState(() => _busSubStop = val)),
          const SizedBox(height: 8),
          _buildTextField("Next Bus Time", _busNextTime, (val) => setState(() => _busNextTime = val)),
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
    );
  }

  // ── TASK WIDGET TAB ─────────────────────────────────────────────────────────
  Widget _buildTaskWidgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            child: Center(
              child: RunningTaskHomeWidget(
                hasTask: true,
                title: _taskTitle,
                subtitle: _taskSubtitle,
                isRunning: _taskIsRunning,
                isCheckpoint: _taskIsCheckpoint,
                accumulatedSeconds: _taskAccumulatedSeconds,
                progress: _taskProgress,
                isPhoenix: _taskIsPhoenix,
                capacity: _taskCapacity,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncButton(
            label: "SYNC TASK WIDGET TO HOMESCREEN",
            onPressed: _pushTaskToAndroid,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("INTERACTIVE TEST CONTROLS"),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text("Is Active / Running", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
            value: _taskIsRunning,
            activeTrackColor: JweTheme.accentAmber,
            onChanged: (val) => setState(() => _taskIsRunning = val),
          ),
          SwitchListTile(
            title: Text("Is Phoenix Mission", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
            value: _taskIsPhoenix,
            activeTrackColor: JweTheme.accentRed,
            onChanged: (val) => setState(() => _taskIsPhoenix = val),
          ),
          const SizedBox(height: 8),
          _buildTextField("Mission Title", _taskTitle, (val) => setState(() => _taskTitle = val)),
          const SizedBox(height: 8),
          _buildTextField("Subtitle / Checkpoint", _taskSubtitle, (val) => setState(() => _taskSubtitle = val)),
          const SizedBox(height: 8),
          _buildTextField("Capacity String", _taskCapacity, (val) => setState(() => _taskCapacity = val)),
          const SizedBox(height: 12),
          Text("Progress: ${(_taskProgress * 100).toStringAsFixed(0)}%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
          Slider(
            value: _taskProgress,
            min: 0.0,
            max: 1.0,
            activeColor: JweTheme.accentAmber,
            onChanged: (v) => setState(() => _taskProgress = v),
          ),
        ],
      ),
    );
  }

  // ── FINANCE WIDGET TAB ──────────────────────────────────────────────────────
  Widget _buildFinanceWidgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            child: Center(
              child: FinanceHomeWidget(
                balance: _financeBalance,
                todaySpend: _financeSpentToday,
                monthSpend: _financeMonthSpend,
                budgetPct: _financeBudgetPct,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncButton(
            label: "SYNC FINANCE WIDGET TO HOMESCREEN",
            onPressed: _pushFinanceToAndroid,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("INTERACTIVE TEST CONTROLS"),
          const SizedBox(height: 12),
          _buildTextField("Liquid Balance", _financeBalance.toString(), (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) setState(() => _financeBalance = parsed);
          }),
          const SizedBox(height: 8),
          _buildTextField("Today Spend", _financeSpentToday.toString(), (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) setState(() => _financeSpentToday = parsed);
          }),
          const SizedBox(height: 8),
          _buildTextField("Month Spend", _financeMonthSpend.toString(), (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) setState(() => _financeMonthSpend = parsed);
          }),
          const SizedBox(height: 12),
          Text("Budget %: $_financeBudgetPct%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
          Slider(
            value: _financeBudgetPct.toDouble(),
            min: 0,
            max: 100,
            activeColor: JweTheme.accentTeal,
            onChanged: (v) => setState(() => _financeBudgetPct = v.round()),
          ),
        ],
      ),
    );
  }

  // ── JOURNAL WIDGET TAB ──────────────────────────────────────────────────────
  Widget _buildJournalWidgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            child: Center(
              child: JournalHomeWidget(
                count: _journalCount,
                wake: _journalWake,
                morn: _journalMorn,
                aft: _journalAft,
                eve: _journalEve,
                night: _journalNight,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncButton(
            label: "SYNC JOURNAL WIDGET TO HOMESCREEN",
            onPressed: _pushJournalToAndroid,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("INTERACTIVE TEST CONTROLS"),
          const SizedBox(height: 12),
          _buildTextField("Entry Count", _journalCount.toString(), (val) {
            final parsed = int.tryParse(val);
            if (parsed != null) setState(() => _journalCount = parsed);
          }),
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
    );
  }

  // ── SHARED HELPERS ──────────────────────────────────────────────────────────
  Widget _buildPreviewContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone, size: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: JweTheme.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSyncButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        icon: _isSyncing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(MdiIcons.upload, size: 16),
        label: Text(
          label,
          style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: JweTheme.accentAmber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _isSyncing ? null : onPressed,
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.rajdhani(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: JweTheme.textWhite,
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue,
      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: JweTheme.isLight ? JweTheme.bgDeep : Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.accentAmber)),
      ),
      onChanged: onChanged,
    );
  }
}
