import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('SOP Model & Provider Tests', () {
    test('SopExecutionLog serialization and deserialization', () {
      final now = DateTime(2026, 7, 26, 12, 0);
      final log = SopExecutionLog(
        id: 'log_1',
        timestamp: now,
        notes: 'Followed all steps cleanly.',
        successStatus: 'success',
        rating: 5,
      );

      final json = log.toJson();
      final restored = SopExecutionLog.fromJson(json);

      expect(restored.id, 'log_1');
      expect(restored.notes, 'Followed all steps cleanly.');
      expect(restored.successStatus, 'success');
      expect(restored.rating, 5);
      expect(restored.timestamp, now);
    });

    test('SopModel serialization and deserialization', () {
      final now = DateTime(2026, 7, 26, 12, 0);
      final log = SopExecutionLog(
        id: 'log_1',
        timestamp: now,
        notes: 'Trial 1',
        successStatus: 'partial',
        rating: 3,
      );
      final sop = SopModel(
        id: 'sop_1',
        title: 'Emergency Reset',
        situation: 'Feeling overwhelmed by task count',
        steps: ['Breathe for 60s', 'Pick top priority', 'Hide distractor apps'],
        expectedOutcomes: 'Calm mind within 5 minutes',
        executionLogs: [log],
        createdAt: now,
        updatedAt: now,
      );

      final json = sop.toJson();
      final restored = SopModel.fromJson(json);

      expect(restored.id, 'sop_1');
      expect(restored.title, 'Emergency Reset');
      expect(restored.situation, 'Feeling overwhelmed by task count');
      expect(restored.steps.length, 3);
      expect(restored.steps.first, 'Breathe for 60s');
      expect(restored.expectedOutcomes, 'Calm mind within 5 minutes');
      expect(restored.executionLogs.length, 1);
      expect(restored.executionLogs.first.notes, 'Trial 1');
    });

    test('AppProvider SOP CRUD operations', () {
      final provider = AppProvider();
      final now = DateTime.now();

      final sop1 = SopModel(
        id: 'sop_1',
        title: 'SOP 1',
        situation: 'Situation 1',
        steps: ['Step 1'],
        expectedOutcomes: 'Outcome 1',
        executionLogs: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(provider.sops.isEmpty, isTrue);

      provider.addSop(sop1);
      expect(provider.sops.length, 1);
      expect(provider.sops.first.title, 'SOP 1');

      final updatedSop1 = sop1.copyWith(title: 'SOP 1 Updated');
      provider.updateSop(updatedSop1);
      expect(provider.sops.first.title, 'SOP 1 Updated');

      final trialLog = SopExecutionLog(
        id: 'log_100',
        timestamp: now,
        notes: 'Great trial',
        successStatus: 'success',
        rating: 5,
      );
      provider.addSopExecutionLog('sop_1', trialLog);
      expect(provider.sops.first.executionLogs.length, 1);
      expect(provider.sops.first.executionLogs.first.notes, 'Great trial');

      provider.deleteSop('sop_1');
      expect(provider.sops.isEmpty, isTrue);
    });

    test('AppProvider active SOP running session workflow', () {
      final provider = AppProvider();
      final now = DateTime.now();

      final sop = SopModel(
        id: 'sop_run_1',
        title: 'Focus Reset SOP',
        situation: 'Paralysis',
        steps: ['Step A', 'Step B', 'Step C'],
        expectedOutcomes: 'Clear focus',
        executionLogs: [],
        createdAt: now,
        updatedAt: now,
      );

      provider.addSop(sop);
      expect(provider.activeSopSession, isNull);

      provider.startSopSession(sop, taskTitle: 'Project Alpha Task');
      expect(provider.activeSopSession, isNotNull);
      expect(provider.activeSopSession!.sop.id, 'sop_run_1');
      expect(provider.activeSopSession!.taskTitle, 'Project Alpha Task');
      expect(provider.activeSopSession!.completionPercentage, 0.0);

      provider.toggleStepInActiveSopSession(0);
      expect(provider.activeSopSession!.completedStepIndices.contains(0), isTrue);
      expect(provider.activeSopSession!.completionPercentage, closeTo(33.33, 0.1));
      expect(provider.activeSopSession!.progressPoints.length, 2);

      provider.pauseActiveSopSession();
      expect(provider.activeSopSession!.isPaused, isTrue);

      provider.resumeActiveSopSession();
      expect(provider.activeSopSession!.isPaused, isFalse);

      provider.finishActiveSopSession(
        notes: 'Execution was smooth',
        rating: 5,
        status: 'success',
      );
      expect(provider.activeSopSession, isNull);
      expect(provider.sops.first.executionLogs.length, 1);
      expect(provider.sops.first.executionLogs.first.notes, 'Execution was smooth');
    });
  });
}
