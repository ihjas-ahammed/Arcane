import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class SkillsDrawer extends StatelessWidget {
  const SkillsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final todayStr = helper.getTodayDateString();

    return Drawer(
      width: 360,
      backgroundColor: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF1F2731), AppTheme.fhBgDeepDark]
              )
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.shieldAccountOutline, color: AppTheme.fhAccentGold, size: 28),
                    const SizedBox(width: 12),
                    Text("VIRTUE", style: theme.textTheme.headlineMedium?.copyWith(color: AppTheme.fhTextPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("// INTERNAL ATTRIBUTES", style: TextStyle(color: AppTheme.fhTextSecondary, fontFamily: "RobotoCondensed", letterSpacing: 2.0, fontSize: 12)),
              ],
            ),
          ),

          // Skills Grid (Diamonds)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    'Wisdom', 'Courage', 'Humanity', 
                    'Justice', 'Temperance', 'Transcendence'
                  ].map((name) {
                    final xp7d = appProvider.get7DaySkillMomentum(name);
                    final int level = (xp7d / 50).floor() + 1;
                    
                    return _buildValorantSkillTile(context, name, level, xp7d % 50);
                  }).toList(),
                ),

                const SizedBox(height: 24),
                
                // Reflection Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                    border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("COMBAT LOG", style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.fhAccentTeal)),
                      const SizedBox(height: 12),
                      ValorantButton(
                        label: "LOG INSIGHT",
                        icon: MdiIcons.notebookEditOutline,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ReflectionEditorScreen(dateStr: todayStr)));
                        },
                        isPrimary: false,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Past logs are encrypted. Access via Analytics -> Secure Archives.",
                        style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic, fontSize: 12)
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildValorantSkillTile(BuildContext context, String name, int level, int currentXp) {
    Color color = _getSkillColor(name);
    IconData icon = _getSkillIcon(name);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Stack(
        children: [
          // Background Icon Watermark
          Positioned(
            right: -10, bottom: -10,
            child: Icon(icon, size: 60, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 20, color: color),
                    Text("LVL $level", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 16, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: currentXp / 50.0,
                      backgroundColor: Colors.black26,
                      color: color,
                      minHeight: 4,
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSkillColor(String name) { 
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return AppTheme.fhAccentRed;
      case 'humanity': return const Color(0xFFE91E63);
      case 'justice': return AppTheme.fhAccentGold;
      case 'temperance': return AppTheme.fhAccentTeal;
      case 'transcendence': return AppTheme.fhAccentPurple;
      default: return AppTheme.fhTextSecondary;
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