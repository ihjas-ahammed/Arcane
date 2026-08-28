import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

import 'package:missions/src/widgets/skills/tactical_hud_widgets.dart';

class SkillIconOption {
  final String key;
  final String label;
  final IconData icon;
  final String category;
  final List<String> tags;

  const SkillIconOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.category,
    required this.tags,
  });
}

class SkillIconHelper {
  static const List<SkillIconOption> allIcons = [
    // Chess & Strategy
    SkillIconOption(key: 'chessKnight', label: 'Chess Knight', icon: MdiIcons.chessKnight, category: 'MENTAL', tags: ['chess', 'knight', 'elo', 'board', 'strategy', 'game']),
    SkillIconOption(key: 'chessQueen', label: 'Chess Queen', icon: MdiIcons.chessQueen, category: 'MENTAL', tags: ['queen', 'chess', 'royal', 'master']),
    SkillIconOption(key: 'chessKing', label: 'Chess King', icon: MdiIcons.chessKing, category: 'MENTAL', tags: ['king', 'chess', 'checkmate']),
    SkillIconOption(key: 'chessRook', label: 'Chess Rook', icon: MdiIcons.chessRook, category: 'MENTAL', tags: ['rook', 'castle', 'chess', 'tower']),
    SkillIconOption(key: 'chessBishop', label: 'Chess Bishop', icon: MdiIcons.chessBishop, category: 'MENTAL', tags: ['bishop', 'diagonal', 'chess']),
    SkillIconOption(key: 'puzzle', label: 'Puzzle & Logic', icon: MdiIcons.puzzleOutline, category: 'MENTAL', tags: ['puzzle', 'logic', 'problem', 'solve']),
    SkillIconOption(key: 'cards', label: 'Cards & Probability', icon: MdiIcons.cardsPlayingOutline, category: 'MENTAL', tags: ['cards', 'poker', 'probability', 'deck']),
    SkillIconOption(key: 'dice', label: 'Dice / RNG', icon: MdiIcons.dice5Outline, category: 'MENTAL', tags: ['dice', 'luck', 'chance', 'probability']),

    // Cognitive & Memory
    SkillIconOption(key: 'numeric', label: 'Digit Span', icon: MdiIcons.numeric, category: 'COGNITIVE', tags: ['digit', 'span', 'numbers', 'math', 'memory', 'count']),
    SkillIconOption(key: 'brain', label: 'Working Memory', icon: MdiIcons.brain, category: 'COGNITIVE', tags: ['brain', 'memory', 'iq', 'cognition', 'mind', 'intellect']),
    SkillIconOption(key: 'calculator', label: 'Mental Math', icon: MdiIcons.calculator, category: 'COGNITIVE', tags: ['math', 'calculation', 'speed', 'numbers']),
    SkillIconOption(key: 'headIdea', label: 'Insight / IQ', icon: MdiIcons.headLightbulbOutline, category: 'COGNITIVE', tags: ['insight', 'idea', 'creative', 'thinking']),
    SkillIconOption(key: 'eyeScan', label: 'Visual Perception', icon: MdiIcons.eyeOutline, category: 'COGNITIVE', tags: ['eye', 'vision', 'perception', 'focus', 'attention']),
    SkillIconOption(key: 'bookLearn', label: 'Reading Speed', icon: MdiIcons.bookOpenPageVariantOutline, category: 'COGNITIVE', tags: ['reading', 'speed', 'wpm', 'comprehension', 'study']),

    // Physical & Strength
    SkillIconOption(key: 'pushUp', label: 'Push-Ups', icon: MdiIcons.humanHandsdown, category: 'PHYSICAL', tags: ['pushup', 'push-up', 'chest', 'reps', 'calisthenics', 'fitness']),
    SkillIconOption(key: 'pullUp', label: 'Pull-Ups / Holds', icon: MdiIcons.gymnastics, category: 'PHYSICAL', tags: ['pullup', 'pull-up', 'hang', 'bar', 'back', 'grip', 'deadhang']),
    SkillIconOption(key: 'dumbbell', label: 'Dumbbell / Weights', icon: MdiIcons.dumbbell, category: 'PHYSICAL', tags: ['dumbbell', 'lift', 'weights', 'gym', 'curls', 'bench']),
    SkillIconOption(key: 'armFlex', label: 'Biceps & Strength', icon: MdiIcons.armFlex, category: 'PHYSICAL', tags: ['biceps', 'muscle', 'power', 'flex', 'strength']),
    SkillIconOption(key: 'weightLifter', label: 'Barbell / Squats', icon: MdiIcons.weightLifter, category: 'PHYSICAL', tags: ['squat', 'deadlift', 'barbell', 'powerlifting', 'olympic']),
    SkillIconOption(key: 'run', label: 'Sprint & Run', icon: MdiIcons.run, category: 'PHYSICAL', tags: ['sprint', 'run', 'pace', 'speed', 'cardio', '5k', '10k']),
    SkillIconOption(key: 'bike', label: 'Cycling', icon: MdiIcons.bike, category: 'PHYSICAL', tags: ['bike', 'cycling', 'pedal', 'watts', 'endurance']),
    SkillIconOption(key: 'swim', label: 'Swimming', icon: MdiIcons.swim, category: 'PHYSICAL', tags: ['swim', 'water', 'laps', 'freestyle']),

    // Endurance, Breath & Vitality
    SkillIconOption(key: 'breathHold', label: 'Breath Hold / Lungs', icon: MdiIcons.lungs, category: 'ENDURANCE', tags: ['breath', 'hold', 'apnea', 'lungs', 'oxygen', 'diving', 'time']),
    SkillIconOption(key: 'timer', label: 'Stopwatch / Time', icon: MdiIcons.timerOutline, category: 'ENDURANCE', tags: ['time', 'seconds', 'duration', 'stopwatch', 'timer', 'speedrun']),
    SkillIconOption(key: 'heartPulse', label: 'Heart Rate / HRV', icon: MdiIcons.heartPulse, category: 'ENDURANCE', tags: ['heart', 'hrv', 'pulse', 'vo2', 'cardio', 'stamina']),
    SkillIconOption(key: 'weatherWind', label: 'Cold Plunge / Thermo', icon: MdiIcons.weatherWindy, category: 'ENDURANCE', tags: ['cold', 'plunge', 'ice', 'bath', 'thermo', 'wimhof']),
    SkillIconOption(key: 'fire', label: 'Sauna / Heat', icon: MdiIcons.fire, category: 'ENDURANCE', tags: ['sauna', 'heat', 'tolerance', 'burn']),

    // Precision, Reaction & Combat
    SkillIconOption(key: 'target', label: 'Target & Precision', icon: MdiIcons.target, category: 'REACTION', tags: ['target', 'accuracy', 'aim', 'precision', 'fps']),
    SkillIconOption(key: 'crosshairs', label: 'Reaction Time', icon: MdiIcons.crosshairsGps, category: 'REACTION', tags: ['reaction', 'reflexes', 'ms', 'aimlab', 'crosshair']),
    SkillIconOption(key: 'swordCross', label: 'Combat / Sparring', icon: MdiIcons.swordCross, category: 'DISCIPLINE', tags: ['sword', 'sparring', 'combat', 'duel', 'martial']),
    SkillIconOption(key: 'boxingGlove', label: 'Boxing / Striking', icon: MdiIcons.boxingGlove, category: 'DISCIPLINE', tags: ['boxing', 'punch', 'strike', 'rounds', 'kickboxing']),
    SkillIconOption(key: 'karate', label: 'Martial Arts / Form', icon: MdiIcons.karate, category: 'DISCIPLINE', tags: ['karate', 'kata', 'form', 'bjj', 'judo']),
    SkillIconOption(key: 'meditation', label: 'Meditation / Stillness', icon: MdiIcons.meditation, category: 'DISCIPLINE', tags: ['meditation', 'zen', 'mindfulness', 'focus', 'sit']),

    // Tech, Gaming & Crafts
    SkillIconOption(key: 'codeTags', label: 'Coding / Typing Speed', icon: MdiIcons.codeTags, category: 'GENERAL', tags: ['code', 'typing', 'wpm', 'programming', 'dev']),
    SkillIconOption(key: 'gamepad', label: 'Aim / Gaming', icon: MdiIcons.gamepadVariant, category: 'GENERAL', tags: ['game', 'aim', 'esports', 'controller']),
    SkillIconOption(key: 'music', label: 'Music & Rhythm', icon: MdiIcons.music, category: 'GENERAL', tags: ['music', 'rhythm', 'bpm', 'instrument', 'audio']),
    SkillIconOption(key: 'palette', label: 'Art / Sketching', icon: MdiIcons.paletteOutline, category: 'GENERAL', tags: ['art', 'draw', 'sketch', 'paint', 'design']),
    SkillIconOption(key: 'trophy', label: 'Rank / Milestone', icon: MdiIcons.trophyOutline, category: 'GENERAL', tags: ['trophy', 'rank', 'win', 'achievement', 'score']),
    SkillIconOption(key: 'star', label: 'General Skill', icon: MdiIcons.starFourPoints, category: 'GENERAL', tags: ['star', 'general', 'custom', 'skill']),
  ];

