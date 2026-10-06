import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin SyncMixin on ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  final Set<String> _dirtyCollections = {};
  bool _hasUnsavedChanges = false;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;

  StorageService get storageService => _storageService;

  void setManuallyLoading(bool value) {
    _isManuallyLoading = value;
    notifyListeners();
  }

  Timer? _saveDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  /// True when there are local edits that have not yet been pushed to the cloud.
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  static const String _cloudSyncPendingKey = 'cloud_sync_pending_v1';

  /// Set when an end-of-day push failed (offline, server error). Persisted so a
  /// restart still retries; cleared only after a verified successful push.
  bool _cloudSyncPending = false;
  bool get cloudSyncPending => _cloudSyncPending;
  bool _endOfDaySyncQueued = false;

  /// True while the signed-in user's data is being loaded, or the in-memory state reset.
  /// Nothing may be saved or marked dirty in that window: a save would write default or partial
  /// state to the local cache (with a fresh timestamp), and the next sync would push it over the
  /// real cloud data. Crash restarts made this window common.
  bool _dataLoadInProgress = false;

  void beginDataLoad() {
    _dataLoadInProgress = true;
    _saveDebounce?.cancel();
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
  dynamic mergeAppStateFromMap(Map<String, dynamic> rawData);

  /// Cloud sync is NOT realtime. Every change is saved to the local cache only; the cloud is
  /// written once a day when the daily briefing is generated ([syncEndOfDay]) or when the user
  /// taps a manual sync button. This only wires up the "retry a failed end-of-day sync once we're
  /// back online" hook.
  void initSync() {
    SharedPreferences.getInstance().then((prefs) {
      _cloudSyncPending = prefs.getBool(_cloudSyncPendingKey) ?? false;
    }).catchError((_) {});

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _cloudSyncPending && currentUser != null && !_dataLoadInProgress && !_isSyncing) {
        debugPrint("[SyncMixin] Back online with a pending end-of-day sync. Retrying.");
        syncEndOfDay();
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _connectivitySubscription?.cancel();
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
    // Local cache only. Debounced so bursts of edits cost a single serialization pass.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveLocalSnapshot);
    notifyListeners();
  }

  /// Kept for call-site compatibility: saves locally, never touches the network.
  void scheduleRealtimeSync() {
    _saveLocalSnapshot();
  }

  Future<void> forceLocalBackup() async {
    _saveDebounce?.cancel();
    await _saveLocalSnapshot(forceFlush: true);
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

  Future<void> _setCloudSyncPending(bool value) async {
    _cloudSyncPending = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cloudSyncPendingKey, value);
    } catch (_) {}
  }

  /// The single automatic cloud write: a full, forced push of every collection (tasks, history,
  /// reflections, finance, health, trading, launcher, settings), verified by reading the cloud
  /// timestamp back, retried with backoff, and reported through a progress notification. If it
  /// still fails the work is marked pending and retried when connectivity returns.
  /// Never throws; returns whether the cloud now holds the current local state.
  Future<bool> syncEndOfDay({bool showNotification = true}) async {
    if (currentUser == null || _dataLoadInProgress) return false;
    if (!settings.autoSaveEnabled) return false;
    if (_isSyncing) {
      // A push is already running: queue exactly one more so the newest state is also pushed.
      _endOfDaySyncQueued = true;
      return false;
    }
    _isSyncing = true;
    notifyListeners();
    final notif = NotificationService.instance;
    try {
      // Local cache first: whatever happens next, nothing is lost on this device.
      _saveDebounce?.cancel();
      await _saveLocalSnapshot(forceFlush: true);
      await _setCloudSyncPending(true);

      const maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (showNotification) {
          await notif.showCloudSyncNotification(
            body: attempt == 1 ? 'Backing up your day to the cloud…' : 'Retrying (attempt $attempt of $maxAttempts)…',
          );
        }
        final ok = await _performActualSaveInternal(
          force: true,
          onProgress: (done, total, label) {
            if (showNotification) {
              notif.showCloudSyncNotification(body: label, done: done, total: total);
            }
          },
        );
        if (ok) {
          await _setCloudSyncPending(false);
          if (showNotification) {
            await notif.showCloudSyncNotification(body: 'Everything is safely backed up.', finished: true);
          }
          return true;
        }
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: 2 << attempt));
        }
      }
      if (showNotification) {
        await notif.showCloudSyncNotification(
          body: 'Your data is safe on this device. Will retry when you are back online.',
          failed: true,
        );
      }
      return false;
    } catch (e) {
      debugPrint("[SyncMixin] syncEndOfDay error: $e");
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_endOfDaySyncQueued) {
        _endOfDaySyncQueued = false;
        unawaited(syncEndOfDay(showNotification: showNotification));
      }
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

  Map<String, dynamic> getTaskStateMap() => {};
  Map<String, dynamic> getFinanceStateMap() => {};
  Map<String, dynamic> getUserStateMap() => {};
  Map<String, dynamic> getHealthStateMap() => {};
  Map<String, dynamic> getTradingStateMap() => {};
  Map<String, dynamic> getLauncherStateMap() => {};

  Future<bool> _manuallyLoadFromCloudInternal() async {
    final cloudData = await _storageService.getUserData(currentUser!.uid);
    if (cloudData != null && cloudData.isNotEmpty) {
      // Load under the guard so the setters don't re-stamp the cloud data as a local change.
      final nested = _dataLoadInProgress;
      _dataLoadInProgress = true;
      _saveDebounce?.cancel();
      try {
        mergeAppStateFromMap(cloudData);
      } finally {
        _dataLoadInProgress = nested;
      }
      _hasUnsavedChanges = false;
      _dirtyCollections.clear();

      // Ensure local settings.lastModified matches or exceeds remote RTDB timestamp
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
        await _setCloudSyncPending(false);
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

  Future<bool> _performActualSaveInternal({
    bool force = false,
    void Function(int done, int total, String label)? onProgress,
  }) async {
    if (currentUser == null || _dataLoadInProgress) return false;
    try {
      // 1. Establish a single synchronized timestamp across all collections and RTDB
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      settings.lastModified = nowTs;

      final tasksData = Map<String, dynamic>.from(getTaskStateMap());
      final financeData = Map<String, dynamic>.from(getFinanceStateMap());
      final healthData = Map<String, dynamic>.from(getHealthStateMap());
      final tradingData = Map<String, dynamic>.from(getTradingStateMap());
      final launcherData = Map<String, dynamic>.from(getLauncherStateMap());
      final userState = Map<String, dynamic>.from(getUserStateMap());

      final appData = <String, dynamic>{
        ...tasksData,
        ...financeData,
        ...userState,
        ...healthData,
        'trading': tradingData,
        'launcher': launcherData,
      };

      final historyData = {'completedByDay': appData['completedByDay'] ?? {}};
      final reflectionsData = {'reflectionLogs': appData['reflectionLogs'] ?? []};
      
      // Exclude completedByDay from tasksData so it is not duplicated as a massive 5MB+ payload
      tasksData.remove('completedByDay');

      final settingsData = Map<String, dynamic>.from(userState);
      settingsData.remove('reflectionLogs');
      settingsData['lastSuccessfulSaveTimestamp'] = DateTime.now().toIso8601String();

      // Catch-all for any future or top-level keys in appData not explicitly categorized above
      final categorizedKeys = <String>{
        ...tasksData.keys,
        ...financeData.keys,
        ...healthData.keys,
        ...tradingData.keys,
        ...launcherData.keys,
        'trading',
        'launcher',
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
      const totalSteps = 9;
      var step = 0;
      void tick(String label) => onProgress?.call(++step, totalSteps, label);

      if (force || _dirtyCollections.contains('tasks')) {
        if (!await _storageService.saveTasks(currentUser!.uid, tasksData)) success = false;
        tick('Tasks & projects');
      }
      if (force || _dirtyCollections.contains('history')) {
        if (!await _storageService.saveHistory(currentUser!.uid, historyData)) success = false;
        tick('History');
      }
      if (force || _dirtyCollections.contains('reflections')) {
        if (!await _storageService.saveReflections(currentUser!.uid, reflectionsData)) success = false;
        tick('Reflections');
      }
      if (force || _dirtyCollections.contains('finance')) {
        if (!await _storageService.saveFinance(currentUser!.uid, financeData)) success = false;
        tick('Finance');
      }
      if (force || _dirtyCollections.contains('health')) {
        if (!await _storageService.saveHealth(currentUser!.uid, healthData)) success = false;
        tick('Health');
      }
      if (force || _dirtyCollections.contains('trading')) {
        if (!await _storageService.saveTrading(currentUser!.uid, tradingData)) success = false;
        tick('Trading');
      }
      if (force || _dirtyCollections.contains('launcher')) {
        final hasLauncherItems = launcherData.isNotEmpty &&
            ((launcherData['dock'] as List?)?.isNotEmpty == true ||
             (launcherData['home'] as List?)?.isNotEmpty == true ||
             (launcherData['widgets'] as List?)?.isNotEmpty == true ||
             (launcherData['folders'] as List?)?.isNotEmpty == true);
        if ((hasLauncherItems || _dirtyCollections.contains('launcher')) && launcherData.isNotEmpty) {
          if (!await _storageService.saveLauncher(currentUser!.uid, launcherData)) success = false;
        }
        tick('Launcher');
      }
      if (force || _dirtyCollections.isNotEmpty || _dirtyCollections.contains('settings')) {
        if (!await _storageService.saveSettings(currentUser!.uid, settingsData)) success = false;
      }
      tick('Settings');

      if (LauncherNative.isSupported) {
        try {
          final crashLogs = await LauncherNative.getCrashLog();
          if (crashLogs.isNotEmpty) {
            await _storageService.saveCrashLogs(currentUser!.uid, crashLogs);
          }
        } catch (_) {}
      }

      if (success) {
        await _storageService.setLastModified(currentUser!.uid, nowTs);
        // Verify the cloud really holds this save before declaring everything synced.
        final confirmedTs = await _storageService.getLastModified(currentUser!.uid);
        if (confirmedTs != nowTs) {
          debugPrint("[SyncMixin] Cloud timestamp verification failed ($confirmedTs != $nowTs).");
          return false;
        }
        tick('Verified');
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