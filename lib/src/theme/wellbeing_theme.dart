import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class WellbeingTheme {
  static Color getColor(String trait) {
    switch (trait.toLowerCase()) {
      case 'positivity':
        return const Color(0xFFFFD700); // Yellow
      case 'resilience':
        return const Color(0xFF1E90FF); // Dodger Blue
      case 'satisfaction':
        return const Color(0xFF00FFFF); // Cyan
      case 'vitality':
        return const Color(0xFF32CD32); // Lime Green
      case 'env. mastery':
        return const Color(0xFFFFA500); // Orange
      case 'relationships':
        return const Color(0xFFFF69B4); // Hot Pink
      case 'self-acceptance':
        return const Color(0xFF9370DB); // Medium Purple
      case 'mastery':
        return const Color(0xFFFF4500); // Orange Red
      case 'autonomy':
        return const Color(0xFF20B2AA); // Light Sea Green
      case 'growth':
        return const Color(0xFF7CFC00); // Lawn Green
      case 'engagement':
        return const Color(0xFFF8F8FF); // Ghost White
      case 'meaning':
        return const Color(0xFFFFD700); // Amber/Gold
      default:
        return Colors.grey;
    }
  }

  static IconData getIcon(String trait) {
    switch (trait.toLowerCase()) {
      case 'positivity':
        return MdiIcons.emoticonHappyOutline;
      case 'resilience':
        return MdiIcons.shieldHalfFull;
      case 'satisfaction':
        return MdiIcons.checkDecagramOutline;
      case 'vitality':
        return MdiIcons.heartPulse;
      case 'env. mastery':
        return MdiIcons.earth;
      case 'relationships':
        return MdiIcons.accountHeartOutline;
      case 'self-acceptance':
        return MdiIcons.accountCheckOutline;
      case 'mastery':
        return MdiIcons.starShootingOutline;
      case 'autonomy':
        return MdiIcons.accountKeyOutline;
      case 'growth':
        return MdiIcons.sproutOutline;
      case 'engagement':
        return MdiIcons.fire;
      case 'meaning':
        return MdiIcons.compassOutline;
      default:
        return MdiIcons.circleSmall;
    }
  }

  static String getCategory(String trait) {
    switch (trait.toLowerCase()) {
      case 'positivity':
      case 'resilience':
      case 'satisfaction':
        return 'Emotional';
      case 'autonomy':
      case 'env. mastery':
      case 'self-acceptance':
        return 'Psychological';
      case 'relationships':
      case 'engagement':
      case 'meaning':
        return 'Social & Purpose';
      case 'vitality':
      case 'mastery':
      case 'growth':
        return 'Vitality & Growth';
      default:
        return 'Other';
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Emotional':
        return const Color(0xFFFFD700); // Gold/Yellow
      case 'Psychological':
        return const Color(0xFF00F59B); // Teal
      case 'Social & Purpose':
        return const Color(0xFF8A2BE2); // Purple
      case 'Vitality & Growth':
        return const Color(0xFFFF4655); // Red
      default:
        return Colors.grey;
    }
  }
}