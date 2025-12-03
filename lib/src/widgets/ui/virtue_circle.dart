// lib/src/widgets/ui/virtue_circle.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class VirtueCircle extends StatelessWidget {
  final Skill skill;
  final VoidCallback? onTap;

  const VirtueCircle({super.key, required this.skill, this.onTap});

  Color get color => _getSkillColor(skill.name);
  IconData get icon => _getSkillIcon(skill.name);

  static Color _getSkillColor(String name) {
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
  
  static IconData _getSkillIcon(String name) {
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

  @override
  Widget build(BuildContext context) {
    final double progress = skill.currentXp / skill.maxXp;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, // Fixed width for grid consistency
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             SizedBox(
               height: 60,
               width: 60,
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   SizedBox(
                     height: 60, width: 60,
                     child: CircularProgressIndicator(
                       value: progress,
                       backgroundColor: AppTheme.fhBgDeepDark,
                       color: color,
                       strokeWidth: 5,
                     ),
                   ),
                   Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(icon, size: 20, color: color),
                       const SizedBox(height: 2),
                       Text(skill.level.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                     ],
                   )
                 ],
               ),
             ),
             const SizedBox(height: 8),
             Text(skill.name.toUpperCase(), 
               style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.fhTextSecondary, letterSpacing: 0.5),
               textAlign: TextAlign.center,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             )
          ],
        ),
      ),
    );
  }
}