import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/skills/skill_icon_helper.dart';
import 'package:missions/src/widgets/skills/tactical_hud_widgets.dart';

void main() {
  group('TrackedSkill & SkillTrainingLog Tests', () {
    test('defaultSkills initializes correctly with valid data', () {
      final defaults = TrackedSkill.defaultSkills();
      expect(defaults.isNotEmpty, true);
      expect(defaults.length, 4);

      final chess = defaults.firstWhere((s) => s.id == 'skill_chess_rating');
      expect(chess.name, 'CHESS RATING');
      expect(chess.targetValue, 3000);
      expect(chess.currentValue, 1350);
      expect(chess.progress, closeTo(1350 / 3000, 0.001));
      expect(chess.logs.length, 5);
      expect(chess.effectiveTier, 'CLUB PLAYER');
      expect(chess.bestValue, 1350);
    });

    test('effectiveTier auto-calculates when customTier is empty', () {
      final initiate = TrackedSkill(name: 'TEST', currentValue: 20, targetValue: 100);
      expect(initiate.effectiveTier, 'INITIATE');

      final average = TrackedSkill(name: 'TEST', currentValue: 45, targetValue: 100);
      expect(average.effectiveTier, 'AVERAGE - DECENT');

      final aboveAvg = TrackedSkill(name: 'TEST', currentValue: 65, targetValue: 100);
      expect(aboveAvg.effectiveTier, 'ABOVE AVERAGE');

      final competent = TrackedSkill(name: 'TEST', currentValue: 80, targetValue: 100);
      expect(competent.effectiveTier, 'COMPETENT');

      final veryGood = TrackedSkill(name: 'TEST', currentValue: 90, targetValue: 100);
      expect(veryGood.effectiveTier, 'VERY GOOD');

      final master = TrackedSkill(name: 'TEST', currentValue: 98, targetValue: 100);
      expect(master.effectiveTier, 'MASTER - ELITE');
    });

    test('SkillTrainingLog json round-trip works accurately', () {
      final log = SkillTrainingLog(
        id: 'test_log_1',
        timestamp: DateTime(2026, 8, 28, 6, 0),
        mode: 'BLITZ 5+0',
        value: 1350,
        delta: 18,
        resultType: 'WIN',
        durationSeconds: 1800,
        notes: 'Great opening prep.',
      );

      final json = log.toJson();
      final recovered = SkillTrainingLog.fromJson(json);

      expect(recovered.id, log.id);
      expect(recovered.mode, 'BLITZ 5+0');
      expect(recovered.value, 1350);
      expect(recovered.delta, 18);
      expect(recovered.resultType, 'WIN');
      expect(recovered.durationSeconds, 1800);
      expect(recovered.notes, 'Great opening prep.');
    });

    test('TrackedSkill json round-trip preserves all nested logs', () {
      final skill = TrackedSkill(
        id: 'skill_test',
        name: 'BREATH HOLD',
        subtitle: 'STATIC APNEA',
        category: 'ENDURANCE',
        description: 'Measures maximum breath hold time in seconds.',
        unit: 's',
        targetValue: 240,
        currentValue: 120,
        customTier: 'INTERMEDIATE',
        iconName: 'breathHold',
        logs: [
          SkillTrainingLog(
            id: 'log_1',
            mode: 'DRY O2',
            value: 120,
            delta: 10,
            resultType: 'PASS',
            durationSeconds: 600,
          ),
        ],
      );

      final json = skill.toJson();
      final recovered = TrackedSkill.fromJson(json);

      expect(recovered.id, skill.id);
      expect(recovered.name, 'BREATH HOLD');
      expect(recovered.subtitle, 'STATIC APNEA');
      expect(recovered.category, 'ENDURANCE');
      expect(recovered.unit, 's');
      expect(recovered.targetValue, 240);
      expect(recovered.currentValue, 120);
      expect(recovered.customTier, 'INTERMEDIATE');
      expect(recovered.logs.length, 1);
      expect(recovered.logs.first.value, 120);
    });

    test('SkillIconHelper resolves icons safely', () {
      expect(SkillIconHelper.resolveIcon('chessKnight'), isNotNull);
      expect(SkillIconHelper.resolveIcon('numeric'), isNotNull);
      expect(SkillIconHelper.resolveIcon('pushUp'), isNotNull);
      expect(SkillIconHelper.resolveIcon('pullUp'), isNotNull);
      expect(SkillIconHelper.resolveIcon('non_existent_key'), isNotNull);
    });

    test('TacColors dynamic tokens adjust correctly for light and dark theme', () {
      // Dark Mode verification
      JweTheme.isLight = false;
      expect(TacColors.bgDark, const Color(0xFF05070A));
      expect(TacColors.textMain, const Color(0xFFFFFFFF));
      expect(TacColors.primaryRed, const Color(0xFFFF4655));

      // Light Mode verification
      JweTheme.isLight = true;
      expect(TacColors.bgDark, const Color(0xFFEDE8E0));
      expect(TacColors.textMain, const Color(0xFF1E242F));
      expect(TacColors.primaryRed, const Color(0xFFC91D32));

      // Reset
      JweTheme.isLight = false;
    });
  });
}
