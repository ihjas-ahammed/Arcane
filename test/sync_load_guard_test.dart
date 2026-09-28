import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

/// Loading/resetting state must never look like a local edit: otherwise default or partial data
/// gets a fresh timestamp and the next sync pushes it over the real cloud data.
void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('changes made during a load are not dirty and keep the loaded timestamp', () {
    final p = AppProvider.forTest();
    p.endDataLoad();

    p.beginDataLoad();
    p.setSettings(AppSettings(lastModified: 1234));
    p.setMainTasks([MainTask(id: 'm', name: 'Loaded', description: '', theme: '', subTasks: [])]);
    p.endDataLoad();

    expect(p.settings.lastModified, 1234);
    expect(p.hasUnsavedChanges, isFalse);
  });

  test('edits after the load are tracked again', () {
    final p = AppProvider.forTest();
    p.beginDataLoad();
    p.setSettings(AppSettings(lastModified: 1234));
    p.endDataLoad();

    p.setMainTasks([MainTask(id: 'm', name: 'Edited', description: '', theme: '', subTasks: [])]);

    expect(p.hasUnsavedChanges, isTrue);
    expect(p.settings.lastModified, greaterThan(1234));
  });

  test('endDataLoad drops changes queued before the load finished', () {
    final p = AppProvider.forTest();
    p.setMainTasks([]); // e.g. a reset before auth resolved
    expect(p.hasUnsavedChanges, isTrue);

    p.beginDataLoad();
    p.endDataLoad();

    expect(p.hasUnsavedChanges, isFalse);
  });
}
