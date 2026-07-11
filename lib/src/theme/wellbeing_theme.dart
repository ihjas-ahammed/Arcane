import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class WellbeingTheme {
  static String? normalizeSkillName(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('positiv')) return 'Positivity';
    if (clean.contains('resili')) return 'Resilience';
    if (clean.contains('satisf')) return 'Satisfaction';
    if (clean.contains('vital')) return 'Vitality';
    if (clean.contains('env') || clean.contains('environ')) return 'Env. Mastery';
    if (clean.contains('self-accept') || clean.contains('self accept')) return 'Self-Acceptance';
    if (clean.contains('relation')) return 'Relationships';
    if (clean.contains('mastery')) return 'Mastery';
    if (clean.contains('autonom')) return 'Autonomy';
    if (clean.contains('growth')) return 'Growth';
    if (clean.contains('engage')) return 'Engagement';
    if (clean.contains('mean') || clean.contains('purpose')) return 'Meaning';
    return null;
  }

  static Color getColor(String trait) {
    final bool l = JweTheme.isLight;
    // Light values keep each trait's hue but darkened for legibility on
    // warm-paper surfaces (neons and ghost-white vanish on light panels).
    switch (trait.toLowerCase()) {
      case 'positivity':
        return l ? const Color(0xFFA16207) : const Color(0xFFFFD700); // Yellow
      case 'resilience':
        return l ? const Color(0xFF1D4ED8) : const Color(0xFF1E90FF); // Dodger Blue
      case 'satisfaction':
        return l ? const Color(0xFF0E7490) : const Color(0xFF00FFFF); // Cyan
      case 'vitality':
        return l ? const Color(0xFF15803D) : const Color(0xFF32CD32); // Lime Green
      case 'env. mastery':
        return l ? const Color(0xFFC2410C) : const Color(0xFFFFA500); // Orange
      case 'relationships':
        return l ? const Color(0xFFBE185D) : const Color(0xFFFF69B4); // Hot Pink
      case 'self-acceptance':
        return l ? const Color(0xFF6D28D9) : const Color(0xFF9370DB); // Medium Purple
      case 'mastery':
        return l ? const Color(0xFFB91C1C) : const Color(0xFFFF4500); // Orange Red
      case 'autonomy':
        return l ? const Color(0xFF0F766E) : const Color(0xFF20B2AA); // Light Sea Green
      case 'growth':
        return l ? const Color(0xFF4D7C0F) : const Color(0xFF7CFC00); // Lawn Green
      case 'engagement':
        return l ? const Color(0xFF57534E) : const Color(0xFFF8F8FF); // Ghost White
      case 'meaning':
        return l ? const Color(0xFF854D0E) : const Color(0xFFFFD700); // Amber/Gold
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
    final bool l = JweTheme.isLight;
    switch (category) {
      case 'Emotional':
        return l ? const Color(0xFFA16207) : const Color(0xFFFFD700); // Gold/Yellow
      case 'Psychological':
        return l ? const Color(0xFF047857) : const Color(0xFF00F59B); // Teal
      case 'Social & Purpose':
        return l ? const Color(0xFF6D28D9) : const Color(0xFF8A2BE2); // Purple
      case 'Vitality & Growth':
        return l ? const Color(0xFFBE123C) : const Color(0xFFFF4655); // Red
      default:
        return Colors.grey;
    }
  }
}