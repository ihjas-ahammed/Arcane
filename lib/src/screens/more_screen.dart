import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/screens/bus_schedule_screen.dart';
import 'package:arcane/src/screens/database_editor_screen.dart';
import 'package:arcane/src/screens/timetable_screen.dart';
import 'package:arcane/src/screens/journaling/quick_therapy_screen.dart';
import 'package:arcane/src/widgets/views/settings_view.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("SYSTEM & UTILITIES"),
        backgroundColor: AppTheme.fhBgDeepDark,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("UTILITIES & SYSTEM",
              style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.fhTextSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 12),

          _buildMenuTile(context,
              icon: MdiIcons.medicalBag,
              title: "Emergency Therapy",
              subtitle: "Quick psychological triage and action plan",
              colorOverride: AppTheme.fhAccentRed,
              onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const QuickTherapyScreen()));
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
              icon: MdiIcons.timetable,
              title: "Academic Timetable",
              subtitle: "4th Semester Physics",
              onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TimetableScreen()));
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

          const SizedBox(height: 24),
          Text("CONFIGURATION",
              style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.fhTextSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 12),

          _buildMenuTile(context,
              icon: MdiIcons.cogOutline,
              title: "System Settings",
              subtitle: "App preferences, AI config, and recovery",
              onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text("SETTINGS")),
                          backgroundColor: AppTheme.fhBgDeepDark,
                          body: Center(
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 800),
                                  child: const SettingsView())),
                        )));
          }),
        ],
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
    final effectiveColor = colorOverride ?? AppTheme.fhAccentTeal;
    return Card(
      color: AppTheme.fhBgDark,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: effectiveColor.withValues(alpha: 0.3))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: effectiveColor),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
        trailing: Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary),
        onTap: onTap,
      ),
    );
  }
}