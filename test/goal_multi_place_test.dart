import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('deleting one place removes only that place from each goal', () {
    final provider = AppProvider.forTest();
    provider.addGoalPlace(const GoalPlace(id: 'gym', name: 'Gym', colorValue: 0xFF10B981));
    provider.addGoal(GoalModel(
      id: 'g_multi',
      title: 'Strength block',
      placeIds: ['home', 'gym'],
    ));

    provider.deleteGoalPlace('gym');

    final goal = provider.goals.firstWhere((g) => g.id == 'g_multi');
    expect(goal.placeIds, ['home']);
  });
}
