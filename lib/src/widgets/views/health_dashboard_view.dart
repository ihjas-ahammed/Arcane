import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/health/health_combined_chart.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

class HealthDashboardView extends StatefulWidget {
  const HealthDashboardView({super.key});

  @override
  State<HealthDashboardView> createState() => _HealthDashboardViewState();
}

class _HealthDashboardViewState extends State<HealthDashboardView> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  // Food input controllers
  final _foodNameController = TextEditingController();
  final _foodAmountController = TextEditingController();
  bool _isAnalyzingFood = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _foodNameController.dispose();
    _foodAmountController.dispose();
    super.dispose();
  }

  // --- Sleep Logging Dialog ---
  void _showSleepDialog(BuildContext context, AppProvider provider, String dateStr) {
    final startController = TextEditingController(text: "23:00");
    final endController = TextEditingController(text: "07:00");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        scrollable: true,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.accentCyan, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'LOG SLEEP RECORD',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'BED TIME (HH:MM)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endController,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'WAKE TIME (HH:MM)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final startParts = startController.text.split(':');
              final endParts = endController.text.split(':');
              if (startParts.length == 2 && endParts.length == 2) {
                final now = DateTime.tryParse(dateStr) ?? DateTime.now();
                final sh = int.tryParse(startParts[0]) ?? 23;
                final sm = int.tryParse(startParts[1]) ?? 0;
                final eh = int.tryParse(endParts[0]) ?? 7;
                final em = int.tryParse(endParts[1]) ?? 0;

                final start = DateTime(now.year, now.month, now.day, sh, sm);
                var end = DateTime(now.year, now.month, now.day, eh, em);
                if (end.isBefore(start)) end = end.add(const Duration(days: 1));

                provider.addSleepLog(dateStr, SleepLog(
                  id: const Uuid().v4(),
                  startTime: start,
                  endTime: end,
                ));
                Navigator.pop(ctx);
              }
            },
            child: Text('LOG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Activity Logging Dialog ---
  void _showActivityDialog(BuildContext context, AppProvider provider, String dateStr) {
    final distanceController = TextEditingController(text: "0.0");
    final workoutController = TextEditingController(text: "0");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        scrollable: true,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.accentTeal, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'LOG PHYSICAL ACTIVITY',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'WALK DISTANCE (KM)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentTeal)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: workoutController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'WORKOUT DURATION (MINUTES)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentTeal)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentTeal,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final dist = double.tryParse(distanceController.text) ?? 0.0;
              final mins = int.tryParse(workoutController.text) ?? 0;
              if (dist > 0 || mins > 0) {
                provider.addActivityLog(dateStr, ActivityLog(
                  id: const Uuid().v4(),
                  walkDistanceKm: dist,
                  workoutMinutes: mins,
                  timestamp: DateTime.now(),
                ));
                Navigator.pop(ctx);
              }
            },
            child: Text('LOG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Energy Logging Dialog ---
  void _showEnergyDialog(BuildContext context, AppProvider provider, String dateStr) {
    int level = 5;
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: JweTheme.panel,
          scrollable: true,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber, width: 2),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'LOG ENERGY LEVEL',
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENERGY STATE: $level / 10',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
               ),
               Slider(
                 value: level.toDouble(),
                 min: 1,
                 max: 10,
                 divisions: 9,
                 activeColor: JweTheme.accentAmber,
                 inactiveColor: JweTheme.border,
                 onChanged: (val) {
                   setDialogState(() => level = val.round());
                 },
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: noteController,
                 style: const TextStyle(color: JweTheme.textWhite),
                 decoration: InputDecoration(
                   labelText: 'STATUS NOTE (OPTIONAL)',
                   labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                   enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                   focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                 ),
               ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ABORT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                provider.addEnergyLog(dateStr, EnergyLog(
                  id: const Uuid().v4(),
                  level: level,
                  timestamp: DateTime.now(),
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: Text('LOG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Meal AI Analyzer Function ---
  Future<void> _handleFoodAILog(AppProvider provider, String dateStr) async {
    final food = _foodNameController.text.trim();
    final amount = _foodAmountController.text.trim();

    if (food.isEmpty || amount.isEmpty) return;

    setState(() => _isAnalyzingFood = true);
    try {
      final foodItem = await provider.analyzeFoodWithAI(food, amount);
      provider.addFoodItem(foodItem);

      final mealLog = MealLog(
        id: const Uuid().v4(),
        foodItemId: foodItem.id,
        timestamp: DateTime.now(),
      );
      provider.addMealLog(dateStr, mealLog);

      _foodNameController.clear();
      _foodAmountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged "$food ($amount)" successfully!'),
            backgroundColor: JweTheme.accentTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing food: $e'),
            backgroundColor: JweTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingFood = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final log = provider.getDailyHealthLog(dateStr);
    final accentColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentCyan;

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 16.0 : (0 + MediaQuery.of(context).padding.bottom);

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Date Selector header (Tactical Logbook Border design)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: HudPanel(
                clip: HudClip.br,
                accent: accentColor,
                brackets: true,
                allBrackets: false,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: accentColor),
                      onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate).toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: accentColor),
                      onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: JweTheme.panel,
              child: TabBar(
                controller: _tabController,
                indicatorColor: accentColor,
                labelColor: accentColor,
                dividerColor: accentColor.withValues(alpha: 0.15),
                unselectedLabelColor: JweTheme.textMuted,
                labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                tabs: const [
                  Tab(text: "LOGS", icon: Icon(MdiIcons.heartPulse, size: 18)),
                  Tab(text: "NUTRITION", icon: Icon(MdiIcons.silverwareForkKnife, size: 18)),
                  Tab(text: "STATS", icon: Icon(MdiIcons.chartDonut, size: 18)),
                ],
              ),
            ),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogsTab(context, provider, log, dateStr, accentColor, bottomPadding),
                  _buildNutritionTab(context, provider, log, dateStr, accentColor, bottomPadding),
                  _buildStatsTab(context, provider, log, accentColor, bottomPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: LOGS
  // ==========================================
  Widget _buildLogsTab(BuildContext context, AppProvider provider, DailyHealthLog log, String dateStr, Color accent, double bottomPadding) {
    final totalSleepMinutes = log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes);
    final workoutMinutes = log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);
    final distanceKm = log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 7-Day Trend Chart
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HEALTH TREND ANALYSIS (7-DAY)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: HealthCombinedChart(provider: provider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hydration Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'HYDRATION TELEMETRY',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: JweTheme.textMuted),
                      onPressed: () => provider.updateWater(dateStr, (log.waterGlasses - 1).clamp(0, 99)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "${log.waterGlasses}",
                      style: GoogleFonts.rajdhani(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: JweTheme.textWhite,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.add, color: JweTheme.accentCyan),
                      onPressed: () => provider.updateWater(dateStr, log.waterGlasses + 1),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    "GLASSES COMPLETED (${log.waterGlasses * 250} ml / 2000 ml target)",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      color: JweTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sleep Metrics Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SLEEP MONITORING',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "${(totalSleepMinutes / 60).floor()}H ${totalSleepMinutes % 60}M",
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (log.sleepLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "NO SLEEP SESSIONS LOGGED TODAY.",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...log.sleepLogs.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              Icon(MdiIcons.bedOutline, size: 14, color: JweTheme.accentCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${DateFormat('HH:mm').format(s.startTime)} — ${DateFormat('HH:mm').format(s.endTime)} (${(s.durationMinutes / 60).floor()}h ${s.durationMinutes % 60}m)",
                                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => provider.deleteSleepLog(dateStr, s.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('RECORD SLEEP SESSION'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentCyan,
                    side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  onPressed: () => _showSleepDialog(context, provider, dateStr),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Activity logs
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentTeal,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PHYSICAL TELEMETRY',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "${workoutMinutes}M / ${distanceKm.toStringAsFixed(1)}KM",
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.accentTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (log.activityLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "NO PHYSICAL ACTIVITY SESSIONS LOGGED TODAY.",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...log.activityLogs.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              Icon(MdiIcons.walk, size: 14, color: JweTheme.accentTeal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${a.walkDistanceKm} km walk / ${a.workoutMinutes} mins active",
                                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => provider.deleteActivityLog(dateStr, a.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('RECORD ACTIVITY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentTeal,
                    side: BorderSide(color: JweTheme.accentTeal.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  onPressed: () => _showActivityDialog(context, provider, dateStr),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Energy State Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentAmber,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DAILY ENERGY LEVEL',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (log.energyLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "NO ENERGY ENTRIES LOGGED TODAY.",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...log.energyLogs.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              Icon(MdiIcons.batteryCharging, size: 14, color: JweTheme.accentAmber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${e.level}/10 energy level logged ${e.note != null ? '(${e.note})' : ''}",
                                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => provider.deleteEnergyLog(dateStr, e.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('RECORD ENERGY LOG'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentAmber,
                    side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  onPressed: () => _showEnergyDialog(context, provider, dateStr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: NUTRITION
  // ==========================================
  Widget _buildNutritionTab(BuildContext context, AppProvider provider, DailyHealthLog log, String dateStr, Color accent, double bottomPadding) {
    // Resolve foods for meal logs
    final mealsWithFood = log.meals.map((meal) {
      final food = provider.foodItems.firstWhereOrNull((f) => f.id == meal.foodItemId);
      return MapEntry(meal, food);
    }).toList();

    final totalCalories = mealsWithFood.fold<int>(0, (sum, entry) => sum + (entry.value?.calories ?? 0));
    final totalProtein = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.protein ?? 0.0));
    final totalCarbs = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.carbs ?? 0.0));
    final totalFat = mealsWithFood.fold<double>(0.0, (sum, entry) => sum + (entry.value?.fat ?? 0.0));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Food Form Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentAmber,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LOG MEAL PROTOCOL (AI ASSISTED)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _foodNameController,
                  style: const TextStyle(color: JweTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'FOOD CONSUMED (e.g. Grilled Chicken)',
                    labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _foodAmountController,
                  style: const TextStyle(color: JweTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'APPROXIMATE PORTION AMOUNT (e.g. 150 grams / 1 cup)',
                    labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JweTheme.accentAmber,
                    foregroundColor: Colors.black,
                    shape: const BeveledRectangleBorder(),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: _isAnalyzingFood ? null : () => _handleFoodAILog(provider, dateStr),
                  icon: _isAnalyzingFood
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Icon(MdiIcons.brain, size: 16),
                  label: Text(
                    _isAnalyzingFood ? 'ANALYZING PROFILE...' : 'ENGAGE AI NUTRITION ANALYSIS',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total Summary Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacrosColumn("CALORIES", "$totalCalories kcal", JweTheme.textWhite),
                _buildMacrosColumn("PROTEIN", "${totalProtein.toStringAsFixed(1)}g", JweTheme.accentTeal),
                _buildMacrosColumn("CARBS", "${totalCarbs.toStringAsFixed(1)}g", JweTheme.accentCyan),
                _buildMacrosColumn("FAT", "${totalFat.toStringAsFixed(1)}g", JweTheme.accentAmber),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meal List
          Row(
            children: [
              Container(width: 4, height: 12, color: JweTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                'LOGGED MEAL PROTOCOLS',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (mealsWithFood.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'NO MEALS RECORDED FOR THIS PROTOCOL CYCLE.',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              ),
            )
          else
            ...mealsWithFood.map((entry) {
              final meal = entry.key;
              final food = entry.value;

              if (food == null) return const SizedBox.shrink();

              final hasWarnings = food.warnings != null && food.warnings!.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: HudPanel(
                  clip: HudClip.br,
                  accent: hasWarnings ? JweTheme.accentRed : JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: JweTheme.border.withValues(alpha: 0.2))),
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.silverwareForkKnife, color: JweTheme.accentTeal, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                food.name.toUpperCase(),
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(meal.timestamp),
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => provider.deleteMealLog(dateStr, meal.id),
                            ),
                          ],
                        ),
                      ),
                      // Card Body
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ENERGY: ${food.calories} kcal', style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('P: ${food.protein}g  |  C: ${food.carbs}g  |  F: ${food.fat}g', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5)),
                              ],
                            ),
                            if (food.description != null && food.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                food.description!,
                                style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11.5),
                              ),
                            ],
                            if (food.benefits != null && food.benefits!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: food.benefits!.map((b) => HudChip(label: b, tone: HudTone.teal)).toList(),
                              ),
                            ],
                            if (food.warnings != null && food.warnings!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: JweTheme.accentRed.withValues(alpha: 0.08),
                                  border: Border(left: BorderSide(color: JweTheme.accentRed, width: 2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: food.warnings!.map((w) => Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: JweTheme.accentRed, size: 12),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              w,
                                              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 9.5),
                                            ),
                                          ),
                                        ],
                                      )).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMacrosColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.chakraPetch(color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: STATS & SCIENCE RECOMMENDATIONS
  // ==========================================
  Widget _buildStatsTab(BuildContext context, AppProvider provider, DailyHealthLog currentLog, Color accent, double bottomPadding) {
    // Generate averages over last 30 days
    final now = DateTime.now();
    int activeDaysCount = 0;
    double totalWater = 0;
    double totalSleepHours = 0;
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalWalkKm = 0;
    int totalWorkoutMins = 0;

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final log = provider.healthLogs[dateStr];
      if (log != null) {
        activeDaysCount++;
        totalWater += log.waterGlasses;
        totalSleepHours += log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes) / 60.0;
        totalWalkKm += log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);
        totalWorkoutMins += log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);

        // Averages of food
        final mealsWithFood = log.meals.map((meal) {
          return provider.foodItems.firstWhereOrNull((f) => f.id == meal.foodItemId);
        }).whereType<FoodItem>().toList();

        totalCalories += mealsWithFood.fold(0, (sum, item) => sum + item.calories);
        totalProtein += mealsWithFood.fold(0.0, (sum, item) => sum + item.protein);
        totalCarbs += mealsWithFood.fold(0.0, (sum, item) => sum + item.carbs);
        totalFat += mealsWithFood.fold(0.0, (sum, item) => sum + item.fat);
      }
    }

    final days = activeDaysCount == 0 ? 1 : activeDaysCount;
    final avgWater = totalWater / days;
    final avgSleep = totalSleepHours / days;
    final avgCalories = totalCalories / days;
    final avgProtein = totalProtein / days;
    final avgCarbs = totalCarbs / days;
    final avgFat = totalFat / days;
    final avgWalkKm = totalWalkKm / days;
    final avgWorkoutMins = totalWorkoutMins / days;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Row(
            children: [
              Container(width: 4, height: 12, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                'HEALTH TELEMETRY & LONGEVITY STATS (30-DAY AVG)',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Overview macro telemetry
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CALORIC ENERGY DEPLOYMENT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    Text('${avgCalories.round()} / 2200 kcal avg', style: GoogleFonts.chakraPetch(color: JweTheme.accentCyan, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                HudProgressBar(value: (avgCalories / 2200 * 100).clamp(0.0, 100.0), tone: HudTone.cyan),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PROTEIN SYNTHESIS TARGET', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    Text('${avgProtein.toStringAsFixed(1)} / 120g avg', style: GoogleFonts.chakraPetch(color: JweTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                HudProgressBar(value: (avgProtein / 120 * 100).clamp(0.0, 100.0), tone: HudTone.teal),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CARBOHYDRATE THRESHOLD', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    Text('${avgCarbs.toStringAsFixed(1)} / 250g avg', style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                HudProgressBar(value: (avgCarbs / 250 * 100).clamp(0.0, 100.0), tone: HudTone.neutral),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LIPID / FAT DEPLOYMENT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    Text('${avgFat.toStringAsFixed(1)} / 70g avg', style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                HudProgressBar(value: (avgFat / 70 * 100).clamp(0.0, 100.0), tone: HudTone.amber),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sleep & hydration averages
          Row(
            children: [
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentCyan,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "SLEEP AVERAGE",
                    value: avgSleep.toStringAsFixed(1),
                    unit: "HRS",
                    sub: "Walker limit: 8.0h",
                    tone: HudTone.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentCyan,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "WATER AVERAGE",
                    value: avgWater.toStringAsFixed(1),
                    unit: "GLS",
                    sub: "Attia target: 8.0",
                    tone: HudTone.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exercise Averages
          Row(
            children: [
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "DAILY ACTIVE DURATION",
                    value: "${avgWorkoutMins.round()}",
                    unit: "MINS",
                    sub: "Goal: 30 min",
                    tone: HudTone.teal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "DAILY LOCOMOTION",
                    value: avgWalkKm.toStringAsFixed(1),
                    unit: "KM",
                    sub: "Goal: 5.0 km",
                    tone: HudTone.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Science-Based Longevity Recommendations (Peter Attia, Matthew Walker, James Clear)
          HudPanel(
            clip: HudClip.both,
            accent: JweTheme.accentAmber,
            allBrackets: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.bookOpenVariant, color: JweTheme.accentAmber, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'LONGEVITY CLINICAL DIRECTIVES',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDirectiveItem(
                  "CARDIORESPIRATORY PERFORMANCE (Peter Attia, 'Outlive')",
                  "Zone 2 training represents the foundation of mitochondrial health. Strive for 150 minutes per week at a pace where you can carry a conversation but prefer not to. VO2 Max is the single strongest predictor of lifespan.",
                ),
                const SizedBox(height: 10),
                _buildDirectiveItem(
                  "REST PROTOCOL & SLEEP ARCHITECTURE (Matthew Walker, 'Why We Sleep')",
                  "Aim for 7.5 to 8 hours of sleep per night. Sleep is an active state essential for glymphatic clearance (brain waste removal) and memory consolidation. Maintain a strict wake-up time.",
                ),
                const SizedBox(height: 10),
                _buildDirectiveItem(
                  "PROTEIN LEVERAGE HYPOTHESIS (Raubenheimer & Simpson)",
                  "To maintain muscle mass and offset age-related sarcopenia, target 1.6 to 2.2 grams of protein per kilogram of body weight. Space protein intake evenly across meals.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectiveItem(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}
