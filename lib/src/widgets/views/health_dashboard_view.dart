import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/health/health_logs_tab.dart';
import 'package:missions/src/widgets/health/health_nutrition_tab.dart';
import 'package:missions/src/widgets/health/health_stats_tab.dart';

export 'package:missions/src/widgets/health/add_activity_dialog.dart';
export 'package:missions/src/widgets/health/add_sleep_dialog.dart';
export 'package:missions/src/widgets/health/circadian_advisor_card.dart';
export 'package:missions/src/widgets/health/health_logs_tab.dart';
export 'package:missions/src/widgets/health/health_nutrition_tab.dart';
export 'package:missions/src/widgets/health/health_stats_tab.dart';

class HealthDashboardView extends StatefulWidget {
  const HealthDashboardView({super.key});

  @override
  State<HealthDashboardView> createState() => _HealthDashboardViewState();
}

class _HealthDashboardViewState extends State<HealthDashboardView> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final log = provider.healthLogs[dateStr] ?? DailyHealthLog(dateStr: dateStr);
    final accentColor = JweTheme.accentTeal;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Date Selector Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: JweTheme.panel,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: JweTheme.border),
                  color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                ),
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
                indicatorWeight: 2.0,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: const [
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.heartPulse, size: 14),
                        SizedBox(width: 6),
                        Text(
                          "LOGS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.silverwareForkKnife, size: 14),
                        SizedBox(width: 6),
                        Text(
                          "NUTRITION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.chartDonut, size: 14),
                        SizedBox(width: 6),
                        Text(
                          "STATS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  HealthLogsTab(
                    provider: provider,
                    log: log,
                    dateStr: dateStr,
                    selectedDate: _selectedDate,
                    accent: accentColor,
                    bottomPadding: bottomPadding,
                  ),
                  HealthNutritionTab(
                    provider: provider,
                    log: log,
                    dateStr: dateStr,
                    accent: accentColor,
                    bottomPadding: bottomPadding,
                  ),
                  HealthStatsTab(
                    provider: provider,
                    currentLog: log,
                    accent: accentColor,
                    bottomPadding: bottomPadding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
