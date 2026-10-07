import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/bus_schedule_screen.dart';
import 'package:missions/src/screens/database_editor_screen.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/screens/reflections_archive_screen.dart';
import 'package:missions/src/screens/schedule/scheduled_reminders_screen.dart';
import 'package:missions/src/screens/journaling/quick_therapy_screen.dart';
import 'package:missions/src/screens/journaling/gratitude_list_screen.dart';
import 'package:missions/src/screens/journaling/someday_list_screen.dart';
import 'package:missions/src/screens/journaling/people_info_screen.dart';
import 'package:missions/src/screens/journaling/advanced_tools_screen.dart';
import 'package:missions/src/screens/journaling/archived_reports_screen.dart';
import 'package:missions/src/screens/skills/skills_screen.dart';
import 'package:missions/src/screens/settings/habit_control_screen.dart';
import 'package:missions/src/screens/settings/homescreen_widgets_preview_screen.dart';
import 'package:missions/src/screens/settings/bus_network_editor_screen.dart';
import 'package:missions/src/screens/settings/sop_list_screen.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/widgets/settings/sections/launcher_settings_section.dart';
import 'package:missions/src/widgets/views/settings_view.dart';
import 'package:missions/src/screens/trading/realtime_trading_screen.dart';
import 'package:missions/src/screens/tools/input_reply_screen.dart';
import 'package:missions/src/screens/tools/devices_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// One entry in the main menu: an icon, a title, a one-line description of
/// what it actually does today, an accent color and where it navigates.
class _MenuEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color Function() color;
  final WidgetBuilder builder;

  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
  });
}

class _MenuGroup {
  final String title;
  final List<_MenuEntry> entries;
  const _MenuGroup({required this.title, required this.entries});
}

class MoreScreen extends StatelessWidget {
  final bool isEmbed;
  const MoreScreen({super.key, this.isEmbed = false});

