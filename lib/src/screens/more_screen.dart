import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/screens/bus_schedule_screen.dart';
import 'package:arcane/src/screens/database_editor_screen.dart';
import 'package:arcane/src/screens/journaling/quick_therapy_screen.dart';
import 'package:arcane/src/screens/journaling/gratitude_list_screen.dart';
import 'package:arcane/src/screens/journaling/someday_list_screen.dart';
import 'package:arcane/src/screens/settings/habit_control_screen.dart';
import 'package:arcane/src/widgets/views/settings_view.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("SYSTEM & UTILITIES", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 2.0, color: JweTheme.accentCyan)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: const IconThemeData(color: JweTheme.accentCyan),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("UTILITIES & SYSTEM",
                    style: TextStyle(
                        color: JweTheme.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),

                _buildMenuTile(context,
                    icon: MdiIcons.medicalBag,
                    title: "Emergency Therapy",
                    subtitle: "Quick psychological triage and action plan",
                    colorOverride: JweTheme.accentRed,
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const QuickTherapyScreen()));
                }),
                
                _buildMenuTile(context,
                    icon: MdiIcons.heartPulse,
                    title: "Gratitude Log",
                    subtitle: "Track people, resources, and things you appreciate",
                    colorOverride: JweTheme.accentCyan,
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GratitudeListScreen()));
                }),

                _buildMenuTile(context,
                    icon: MdiIcons.lightbulbOutline,
                    title: "Someday / Maybe",
                    subtitle: "Zero-friction idea capture and parking lot",
                    colorOverride: JweTheme.accentAmber,
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SomedayListScreen()));
                }),

                _buildMenuTile(context,
                    icon: MdiIcons.busClock,
                    title: "Bus Time",
                    subtitle: "Schedule: S.S College - Areekode - Edavannappara",
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BusScheduleScreen()));
                }),

                _buildMenuTile(context,
                    icon: MdiIcons.databaseEdit,
                    title: "Database Editor",
                    subtitle: "Manual edits & JSON Export/Import", onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DatabaseEditorScreen()));
                }),

                const SizedBox(height: 32),
                const Text("CONFIGURATION",
                    style: TextStyle(
                        color: JweTheme.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),

                _buildMenuTile(context,
                    icon: MdiIcons.brain,
                    title: "Behavioral Override",
                    subtitle: "Habit control & dopamine regulation",
                    colorOverride: JweTheme.accentAmber,
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HabitControlScreen()));
                }),

                _buildMenuTile(context,
                    icon: MdiIcons.cogOutline,
                    title: "System Settings",
                    subtitle: "App preferences, AI config, and recovery",
                    onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: Text("SETTINGS", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                                  backgroundColor: JweTheme.bgBase,
                                  iconTheme: const IconThemeData(color: JweTheme.accentCyan)
                                ),
                                backgroundColor: JweTheme.bgBase,
                                body: Center(
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 800),
                                        child: const SettingsView())),
                              )));
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? colorOverride,
  }) {
    final effectiveColor = colorOverride ?? JweTheme.accentCyan;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(left: BorderSide(color: effectiveColor, width: 3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.1),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: effectiveColor.withOpacity(0.3))
          ),
          child: Icon(icon, color: effectiveColor),
        ),
        title: Text(title.toUpperCase(),
            style: GoogleFonts.chakraPetch(
                fontWeight: FontWeight.bold, color: JweTheme.textWhite, fontSize: 16)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: JweTheme.textMuted, fontSize: 12)),
        trailing: Icon(MdiIcons.chevronRight, color: JweTheme.textMuted),
        onTap: onTap,
      ),
    );
  }
}