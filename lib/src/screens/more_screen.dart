import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/screens/bus_schedule_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("UTILITIES", style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.fhTextSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          
          _buildMenuTile(
            context,
            icon: MdiIcons.busClock,
            title: "Bus Time",
            subtitle: "Schedule: S.S College - Areekode - Edavannappara",
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const BusScheduleScreen())
              );
            }
          ),
          
          // Future items can be added here
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppTheme.fhBgDark,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.3))
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.fhAccentTeal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
        trailing: Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary),
        onTap: onTap,
      ),
    );
  }
}