  static IconData resolveIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return MdiIcons.starFourPoints;
    final match = allIcons.firstWhere(
      (i) => i.key.toLowerCase() == iconName.toLowerCase(),
      orElse: () => allIcons.firstWhere(
        (i) => i.tags.contains(iconName.toLowerCase()),
        orElse: () => allIcons.last,
      ),
    );
    return match.icon;
  }

  static Widget buildSkillIconWidget(String? iconName, {double size = 30, Color? color}) {
    final effectiveColor = color ?? TacColors.primaryRed;
    if (iconName == null || iconName.isEmpty) {
      return Icon(MdiIcons.starFourPoints, size: size, color: effectiveColor);
    }
    final key = iconName.toLowerCase();
    if (key == 'chessknight' || key == 'chess') {
      return ChessKnightSilhouette(size: size, color: effectiveColor);
    }
    if (key == 'numeric' || key == 'digitspan' || key == 'digits') {
      return DigitSpanOdometerIcon(width: size * 1.15, height: size * 0.95, color: effectiveColor);
    }
    if (key == 'pushup' || key == 'pushups' || key == 'push_up') {
      return PushUpSilhouetteIcon(size: size, color: effectiveColor);
    }
    if (key == 'pullup' || key == 'pullups' || key == 'pull_up') {
      return PullUpRigSilhouetteIcon(size: size, color: effectiveColor);
    }
    return Icon(resolveIcon(iconName), size: size, color: effectiveColor);
  }

  static String resolveKey(IconData icon) {
    for (final opt in allIcons) {
      if (opt.icon == icon) return opt.key;
    }
    return 'star';
  }
}

