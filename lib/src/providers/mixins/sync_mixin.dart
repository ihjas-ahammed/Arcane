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

  /// Bumped on every edit. A cloud push remembers the value it started with, so edits made while
  /// it was running stay marked as unsaved instead of being wiped when the push finishes.
  int _editGeneration = 0;
  Timer? _cloudRetryTimer;
  
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

  /// True while an edit is waiting for its (near-immediate) local-cache write.
  bool get hasPendingLocalSave => _saveDebounce?.isActive ?? false;

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

  /// Set when the saved state could not be read. While it is set nothing is written to the local
  /// database or the cloud, so the broken data stays as it is until the user fixes it.
  LocalStateException? localLoadError;
  bool _syncStarted = false;

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
    if (_syncStarted) return;
    _syncStarted = true;
    SharedPreferences.getInstance().then((prefs) {
      _cloudSyncPending = prefs.getBool(_cloudSyncPendingKey) ?? false;
      // The app died (or was offline) mid-push last time: finish the job now.
      if (_cloudSyncPending && currentUser != null && !_dataLoadInProgress && !_isSyncing) {
        _scheduleCloudRetry();
      }
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
    _cloudRetryTimer?.cancel();
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
    _editGeneration++;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleLocalSave();
  }

  // Every state change funnels through notifyListeners, so every change reaches the local cache.
  // Bursts are merged inside _saveLocalSnapshot, so no timer is needed here.
  void _scheduleLocalSave() {
    if (_dataLoadInProgress || currentUser == null) return;
    unawaited(_saveLocalSnapshot());
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

  bool _localSaveRunning = false;
  bool _localSaveAgain = false;

  Future<void> _saveLocalSnapshot({bool forceFlush = false, Map<String, dynamic>? precomputedState}) async {
    if (currentUser == null || _dataLoadInProgress || localLoadError != null) return;
    // One serialization pass at a time: edits that arrive meanwhile are folded into a single
    // follow-up save, so a burst of taps can't queue several multi-MB encodes behind each other.
    if (_localSaveRunning && precomputedState == null && !forceFlush) {
      _localSaveAgain = true;
      return;
    }
    // A flush (app pausing, before a cloud push) must leave the newest state on disk: wait for
    // the save in flight, then write again.
    for (var i = 0; forceFlush && _localSaveRunning && i < 250; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _localSaveRunning = true;
    try {
      // Reuse a just-built state map when the caller already has one instead of re-running
      // getFullAppState()'s full serialization pass.
      final fullData = precomputedState ?? getFullAppState();
      await _localStorageService.saveState(currentUser!.uid, fullData);
    } catch (e) {
      debugPrint("Local snapshot failed: $e. Retrying shortly.");
      // Never give up on the local copy: try again until the write goes through.
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(seconds: 2), _saveLocalSnapshot);
    } finally {
      _localSaveRunning = false;
      if (_localSaveAgain) {
        _localSaveAgain = false;
        unawaited(_saveLocalSnapshot());
      }
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
  /// timestamp back and reported through a progress notification.
  ///
  /// It keeps retrying (backoff capped at 5 minutes) until the cloud holds everything, unless
  /// [maxAttempts] is given. If the app dies first, the pending flag is persisted and the push is
  /// resumed on the next start / when connectivity returns.
  ///
  /// This is strictly one-way: local data is never replaced by anything from the cloud, and the
  /// local cache is not rewritten from the (possibly minutes-old) payload that was uploaded.
  /// Never throws; returns whether the cloud now holds the current local state.
  Future<bool> syncEndOfDay({bool showNotification = true, int? maxAttempts}) async {
    if (currentUser == null || _dataLoadInProgress || localLoadError != null) return false;
    if (!settings.autoSaveEnabled) return false;
    if (_isSyncing) {
      // A push is already running: queue exactly one more so the newest state is also pushed.
      _endOfDaySyncQueued = true;
      return false;
    }
    _isSyncing = true;
    _cloudRetryTimer?.cancel();
    notifyListeners();
    final notif = NotificationService.instance;
    final uid = currentUser!.uid;
    try {
      // Local cache first: whatever happens next, nothing is lost on this device.
      _saveDebounce?.cancel();
      await _saveLocalSnapshot(forceFlush: true);
      await _setCloudSyncPending(true);

      for (var attempt = 1; maxAttempts == null || attempt <= maxAttempts; attempt++) {
        if (currentUser == null || currentUser!.uid != uid) return false; // signed out / switched
        if (showNotification) {
          await notif.showCloudSyncNotification(
            body: attempt == 1 ? 'Backing up your day to the cloud…' : 'Retrying (attempt $attempt)…',
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
        if (showNotification) {
          await notif.showCloudSyncNotification(
            body: 'Your data is safe on this device. Still trying to reach the cloud…',
            failed: true,
          );
        }
        if (maxAttempts != null && attempt >= maxAttempts) break;
        final waitSecs = (5 * (1 << (attempt < 6 ? attempt : 6))).clamp(10, 300);
        await Future.delayed(Duration(seconds: waitSecs));
      }
      _scheduleCloudRetry();
      return false;
    } catch (e) {
      debugPrint("[SyncMixin] syncEndOfDay error: $e");
      _scheduleCloudRetry();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_endOfDaySyncQueued) {
        _endOfDaySyncQueued = false;
        unawaited(syncEndOfDay(showNotification: showNotification, maxAttempts: maxAttempts));
      }
    }
  }

  /// Backstop for a push that gave up (bounded attempts, unexpected error): try again in a minute.
  void _scheduleCloudRetry() {
    _cloudRetryTimer?.cancel();
    _cloudRetryTimer = Timer(const Duration(minutes: 1), () {
      if (_cloudSyncPending && currentUser != null && !_dataLoadInProgress && !_isSyncing) {
        unawaited(syncEndOfDay());
      }
    });
  }

  /// Manual "sync" buttons. Upload only: it never pulls cloud data over the local copy (use the
  /// explicit restore in settings for that).
  Future<void> performManualSync() async {
    if (currentUser == null || _isSyncing || _dataLoadInProgress) return;
    final success = await manuallySaveToCloud();
    if (!success) _scheduleCloudRetry();
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
      // Keep a copy of exactly what's on this device before anything from the cloud is merged in.
      _saveDebounce?.cancel();
      await _saveLocalSnapshot(forceFlush: true);
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
    if (localLoadError != null) {
      showGlobalToast("Local data could not be loaded, so nothing is uploaded until it is fixed.");
      return false;
    }
    if (_isSyncing) {
      _endOfDaySyncQueued = true;
      showGlobalToast("A cloud sync is already running");
      return false;
    }
    final success = await syncEndOfDay(showNotification: false, maxAttempts: 3);
    if (success) {
      showGlobalToast("Data successfully synced to cloud");
    } else {
      showGlobalToast("Cloud unreachable. Your data is safe here and will keep retrying.");
    }
    return success;
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
    if (currentUser == null || _dataLoadInProgress || localLoadError != null) return false;
    try {
      final startGeneration = _editGeneration;
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
        _lastSuccessfulSaveTimestamp = DateTime.now();
        // Only forget the edits this push actually carried. Anything changed while it was
        // running stays marked, and one more push is queued for it.
        if (_editGeneration == startGeneration) {
          _dirtyCollections.clear();
          _hasUnsavedChanges = false;
        } else {
          _endOfDaySyncQueued = true;
        }
        // Deliberately NO local write here: the payload above is a snapshot from when the push
        // started (it can be minutes old), and writing it back would erase newer local edits.
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      return false;
    }
  }
}