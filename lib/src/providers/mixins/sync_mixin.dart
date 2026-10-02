import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  Timer? _periodicSyncTimer;
  StreamSubscription<int>? _realtimeSyncSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
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

  /// Initializes background realtime sync listeners, connectivity detection, and periodic sync.
  void initSync() {
    stopRealtimeSyncListener();
    if (currentUser != null) {
      startRealtimeSyncListener();
    }

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (currentUser != null && settings.autoSaveEnabled && !_dataLoadInProgress && !_isSyncing) {
        autoSyncWithCloud();
      }
    });

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && currentUser != null && settings.autoSaveEnabled && !_dataLoadInProgress) {
        debugPrint("[SyncMixin] Network connectivity restored. Running background sync.");
        if (_hasUnsavedChanges) {
          _scheduleCloudSave();
        }
        autoSyncWithCloud();
      }
    });
  }
  
  /// Subscribes to real-time changes in the cloud lastModified timestamp and pulls immediately.
  void startRealtimeSyncListener() {
    if (currentUser == null) return;
    _realtimeSyncSubscription?.cancel();
    final uid = currentUser!.uid;
    _realtimeSyncSubscription = _storageService.watchLastModified(uid).listen((remoteTs) async {
      if (currentUser == null || currentUser!.uid != uid || _dataLoadInProgress || _isSyncing) return;
      if (remoteTs <= 0) return;

      // CRITICAL DATA PROTECTION: Never overwrite uncommitted local user changes in background!
      if (_hasUnsavedChanges || _dirtyCollections.isNotEmpty) {
        debugPrint("[SyncMixin] Realtime sync: Local has unsaved changes. Scheduling cloud push instead of pulling.");
        if (settings.autoSaveEnabled) {
          _scheduleCloudSave();
        }
        return;
      }

      final localTs = settings.lastModified;
      if (remoteTs > localTs) {
        debugPrint("[SyncMixin] Realtime sync: Remote is newer ($remoteTs > $localTs). Auto-pulling updates in background.");
        await _manuallyLoadFromCloudInternal();
      } else if (localTs > remoteTs) {
        if (settings.autoSaveEnabled) {
          debugPrint("[SyncMixin] Realtime sync: Local is newer ($localTs >= $remoteTs). Scheduling cloud save.");
          _scheduleCloudSave();
        }
      }
    }, onError: (e) {
      debugPrint("[SyncMixin] Realtime sync error: $e");
    });
  }

  void stopRealtimeSyncListener() {
    _realtimeSyncSubscription?.cancel();
    _realtimeSyncSubscription = null;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _cloudDebounce?.cancel();
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    stopRealtimeSyncListener();
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
    _cloudDebounce = Timer(const Duration(milliseconds: 2500), () async {
      if (currentUser != null && _hasUnsavedChanges && !_isSyncing && !_dataLoadInProgress) {
        _isSyncing = true;
        try {
          await _performActualSaveInternal(force: true);
        } finally {
          _isSyncing = false;
          notifyListeners();
        }
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
      await _performActualSaveInternal();
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
    if (currentUser == null || _isSyncing || _dataLoadInProgress) return;

    _isSyncing = true;
    notifyListeners();

    try {
      if (_hasUnsavedChanges || _dirtyCollections.isNotEmpty) {
        // User has local edits: prioritize saving local changes to cloud
        final success = await _performActualSaveInternal(force: true);
        if (success) {
          showGlobalToast("Local changes synced to cloud");
        } else {
          showGlobalToast("Failed to sync some changes to cloud");
        }
        return;
      }

      final localTs = settings.lastModified;
      final remoteTs = await _storageService.getLastModified(currentUser!.uid);
      if (remoteTs > localTs) {
        final success = await _manuallyLoadFromCloudInternal();
        if (success) {
          showGlobalToast("Synced latest data from cloud");
        } else {
          showGlobalToast("Failed to pull latest cloud data");
        }
      } else {
        final success = await _performActualSaveInternal(force: true);
        if (success) {
          showGlobalToast("Data synchronized with cloud");
        } else {
          showGlobalToast("Failed to sync some data to cloud");
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
      showGlobalToast("Sync failed: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Automatically compares remote vs local timestamps on login or startup and synchronizes in the background.
  Future<void> autoSyncWithCloud() async {
    if (currentUser == null || _isSyncing || _dataLoadInProgress) return;
    _isSyncing = true;
    try {
      if (_hasUnsavedChanges || _dirtyCollections.isNotEmpty) {
        debugPrint("[SyncMixin] autoSyncWithCloud: Local has unsaved changes. Syncing to cloud.");
        await _performActualSaveInternal(force: true);
        return;
      }

      final localTs = settings.lastModified;
      final remoteTs = await _storageService.getLastModified(currentUser!.uid);
      if (remoteTs > localTs) {
        debugPrint("[SyncMixin] Remote cloud data is newer ($remoteTs > $localTs). Pulling updates.");
        await _manuallyLoadFromCloudInternal();
      } else if (localTs > remoteTs) {
        debugPrint("[SyncMixin] Local changes newer ($localTs > $remoteTs). Syncing to cloud.");
        await _performActualSaveInternal(force: true);
      }
    } catch (e) {
      debugPrint("[SyncMixin] autoSyncWithCloud error: $e");
    } finally {
      _isSyncing = false;
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

      // Ensure local settings.lastModified matches or exceeds remote RTDB timestamp
      // to prevent an immediate desync loop
      try {
        final remoteTs = await _storageService.getLastModified(currentUser!.uid);
        if (remoteTs > settings.lastModified) {
          settings.lastModified = remoteTs;
        }
      } catch (_) {}

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
      // 1. Establish a single synchronized timestamp across all collections and RTDB
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      settings.lastModified = nowTs;

      final tasksData = Map<String, dynamic>.from(getTaskStateMap());
      final financeData = Map<String, dynamic>.from(getFinanceStateMap());
      final healthData = Map<String, dynamic>.from(getHealthStateMap());
      final tradingData = Map<String, dynamic>.from(getTradingStateMap());
      final userState = Map<String, dynamic>.from(getUserStateMap());

      final appData = <String, dynamic>{
        ...tasksData,
        ...financeData,
        ...userState,
        ...healthData,
        'trading': tradingData,
      };

      final historyData = {'completedByDay': appData['completedByDay'] ?? {}};
      final reflectionsData = {'reflectionLogs': appData['reflectionLogs'] ?? []};
      
      final settingsData = Map<String, dynamic>.from(userState);
      settingsData.remove('reflectionLogs');
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
        ...userState.keys,
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
        await _storageService.setLastModified(currentUser!.uid, nowTs);
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