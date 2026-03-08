import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

/// Handles Cloud Synchronization and Local Persistence
mixin SyncMixin on ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  Timer? _autoSaveTimer;
  final Set<String> _dirtyCollections = {};
  bool _hasUnsavedChanges = false;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;
  
  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  // Dependencies to be implemented by AppProvider
  User? get currentUser;
  AppSettings get settings;
  Map<String, dynamic> getFullAppState(); 
  void loadStateFromMap(Map<String, dynamic> data);

  void initSync() {
    _autoSaveTimer?.cancel();
    // Faster check interval (5s) for "Realtime" feel, but relies on dirty flags
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasUnsavedChanges &&
          currentUser != null &&
          !_isManuallyLoading &&
          settings.autoSaveEnabled) {
        _performActualSave();
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void markDirty(String collection) {
    _dirtyCollections.add(collection);
    _hasUnsavedChanges = true;
    _saveLocalSnapshot(); // Always persist locally immediately
    notifyListeners();
  }

  void scheduleRealtimeSync() {
    _hasUnsavedChanges = true;
    _saveLocalSnapshot();
    if (settings.autoSaveEnabled) {
      // Trigger save on next tick (or debounced)
      notifyListeners();
    }
  }

  Future<void> _saveLocalSnapshot({bool forceFlush = false}) async {
    try {
      final fullData = getFullAppState();
      await _localStorageService.saveState(fullData);
      
      if (forceFlush && (Platform.isAndroid || Platform.isWindows)) {
        _createBackupFile(fullData);
      }
    } catch (e) {
      debugPrint("Local snapshot failed: $e");
    }
  }

  Future<void> _createBackupFile(Map<String, dynamic> data) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${backupDir.path}/backup_$timestamp.json');
      
      final jsonString = await compute((Map<String, dynamic> d) => jsonEncode(d), data);
      await file.writeAsString(jsonString);
      
      // Cleanup old backups (keep last 5)
      final files = backupDir.listSync().whereType<File>().toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      if (files.length > 5) {
        for (var i = 0; i < files.length - 5; i++) {
          await files[i].delete();
        }
      }
    } catch (_) {}
  }

  Future<void> manuallySaveToCloud() async {
    if (currentUser == null) return;
    await _performActualSave(force: true);
  }

  Future<void> manuallyLoadFromCloud() async {
    if (currentUser == null) return;
    _isManuallyLoading = true;
    notifyListeners();
    try {
      final cloudData = await _storageService.getUserData(currentUser!.uid);
      if (cloudData != null) {
        loadStateFromMap(cloudData);
        _hasUnsavedChanges = false;
        _dirtyCollections.clear();
        await _saveLocalSnapshot(forceFlush: true);
      }
    } finally {
      _isManuallyLoading = false;
      notifyListeners();
    }
  }

  Future<void> _performActualSave({bool force = false}) async {
    if (currentUser == null) return;
    if (_isSyncing) return; // Prevent concurrent syncs

    _isSyncing = true;
    notifyListeners();

    try {
      final appData = getFullAppState();
      
      // 1. Always update Settings timestamp
      settings.lastModified = DateTime.now().millisecondsSinceEpoch;
      
      // 2. Prepare chunks
      // We use the full app state map to extract chunks to ensure consistency
      final tasksData = {'mainTasks': appData['mainTasks']};
      final historyData = {'completedByDay': appData['completedByDay']};
      final reflectionsData = {'reflectionLogs': appData['reflectionLogs']};
      final financeData = {
        'transactions': appData['transactions'],
        'categories': appData['categories'],
        'savingsGoals': appData['savingsGoals']
      };
      
      // Settings doc includes auxiliary data
      final settingsData = {
        'lastLoginDate': appData['lastLoginDate'],
        'settings': settings.toJson(),
        'selectedTaskId': appData['selectedTaskId'],
        'apiKeyIndex': appData['apiKeyIndex'],
        'activeTimers': appData['activeTimers'],
        'lastSuccessfulSaveTimestamp': DateTime.now().toIso8601String(),
        'chatbotMemory': appData['chatbotMemory'],
        'skills': appData['skills'],
      };

      bool success = true;

      // 3. Save dirty collections
      if (force || _dirtyCollections.contains('tasks')) {
        if (!await _storageService.saveTasks(currentUser!.uid, tasksData)) success = false;
      }
      if (force || _dirtyCollections.contains('history')) {
        if (!await _storageService.saveHistory(currentUser!.uid, historyData)) success = false;
      }
      if (force || _dirtyCollections.contains('reflections')) {
        if (!await _storageService.saveReflections(currentUser!.uid, reflectionsData)) success = false;
      }
      if (force || _dirtyCollections.contains('finance')) {
        if (!await _storageService.saveFinance(currentUser!.uid, financeData)) success = false;
      }
      // Always try to save settings if anything else was saved or if specifically dirty
      if (force || _dirtyCollections.isNotEmpty || _dirtyCollections.contains('settings')) {
        if (!await _storageService.saveSettings(currentUser!.uid, settingsData)) success = false;
      }

      if (success) {
        _dirtyCollections.clear();
        _hasUnsavedChanges = false;
        _lastSuccessfulSaveTimestamp = DateTime.now();
        // Update local snapshot with new timestamp
        await _saveLocalSnapshot(); 
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}