// lib/src/widgets/skills_drawer.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/reflection_dialog.dart';
import 'package:arcane/src/widgets/ui/virtue_circle.dart';
import 'package:arcane/src/widgets/ui/reflection_log_card.dart';
import 'package:arcane/src/widgets/dialogs/skill_detail_dialog.dart'; // New
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SkillsDrawer extends StatelessWidget {
  const SkillsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final skills = appProvider.skills;

    return Drawer(
      width: 350, // Slightly wider to accommodate 3 columns comfortably
      backgroundColor: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: AppTheme.fhBgDark,
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
            ),
            child: Column(
              children: [
                 Icon(MdiIcons.shieldAccount, size: 48, color: AppTheme.fhAccentGold),
                const SizedBox(height: 12),
                Text("PERSONA & VIRTUES",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.fhTextPrimary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text("Track your internal growth",
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Skills Grid
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85, // Adjust for VirtueCircle height
                  children: skills.map((skill) {
                    // Create a temporary VirtueCircle to access static getters for color/icon
                    // Ideally these should be util methods, but for now we instantiate or duplicate logic
                    // Let's rely on VirtueCircle to build itself
                    return VirtueCircle(
                      skill: skill,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => SkillDetailDialog(
                            skill: skill,
                            // Since VirtueCircle is a widget, we can't access its instance getter easily here
                            // We reconstruct the visual props or move logic to model/util. 
                            // For simplicity, we reuse the widget's internal logic via a temporary instance or just hardcode logic in Dialog
                            color: _getSkillColor(skill.name),
                            icon: _getSkillIcon(skill.name),
                            xpGainedToday: appProvider.getXpGainedForSkillToday(skill.name),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
                Divider(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  icon:  Icon(MdiIcons.notebookEditOutline),
                  label: const Text("LOG REFLECTION"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fhAccentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ReflectionDialog(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (appProvider.reflectionLogs.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("RECENT INSIGHTS", style: theme.textTheme.labelMedium),
                      Text("${appProvider.reflectionLogs.length} Total", style: const TextStyle(fontSize: 10, color: AppTheme.fhTextDisabled)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Use reversed to show newest first, take 5
                  ...appProvider.reflectionLogs.reversed.take(5).map((log) => 
                    ReflectionLogCard(log: log)
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Duplicating helper logic here for the Dialog call, or could be static in Model
  Color _getSkillColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return Colors.redAccent;
      case 'humanity': return Colors.pinkAccent;
      case 'justice': return Colors.amber;
      case 'temperance': return Colors.tealAccent;
      case 'transcendence': return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
  
  IconData _getSkillIcon(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return MdiIcons.brain;
      case 'courage': return MdiIcons.sword;
      case 'humanity': return MdiIcons.handHeart;
      case 'justice': return MdiIcons.scaleBalance;
      case 'temperance': return MdiIcons.yinYang;
      case 'transcendence': return MdiIcons.starFourPoints;
      default: return MdiIcons.circle;
    }
  }
}