/// Interactive Searchable Modal for choosing Lucide & Material Design Icons.
class SkillIconPickerDialog extends StatefulWidget {
  final String currentIconKey;
  final Color accentColor;

  const SkillIconPickerDialog({
    super.key,
    required this.currentIconKey,
    required this.accentColor,
  });

  static Future<String?> show(BuildContext context, {required String currentIconKey, Color? accentColor}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SkillIconPickerDialog(
        currentIconKey: currentIconKey,
        accentColor: accentColor ?? JweTheme.accentAmber,
      ),
    );
  }

  @override
  State<SkillIconPickerDialog> createState() => _SkillIconPickerDialogState();
}

class _SkillIconPickerDialogState extends State<SkillIconPickerDialog> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  late String _selectedKey;

  final List<String> _categories = [
    'ALL',
    'MENTAL',
    'COGNITIVE',
    'PHYSICAL',
    'ENDURANCE',
    'REACTION',
    'DISCIPLINE',
    'GENERAL',
  ];

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.currentIconKey;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final query = _searchQuery.toLowerCase().trim();

    final filteredIcons = SkillIconHelper.allIcons.where((item) {
      final matchesCategory = _selectedCategory == 'ALL' || item.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return item.label.toLowerCase().contains(query) ||
          item.key.toLowerCase().contains(query) ||
          item.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: JweTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.shapeOutline, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'SELECT SKILL ICON',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search icons (e.g. chess, run, memory, math, breath)...',
                hintStyle: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: accent, size: 18),
                filled: true,
                fillColor: JweTheme.bgBase,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: JweTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Pills
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.2) : JweTheme.bgBase,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? accent : JweTheme.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.jetBrainsMono(
                        color: isSelected ? accent : JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Icons Grid
          Expanded(
            child: filteredIcons.isEmpty
                ? Center(
                    child: Text(
                      'No matching icons found.',
                      style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 13),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: filteredIcons.length,
                    itemBuilder: (context, index) {
                      final item = filteredIcons[index];
                      final isSelected = item.key == _selectedKey;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedKey = item.key);
                          Navigator.pop(context, item.key);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? accent.withValues(alpha: 0.25) : JweTheme.bgBase,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? accent : JweTheme.border.withValues(alpha: 0.6),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 8)]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                size: 28,
                                color: isSelected ? accent : JweTheme.textWhite,
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    color: isSelected ? accent : JweTheme.textMuted,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
