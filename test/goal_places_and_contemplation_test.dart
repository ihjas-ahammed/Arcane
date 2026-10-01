import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalPlace Model Tests', () {
    test('Default places have correct IDs and distinct tactical colors', () {
      final defaults = GoalPlace.defaultPlaces;
      expect(defaults.length, 3);

      final home = defaults.firstWhere((p) => p.id == 'home');
      final work = defaults.firstWhere((p) => p.id == 'work');
      final college = defaults.firstWhere((p) => p.id == 'college');

      expect(home.name, 'Home');
      expect(home.colorValue, 0xFF10B981); // Emerald / Teal

      expect(work.name, 'Work');
      expect(work.colorValue, 0xFFFFB547); // Tactical Amber

      expect(college.name, 'College');
      expect(college.colorValue, 0xFF8B5CF6); // Tactical Purple / Indigo
    });

    test('Custom GoalPlace toJson and fromJson roundtrip', () {
      const place = GoalPlace(
        id: 'place_gym',
        name: 'Gym',
        colorValue: 0xFFEF4444,
        iconName: 'dumbbell',
      );

      final json = place.toJson();
      expect(json['id'], 'place_gym');
      expect(json['name'], 'Gym');
      expect(json['colorValue'], 0xFFEF4444);
      expect(json['iconName'], 'dumbbell');

      final reconstructed = GoalPlace.fromJson(json);
      expect(reconstructed.id, place.id);
      expect(reconstructed.name, place.name);
      expect(reconstructed.colorValue, place.colorValue);
      expect(reconstructed.iconName, place.iconName);
    });

    test('GoalPlace copyWith updates fields correctly', () {
      const original = GoalPlace(
        id: 'place_lib',
        name: 'Library',
        colorValue: 0xFF3B82F6,
      );

      final updated = original.copyWith(name: 'Main Library', colorValue: 0xFF00E5FF);
      expect(updated.id, 'place_lib');
      expect(updated.name, 'Main Library');
      expect(updated.colorValue, 0xFF00E5FF);
    });
  });

  group('GoalModel Place & Contemplation Reminders', () {
    test('GoalModel stores reminderTimes and placeId with full JSON roundtrip', () {
      final goal = GoalModel(
        id: 'goal_daily_1',
        title: 'Deep Focus Coding',
        scope: GoalScope.daily,
        metricType: GoalMetricType.check,
        placeId: 'work',
        reminderTimes: ['09:00', '14:30', '18:00'],
      );

      expect(goal.placeId, 'work');
      expect(goal.reminderTimes, ['09:00', '14:30', '18:00']);

      final json = goal.toJson();
      expect(json['placeId'], 'work');
      expect(json['reminderTimes'], ['09:00', '14:30', '18:00']);

      final restored = GoalModel.fromJson(json);
      expect(restored.id, goal.id);
      expect(restored.title, goal.title);
      expect(restored.placeId, 'work');
      expect(restored.reminderTimes, ['09:00', '14:30', '18:00']);
    });

    test('GoalModel copyWith supports modifying and clearing placeId', () {
      final goal = GoalModel(
        id: 'goal_daily_2',
        title: 'Study Mechanics',
        scope: GoalScope.daily,
        placeId: 'college',
        reminderTimes: ['10:00'],
      );

      final updated = goal.copyWith(
        placeId: 'home',
        reminderTimes: ['10:00', '16:00'],
      );
      expect(updated.placeId, 'home');
      expect(updated.reminderTimes, ['10:00', '16:00']);

      final cleared = updated.copyWith(clearPlaceId: true);
      expect(cleared.placeId, isNull);
    });

    test('GoalModel defaults reminderTimes to empty list and placeId to null', () {
      final goal = GoalModel(
        id: 'goal_def',
        title: 'Simple Goal',
      );

      expect(goal.placeId, isNull);
      expect(goal.reminderTimes, isEmpty);

      final json = goal.toJson();
      expect(json.containsKey('placeId'), isFalse);
      expect(json['reminderTimes'], isEmpty);
    });
  });

  group('NotificationService Goal Reminder ID Determinism', () {
    test('goalReminderId generates deterministic IDs within expected range', () {
      final id1 = NotificationService.goalReminderId('goal_123', 0);
      final id2 = NotificationService.goalReminderId('goal_123', 0);
      final id3 = NotificationService.goalReminderId('goal_123', 1);
      final idOther = NotificationService.goalReminderId('goal_999', 0);

      expect(id1, id2, reason: 'Same goal and index must generate identical ID');
      expect(id1 != id3, isTrue, reason: 'Different index must generate different ID');
      expect(id1 != idOther, isTrue, reason: 'Different goal ID must generate different ID');

      expect(id1 >= 60000 && id1 <= 90000, isTrue);
    });
  });
}
