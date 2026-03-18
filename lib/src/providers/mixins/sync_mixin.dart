import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

mixin SyncMixin on ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  Timer? _autoSaveTimer;
  StreamSubscription? _rtdbSubscription;
  final Set<String> _dirtyCollections = {};
  bool _hasUnsavedChanges = false;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;
  
  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  User? get currentUser;
  AppSettings get settings;
  Map<String, dynamic> getFullAppState(); 
  void loadStateFromMap(Map<String, dynamic> data);

  void initSync() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasUnsavedChanges &&
          currentUser != null &&
          !_isManuallyLoading &&
          settings.autoSaveEnabled) {
        _performActualSave();
      }
    });
  }
  
  void startRealtimeSyncListener() {
    _rtdbSubscription?.cancel();
    if (currentUser == null) return;
    
    _rtdbSubscription = _storageService.watchLastModified(currentUser!.uid).listen((remoteTs) async {
      if (_isSyncing || _isManuallyLoading) return;
      if (remoteTs > settings.lastModified) {
        await manuallyLoadFromCloud();
      }
    });
  }

  void stopRealtimeSyncListener() {
    _rtdbSubscription?.cancel();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _rtdbSubscription?.cancel();
    super.dispose();
  }

  void markDirty(String collection) {
    settings.lastModified = DateTime.now().millisecondsSinceEpoch;
    _dirtyCollections.add(collection);
    _hasUnsavedChanges = true;
    _saveLocalSnapshot(); 
    notifyListeners();
  }

  void scheduleRealtimeSync() {
    _saveLocalSnapshot();
    if (settings.autoSaveEnabled && _hasUnsavedChanges) {
      notifyListeners();
    }
  }

  Future<void> syncIfDirty() async {
    if (_hasUnsavedChanges) {
      await _performActualSave();
    }
  }

  Future<void> forceLocalBackup() async {
    await _saveLocalSnapshot(forceFlush: true);
    notifyListeners();
  }

  Future<void> _saveLocalSnapshot({bool forceFlush = false}) async {
    if (currentUser == null) return;
    try {
      final fullData = getFullAppState();
      await _localStorageService.saveState(currentUser!.uid, fullData);
    } catch (e) {
      debugPrint("Local snapshot failed: $e");
    }
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
    if (_isSyncing) return; 

    _isSyncing = true;
    notifyListeners();

    try {
      final remoteTs = await _storageService.getLastModified(currentUser!.uid);
      if (remoteTs > settings.lastModified) {
        _isSyncing = false;
        await manuallyLoadFromCloud();
        return;
      }

      final appData = getFullAppState();
      
      final tasksData = {'mainTasks': appData['mainTasks']};
      final historyData = {'completedByDay': appData['completedByDay']};
      final reflectionsData = {'reflectionLogs': appData['reflectionLogs']};
      final financeData = {
        'transactions': appData['transactions'],
        'categories': appData['categories'],
        'savingsGoals': appData['savingsGoals']
      };
      
      final healthData = {
        'foodItems': appData['foodItems'],
        'healthLogs': appData['healthLogs']
      };
      
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
      if (force || _dirtyCollections.contains('health')) {
        if (!await _storageService.saveHealth(currentUser!.uid, healthData)) success = false;
      }
      if (force || _dirtyCollections.isNotEmpty || _dirtyCollections.contains('settings')) {
        if (!await _storageService.saveSettings(currentUser!.uid, settingsData)) success = false;
      }

      if (success) {
        await _storageService.setLastModified(currentUser!.uid, settings.lastModified);
        _dirtyCollections.clear();
        _hasUnsavedChanges = false;
        _lastSuccessfulSaveTimestamp = DateTime.now();
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