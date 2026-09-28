import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/utils/global_toast.dart';

mixin SyncMixin on ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  final Set<String> _dirtyCollections = {};
  bool _hasUnsavedChanges = false;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;

  Timer? _saveDebounce;
  Timer? _cloudDebounce;
  
  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// True while the signed-in user's data is being loaded, or the in-memory state reset.
  /// Nothing may be saved or marked dirty in that window: a save would write default or partial
  /// state to the local cache (with a fresh timestamp), and the next sync would push it over the
  /// real cloud data. Crash restarts made this window common.
  bool _dataLoadInProgress = false;

  void beginDataLoad() {
    _dataLoadInProgress = true;
    _saveDebounce?.cancel();
    _cloudDebounce?.cancel();
  }

  /// Ends a load/reset: what's in memory now is the saved state, so nothing is pending.
  void endDataLoad() {
    _dataLoadInProgress = false;
    _dirtyCollections.clear();
    _hasUnsavedChanges = false;
  }

  AppUser? get currentUser;
  AppSettings get settings;
  Map<String, dynamic> getFullAppState(); 
  void loadStateFromMap(Map<String, dynamic> data);

  // App is offline-first with automatic background cloud sync when autoSaveEnabled is true.
  void initSync() {}
  
  void startRealtimeSyncListener() {}

  void stopRealtimeSyncListener() {}

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _cloudDebounce?.cancel();
    super.dispose();
  }

  void markDirty(String collection) {
    if (_dataLoadInProgress) {
      // Setters fired by the load itself: keep the loaded timestamp, save nothing.
      notifyListeners();
      return;
    }
    settings.lastModified = DateTime.now().millisecondsSinceEpoch;
    _dirtyCollections.add(collection);
    _hasUnsavedChanges = true;
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveLocalSnapshot);

    if (currentUser != null && settings.autoSaveEnabled) {
      _scheduleCloudSave();
    }
  }

  void _scheduleCloudSave() {
    _cloudDebounce?.cancel();
    _cloudDebounce = Timer(const Duration(milliseconds: 2500), () {
      if (currentUser != null && _hasUnsavedChanges && !_isSyncing) {
        _performActualSaveInternal();
      }
    });
  }

  void scheduleRealtimeSync() {
    _saveLocalSnapshot();
    if (currentUser != null && settings.autoSaveEnabled) {
      _scheduleCloudSave();
    }
  }

  Future<void> syncIfDirty() async {
    // Kept for backward compatibility, currently offline default
  }

  Future<void> forceLocalBackup() async {
    await _saveLocalSnapshot(forceFlush: true);
    if (currentUser != null && settings.autoSaveEnabled && _hasUnsavedChanges) {
      _performActualSaveInternal();
    }
    notifyListeners();
  }

  Future<void> _saveLocalSnapshot({bool forceFlush = false, Map<String, dynamic>? precomputedState}) async {
    if (currentUser == null || _dataLoadInProgress) return;
    try {
      // Reuse a just-built state map when the caller already has one (e.g. right after a
      // cloud save) instead of re-running getFullAppState()'s full serialization pass.
      final fullData = precomputedState ?? getFullAppState();
      await _localStorageService.saveState(currentUser!.uid, fullData);
    } catch (e) {
      debugPrint("Local snapshot failed: $e");
    }
  }

  Future<void> performManualSync() async {
    if (currentUser == null || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    final localTs = settings.lastModified;
    try {
      final remoteTs = await _storageService.getLastModified(currentUser!.uid);
      if (remoteTs > localTs) {
        await _manuallyLoadFromCloudInternal();
      } else if (localTs > remoteTs || _hasUnsavedChanges) {
        await _performActualSaveInternal(force: true);
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Automatically compares remote vs local timestamps on login or startup and synchronizes in the background.
  Future<void> autoSyncWithCloud() async {
    if (currentUser == null || _isSyncing) return;
    // Compare against the timestamp of the data as loaded. Startup maintenance runs while the
    // remote timestamp is being fetched and re-stamps it with "now", which made stale local data
    // look newer than the cloud and get pushed over it.
    final localTs = settings.lastModified;
    try {
      final remoteTs = await _storageService.getLastModified(currentUser!.uid);
      if (remoteTs > localTs) {
        debugPrint("[SyncMixin] Remote cloud data is newer ($remoteTs > $localTs). Pulling updates.");
        await _manuallyLoadFromCloudInternal();
      } else if (localTs > remoteTs || _hasUnsavedChanges) {
        debugPrint("[SyncMixin] Local changes newer ($localTs >= $remoteTs). Syncing to cloud.");
        await _performActualSaveInternal();
      }
    } catch (e) {
      debugPrint("[SyncMixin] autoSyncWithCloud error: $e");
    }
  }

  Map<String, dynamic> getTaskStateMap() => {};
  Map<String, dynamic> getFinanceStateMap() => {};
  Map<String, dynamic> getUserStateMap() => {};
  Map<String, dynamic> getHealthStateMap() => {};
  Map<String, dynamic> getTradingStateMap() => {};

  Future<bool> _manuallyLoadFromCloudInternal() async {
    final cloudData = await _storageService.getUserData(currentUser!.uid);
    if (cloudData != null && cloudData.isNotEmpty) {
      // Load under the guard so the setters don't re-stamp the cloud data as a local change.
      final nested = _dataLoadInProgress;
      _dataLoadInProgress = true;
      _saveDebounce?.cancel();
      _cloudDebounce?.cancel();
      try {
        loadStateFromMap(cloudData);
      } finally {
        _dataLoadInProgress = nested;
      }
      _hasUnsavedChanges = false;
      _dirtyCollections.clear();
      // Inside an outer load the caller persists once it ends.
      if (!nested) await _saveLocalSnapshot(forceFlush: true);
      return true;
    }
    return false;
  }

  Future<bool> manuallySaveToCloud() async {
    if (currentUser == null) return false;
    _isSyncing = true;
    notifyListeners();
    try {
      final success = await _performActualSaveInternal(force: true);
      if (success) {
        showGlobalToast("Data successfully synced to cloud");
      } else {
        showGlobalToast("Failed to sync some data to cloud");
      }
      return success;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> manuallyLoadFromCloud() async {
    if (currentUser == null) return false;
    _isManuallyLoading = true;
    notifyListeners();
    try {
      final success = await _manuallyLoadFromCloudInternal();
      if (success) {
        showGlobalToast("Data restored from cloud");
      } else {
        showGlobalToast("No cloud data found or restore failed");
      }
      return success;
    } finally {
      _isManuallyLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _performActualSaveInternal({bool force = false}) async {
    if (currentUser == null || _dataLoadInProgress) return false;
    try {
      final appData = getFullAppState();
      
      final tasksData = Map<String, dynamic>.from(getTaskStateMap());
      final historyData = {'completedByDay': appData['completedByDay'] ?? {}};
      final reflectionsData = {'reflectionLogs': appData['reflectionLogs'] ?? []};
      final financeData = Map<String, dynamic>.from(getFinanceStateMap());
      final healthData = Map<String, dynamic>.from(getHealthStateMap());
      final tradingData = Map<String, dynamic>.from(getTradingStateMap());
      
      final settingsData = Map<String, dynamic>.from(getUserStateMap());
      settingsData['lastSuccessfulSaveTimestamp'] = DateTime.now().toIso8601String();

      // Catch-all for any future or top-level keys in appData not explicitly categorized above
      final categorizedKeys = <String>{
        ...tasksData.keys,
        ...financeData.keys,
        ...healthData.keys,
        ...tradingData.keys,
        'trading',
        'completedByDay',
        'reflectionLogs',
        ...getUserStateMap().keys,
      };

      appData.forEach((key, value) {
        if (!categorizedKeys.contains(key)) {
          settingsData[key] = value;
        }
      });

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
      if (force || _dirtyCollections.contains('trading')) {
        if (!await _storageService.saveTrading(currentUser!.uid, tradingData)) success = false;
      }
      if (force || _dirtyCollections.isNotEmpty || _dirtyCollections.contains('settings')) {
        if (!await _storageService.saveSettings(currentUser!.uid, settingsData)) success = false;
      }

      if (success) {
        await _storageService.setLastModified(currentUser!.uid, settings.lastModified);
        _dirtyCollections.clear();
        _hasUnsavedChanges = false;
        _lastSuccessfulSaveTimestamp = DateTime.now();
        // appData was already built above for the cloud save — reuse it here instead of
        // calling getFullAppState() (a full serialization pass over the entire app state)
        // a second time back-to-back.
        await _saveLocalSnapshot(forceFlush: true, precomputedState: appData);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      return false;
    }
  }
}