  static Widget _settingsScaffold(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text("SETTINGS",
              style: GoogleFonts.rajdhani(
                  color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          backgroundColor: JweTheme.bgBase,
          iconTheme: IconThemeData(color: JweTheme.accentCyan),
        ),
        backgroundColor: JweTheme.bgBase,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const SettingsView(),
          ),
        ),
      );

  static Widget _launcherScaffold(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text("HOME LAUNCHER",
              style: GoogleFonts.rajdhani(
                  color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          backgroundColor: JweTheme.bgBase,
          iconTheme: IconThemeData(color: JweTheme.accentCyan),
        ),
        backgroundColor: JweTheme.bgBase,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const LauncherSettingsSection(),
              ),
            ),
          ),
        ),
      );

  List<_MenuGroup> _groups(BuildContext context) => [
        _MenuGroup(title: "DAILY OPS", entries: [
          _MenuEntry(
            icon: MdiIcons.busClock,
            title: "Bus Time",
            subtitle: "Schedule: S.S College - Areekode - Edavannappara",
            color: () => JweTheme.accentCyan,
            builder: (_) => const BusScheduleScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.bellCogOutline,
            title: "Scheduled Reminders",
            subtitle: "View, edit or cancel every reminder & per-task alert",
            color: () => JweTheme.accentAmber,
            builder: (_) => const ScheduledRemindersScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.brain,
            title: "Behavioral Override",
            subtitle: "Habit control & dopamine regulation loops",
            color: () => JweTheme.accentWarn,
            builder: (_) => const HabitControlScreen(),
          ),
        ]),
        _MenuGroup(title: "JOURNAL & MIND", entries: [
          _MenuEntry(
            icon: MdiIcons.robotHappyOutline,
            title: "Nora AI Assistant",
            subtitle: "Chat, voice command & persona control for your tactical AI",
            color: () => AppTheme.fhAccentPurple,
            builder: (_) => const NoraAiScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.medicalBag,
            title: "Emergency Therapy",
            subtitle: "Quick psychological triage and action plan",
            color: () => JweTheme.accentRed,
            builder: (_) => const QuickTherapyScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.heartPulse,
            title: "Gratitude Log",
            subtitle: "Track people, resources, and things you appreciate",
            color: () => JweTheme.accentCyan,
            builder: (_) => const GratitudeListScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.lightbulbOutline,
            title: "Someday / Maybe",
            subtitle: "Zero-friction idea capture and parking lot",
            color: () => JweTheme.accentAmber,
            builder: (_) => const SomedayListScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.accountGroupOutline,
            title: "People & Relationships",
            subtitle: "Tracked contacts, relationship notes & social intel",
            color: () => JweTheme.accentCyan,
            builder: (_) => const PeopleInfoScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.trophyOutline,
            title: "Skills & Progression",
            subtitle: "Skill matrix & mastery tracking",
            color: () => JweTheme.accentAmber,
            builder: (_) => const SkillsScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.bookOpenPageVariantOutline,
            title: "Reflections Archive",
            subtitle: "Browse and search every daily reflection log",
            color: () => JweTheme.accentCyan,
            builder: (_) => const ReflectionsArchiveScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.archiveOutline,
            title: "Archived Reports",
            subtitle: "Past weekly reviews & monthly briefings; regenerate on demand",
            color: () => JweTheme.accentAmber,
            builder: (_) => const ArchivedReportsScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.forumOutline,
            title: "Advanced Protocols",
            subtitle: "Situation & comms simulators, plus quick links to Skills, People & Trading",
            color: () => JweTheme.accentWarn,
            builder: (_) => const AdvancedToolsScreen(),
          ),
        ]),
        _MenuGroup(title: "TOOLS", entries: [
          _MenuEntry(
            icon: MdiIcons.clipboardListOutline,
            title: "Standard Operational Procedures (SOP)",
            subtitle: "Actionable procedures & execution logs for recurring situations",
            color: () => JweTheme.accentAmber,
            builder: (_) => const SopListScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.chartLine,
            title: "Realtime Trading",
            subtitle: "Live crypto paper-trading simulator & execution lab",
            color: () => JweTheme.accentCyan,
            builder: (_) => const RealtimeTradingScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.widgetsOutline,
            title: "Widgets Studio",
            subtitle: "Preview, customize & sync Android home-screen widgets",
            color: () => JweTheme.accentTeal,
            builder: (_) => const HomescreenWidgetsPreviewScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.recordCircleOutline,
            title: "Input Reply",
            subtitle: "Record & replay whole-device interactions, gestures & macros",
            color: () => JweTheme.accentCyan,
            builder: (_) => const InputReplyScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.watchVariant,
            title: "Devices",
            subtitle: "Smartwatch & Bluetooth data, watch app selection and keep-alive",
            color: () => JweTheme.accentTeal,
            builder: (_) => const DevicesScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.busStopCovered,
            title: "Transit Network & Sub-Stops",
            subtitle: "Manage routes, sub-stops, distances & timetables",
            color: () => JweTheme.accentCyan,
            builder: (_) => const BusNetworkEditorScreen(),
          ),
        ]),
        if (LauncherNative.isSupported)
          _MenuGroup(title: "DEVICE & LAUNCHER", entries: [
            _MenuEntry(
              icon: MdiIcons.homeVariantOutline,
              title: "Home Launcher",
              subtitle: "Set Arcane as home app, MIUI takeover & customization",
              color: () => JweTheme.accentTeal,
              builder: _launcherScaffold,
            ),
          ]),
        _MenuGroup(title: "SYSTEM", entries: [
          _MenuEntry(
            icon: MdiIcons.databaseEdit,
            title: "Database Editor",
            subtitle: "Manual edits & JSON Export/Import",
            color: () => JweTheme.accentCyan,
            builder: (_) => const DatabaseEditorScreen(),
          ),
          _MenuEntry(
            icon: MdiIcons.cogOutline,
            title: "System Settings",
            subtitle: "Account, launcher, notifications, AI, updates & recovery",
            color: () => JweTheme.accentCyan,
            builder: _settingsScaffold,
          ),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final groups = _groups(context);

    final bodyContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            for (final group in groups) ...[
              Text(group.title,
                  style: TextStyle(
                      color: JweTheme.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              for (final entry in group.entries) _buildMenuTile(context, entry: entry),
              const SizedBox(height: 24),
            ],
            const _VersionFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (isEmbed) {
      return SafeArea(child: bodyContent);
    }

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("SYSTEM & UTILITIES",
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 2.0, color: JweTheme.accentCyan)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: IconThemeData(color: JweTheme.accentCyan),
      ),
      body: SafeArea(
        child: bodyContent,
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required _MenuEntry entry}) {
    final effectiveColor = entry.color();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(left: BorderSide(color: effectiveColor, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: entry.builder));
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
              ),
              child: Icon(entry.icon, color: effectiveColor),
            ),
            title: Text(entry.title.toUpperCase(),
                style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: JweTheme.textWhite, fontSize: 16)),
            subtitle: Text(entry.subtitle, style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            trailing: Icon(MdiIcons.chevronRight, color: JweTheme.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Shows the installed app version + build number, read asynchronously so the
/// menu never blocks on it; renders nothing (not an error) while pending.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final label = info == null ? "ARCANE" : "ARCANE v${info.version} (Build #${info.buildNumber})";
        return Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }
}
