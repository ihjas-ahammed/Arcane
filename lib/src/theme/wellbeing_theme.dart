import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// The twelve needs a day's reflections are read against ("What the day needed").
///
/// They are deliberately distinct (no two measure the same thing) and each rests on a
/// well-studied framework rather than on mood words:
///
///  * Rest, Security          Maslow's physiological and safety needs; recovery research
///  * Belonging, Self-Worth   Baumeister & Leary's need to belong; Maslow's esteem; Neff's self-compassion
///  * Autonomy, Competence    Self-Determination Theory (Deci & Ryan); the Stoic sphere of choice
///  * Growth                  Ryff's personal growth; Aristotle's actualisation of potential
///  * Purpose, Integrity      Frankl's will to meaning; Ryff's purpose; virtue ethics (acting by one's values)
///  * Flow, Equanimity, Delight  Csikszentmihalyi; Stoic ataraxia and emotion regulation (Gross); Fredrickson's positive emotion
class WellbeingTheme {
  static const List<String> needNames = [
    'Rest',
    'Security',
    'Belonging',
    'Self-Worth',
    'Autonomy',
    'Competence',
    'Growth',
    'Purpose',
    'Integrity',
    'Flow',
    'Equanimity',
    'Delight',
  ];

  /// One line each: what the need is, written to be read by the user and used in AI prompts.
  static const Map<String, String> descriptions = {
    'Rest': 'Energy and recovery: sleep, food, movement, a body that is not running on empty.',
    'Security': 'Stability and order: money, health, home and routines feeling safe and predictable.',
    'Belonging': 'Being seen, accepted and supported by people who matter; giving the same in return.',
    'Self-Worth': 'Respecting yourself: self-compassion, recognition, not measuring your value by one outcome.',
    'Autonomy': 'Acting from your own choice instead of pressure; owning what is yours to decide.',
    'Competence': 'Feeling capable: finishing something hard, using a skill, seeing effort turn into results.',
    'Growth': 'Becoming more than you were: learning, feedback, deliberate practice, stretching.',
    'Purpose': 'Something larger than today: direction, contribution, work that matters to you.',
    'Integrity': 'Living by your values: doing what you said, being honest, no gap between belief and action.',
    'Flow': 'Absorption: a task that holds you fully, with focus and enjoyment, time disappearing.',
    'Equanimity': 'Inner steadiness: meeting setbacks and strong emotion without being run by them.',
    'Delight': 'Savouring: joy, gratitude, beauty, humour, play, awe.',
  };

