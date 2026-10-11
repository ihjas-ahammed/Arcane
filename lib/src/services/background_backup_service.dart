import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:missions/firebase_options.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/state_database.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/state_validator.dart';
import 'package:missions/src/services/cloud_snapshot_store.dart';

@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != input?['uid']) return true;
      final prefs = await SharedPreferences.getInstance();
      final baselineText =
          await StateDatabase.instance.getMeta(user.uid, 'cloudBaseline');
      final baseline = int.tryParse(baselineText ?? '') ??
          prefs.getInt('cloud_baseline_${user.uid}');
      if (baseline == null) return true;
      final version = await StateDatabase.instance
              .getMeta(user.uid, 'cloudBaselineVersion') ??
          prefs.getString('cloud_baseline_version_${user.uid}');
      final state = await LocalStorageService().loadState(user.uid);
      if (state == null ||
          (state['settings'] as Map?)?['autoSaveEnabled'] == false ||
          state['_quarantine'] != null) return true;
      validateAppState(state);
      final last = DateTime.tryParse(
          prefs.getString('last_cloud_push_${user.uid}') ?? '');
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 6))
        return true;
      final storage = StorageService();
      final saved = await storage.saveSnapshot(
          user.uid, cloudCollectionsFromState(state),
          baseline: baseline,
          baselineVersion: version == null || version.isEmpty ? null : version,
          deviceId: prefs.getString('cloud_device_id') ?? 'android-background');
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return true;
      final timestamp = (saved['lastModified'] as num).toInt();
      await StateDatabase.instance
          .setMeta(user.uid, 'cloudBaseline', '$timestamp');
      await prefs.setInt('cloud_baseline_${user.uid}', timestamp);
      await StateDatabase.instance.setMeta(
          user.uid, 'cloudBaselineVersion', saved['version']?.toString() ?? '');
      await prefs.setString('cloud_baseline_version_${user.uid}',
          saved['version']?.toString() ?? '');
      await prefs.setString(
          'last_cloud_push_${user.uid}', DateTime.now().toIso8601String());
      return true;
    } on CloudConflictException catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_sync_error_${input?['uid']}', e.message);
      return true; // A conflict requires an explicit merge, not repeated overwrites.
    } catch (e) {
      debugPrint('Background backup will retry: $e');
      return false;
    } finally {
      await StateDatabase.instance.close();
    }
  });
}

Map<String, dynamic> cloudCollectionsFromState(Map<String, dynamic> state) {
  Map<String, dynamic> select(List<String> keys) => {
        for (final key in keys)
          if (state.containsKey(key)) key: state[key]
      };
  return {
    'tasks': select([
      'mainTasks',
      'projects',
      'routineLists',
      'goals',
      'goalPlaces',
      'selectedTaskId',
      'activeTimers'
    ]),
    'history': {'completedByDay': state['completedByDay'] ?? {}},
    'reflections': {'reflectionLogs': state['reflectionLogs'] ?? []},
    'finance':
        select(['transactions', 'categories', 'savingsGoals', 'accounts']),
    'health': select(['foodItems', 'healthLogs']),
    'settings': select([
      'lastLoginDate',
      'settings',
      'skills',
      'trackedSkills',
      'sops',
      'chatbotMemory',
      'apiKeyIndex',
      'legacySkills',
      'mergeConflicts',
      'tombstones'
    ]),
    'trading': state['trading'] ?? {},
    'launcher': state['launcher'] ?? {},
  };
}

class BackgroundBackupService {
  static bool _initialized = false;
  static Future<void> schedule(String uid) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_initialized) {
      await Workmanager().initialize(backupCallbackDispatcher);
      _initialized = true;
    }
    await Workmanager().registerPeriodicTask(
        'arcane-cloud-backup', 'cloud-backup',
        frequency: const Duration(hours: 6),
        inputData: {'uid': uid},
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
            networkType: NetworkType.unmetered, requiresCharging: true));
  }
}
