import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/screens/journaling/people_info_screen.dart';
import 'package:arcane/src/screens/journaling/simulate_event_screen.dart';
import 'package:arcane/src/screens/journaling/simulate_talk_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedToolsScreen extends StatelessWidget {
  const AdvancedToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("ADVANCED PROTOCOLS"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "CLASSIFIED SUITE",
              style: TextStyle(
                color: AppTheme.fhAccentPurple,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            _buildToolCard(
              context,
              title: "PEOPLE INTEL",
              description: "Analyze relationships, communication patterns, and psychological profiles of entities extracted from your logs.",
              icon: MdiIcons.accountGroup,
              color: AppTheme.fhAccentTeal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeopleInfoScreen())),
            ),
            const SizedBox(height: 16),
            _buildToolCard(
              context,
              title: "SITUATION SIMULATOR",
              description: "Run predictive models on future scenarios based on your historical behavior and psychological patterns.",
              icon: MdiIcons.headLightbulbOutline,
              color: AppTheme.fhAccentPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulateEventScreen())),
            ),
            const SizedBox(height: 16),
            _buildToolCard(
              context,
              title: "COMMS SIMULATOR",
              description: "Initiate a simulated Nora chat session roleplaying as a specific person from your intelligence files.",
              icon: MdiIcons.forumOutline,
              color: AppTheme.fhAccentOrange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulateTalkScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, {required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ValorantCard(
      borderColor: color.withOpacity(0.5),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary),
        ],
      ),
    );
  }
}