  /// Maps any stored or AI-returned name (including the earlier well-being labels) onto a need.
  static String? normalizeSkillName(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.isEmpty) return null;
    for (final n in needNames) {
      if (c == n.toLowerCase()) return n;
    }
    // Earlier labels, so reflections analysed before this model still chart correctly.
    if (c.contains('positiv') || c.contains('satisf') || c.contains('delight') || c.contains('joy')) return 'Delight';
    if (c.contains('resili') || c.contains('equanim') || c.contains('calm')) return 'Equanimity';
    if (c.contains('vital') || c.contains('rest') || c.contains('energy')) return 'Rest';
    if (c.contains('env') || c.contains('secur') || c.contains('safe')) return 'Security';
    if (c.contains('relation') || c.contains('belong') || c.contains('connect')) return 'Belonging';
    if (c.contains('self-accept') || c.contains('self accept') || c.contains('worth')) return 'Self-Worth';
    if (c.contains('mastery') || c.contains('compet')) return 'Competence';
    if (c.contains('autonom') || c.contains('freedom')) return 'Autonomy';
    if (c.contains('growth') || c.contains('learn')) return 'Growth';
    if (c.contains('engage') || c.contains('flow')) return 'Flow';
    if (c.contains('integr') || c.contains('value') || c.contains('virtue')) return 'Integrity';
    if (c.contains('mean') || c.contains('purpose')) return 'Purpose';
    return null;
  }

  static String describe(String trait) => descriptions[normalizeSkillName(trait) ?? trait] ?? '';

  static Color getColor(String trait) {
    final bool l = JweTheme.isLight;
    // Light values keep each hue but darkened for legibility on warm-paper surfaces.
    switch (trait.toLowerCase()) {
      case 'rest':
        return l ? const Color(0xFF1D4ED8) : const Color(0xFF5B9DFF); // night blue
      case 'security':
        return l ? const Color(0xFF57534E) : const Color(0xFFB8B2A7); // stone
      case 'belonging':
        return l ? const Color(0xFFBE185D) : const Color(0xFFFF69B4); // warm pink
      case 'self-worth':
        return l ? const Color(0xFF6D28D9) : const Color(0xFF9F7AEA); // violet
      case 'autonomy':
        return l ? const Color(0xFF0F766E) : const Color(0xFF20B2AA); // teal
      case 'competence':
        return l ? const Color(0xFFB91C1C) : const Color(0xFFFF5A3C); // ember
      case 'growth':
        return l ? const Color(0xFF4D7C0F) : const Color(0xFF8BE04A); // green shoot
      case 'purpose':
        return l ? const Color(0xFF854D0E) : const Color(0xFFFFC53D); // gold
      case 'integrity':
        return l ? const Color(0xFF0E7490) : const Color(0xFF22D3EE); // clear cyan
      case 'flow':
        return l ? const Color(0xFFC2410C) : const Color(0xFFFFA14A); // orange
      case 'equanimity':
        return l ? const Color(0xFF334155) : const Color(0xFF94A3B8); // calm slate
      case 'delight':
        return l ? const Color(0xFFA16207) : const Color(0xFFFFE066); // sunlight
      default:
        return Colors.grey;
    }
  }

  static IconData getIcon(String trait) {
    switch (trait.toLowerCase()) {
      case 'rest':
        return MdiIcons.sleep;
      case 'security':
        return MdiIcons.shieldHomeOutline;
      case 'belonging':
        return MdiIcons.accountHeartOutline;
      case 'self-worth':
        return MdiIcons.handHeartOutline;
      case 'autonomy':
        return MdiIcons.accountKeyOutline;
      case 'competence':
        return MdiIcons.starShootingOutline;
      case 'growth':
        return MdiIcons.sproutOutline;
      case 'purpose':
        return MdiIcons.compassOutline;
      case 'integrity':
        return MdiIcons.scaleBalance;
      case 'flow':
        return MdiIcons.fire;
      case 'equanimity':
        return MdiIcons.waves;
      case 'delight':
        return MdiIcons.whiteBalanceSunny;
      default:
        return MdiIcons.circleSmall;
    }
  }

  static String getCategory(String trait) {
    switch (trait.toLowerCase()) {
      case 'rest':
      case 'security':
        return 'Body & Safety';
      case 'belonging':
      case 'self-worth':
        return 'Connection & Worth';
      case 'autonomy':
      case 'competence':
      case 'growth':
        return 'Agency & Growth';
      case 'purpose':
      case 'integrity':
        return 'Meaning & Values';
      case 'flow':
      case 'equanimity':
      case 'delight':
        return 'Inner Life';
      default:
        return 'Other';
    }
  }

  static Color getCategoryColor(String category) {
    final bool l = JweTheme.isLight;
    switch (category) {
      case 'Body & Safety':
        return l ? const Color(0xFF1D4ED8) : const Color(0xFF5B9DFF);
      case 'Connection & Worth':
        return l ? const Color(0xFFBE185D) : const Color(0xFFFF69B4);
      case 'Agency & Growth':
        return l ? const Color(0xFF047857) : const Color(0xFF00F59B);
      case 'Meaning & Values':
        return l ? const Color(0xFF854D0E) : const Color(0xFFFFC53D);
      case 'Inner Life':
        return l ? const Color(0xFF6D28D9) : const Color(0xFF8A2BE2);
      default:
        return Colors.grey;
    }
  }
}
