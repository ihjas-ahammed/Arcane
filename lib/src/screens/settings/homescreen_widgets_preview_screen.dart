import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

export 'widgets_studio/widgets_studio.dart';
import 'widgets_studio/widgets_studio.dart';

class HomescreenWidgetsPreviewScreen extends StatefulWidget {
  const HomescreenWidgetsPreviewScreen({super.key});

  @override
  State<HomescreenWidgetsPreviewScreen> createState() => _HomescreenWidgetsPreviewScreenState();
}

class _HomescreenWidgetsPreviewScreenState extends State<HomescreenWidgetsPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pushAllToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    await WidgetsStudioSync.pushAllToAndroid(provider, context: context);
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

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
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sync, size: 16, color: Colors.black),
              label: const Text(
                'SYNC ALL',
                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _isSyncing ? null : () => _pushAllToAndroid(provider),
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
              Tab(text: "BUS ROUTE"),
              Tab(text: "TASK HERO"),
              Tab(text: "DAY PLAN"),
              Tab(text: "FINANCE"),
              Tab(text: "JOURNAL"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            BusWidgetTab(provider: provider),
            TaskWidgetTab(provider: provider),
            DayPlanWidgetTab(provider: provider),
            FinanceWidgetTab(provider: provider),
            JournalWidgetTab(provider: provider),
          ],
        ),
      ),
    );
  }
}
