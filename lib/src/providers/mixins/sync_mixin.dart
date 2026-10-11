import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:missions/src/services/state_database.dart';
import 'package:missions/src/services/cloud_snapshot_store.dart';
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

Uint8List _gzipSnapshot(Map<String, dynamic> state) => Uint8List.fromList(GZipEncoder().encode(utf8.encode(jsonEncode(state)))!);

mixin SyncMixin on ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();

  final Set<String> _dirtyCollections = {};
  bool _hasUnsavedChanges = false;
  final Set<String> _localDirtyCollections = {};
  final Set<String> failedCollections = {};
  final List<Map<String, dynamic>> mergeConflicts = [];
  final Map<String, Map<String, int>> tombstones = {};
  final Map<String, dynamic> protectedCollections = {};
  final List<Map<String, dynamic>> quarantine = [];
  int? cloudBaseline;
  String? cloudBaselineVersion;
  bool cloudAttachRequired = false;
  bool cloudAttachHasLocalData = false;
  String? cloudSyncError;
  bool allowConfirmedShrink = false;
  Timer? _periodicCloudTimer;
  bool _offsiteRunning = false;
  String? offsiteBackupError;
  String _deviceId = '';

  void preserveMergeConflict(String collection, String id, Map<String, dynamic> local, Map<String, dynamic> incoming) {
    if (jsonEncode(local) == jsonEncode(incoming)) return;
    if (mergeConflicts.any((c) => c['collection'] == collection && c['id'] == id && jsonEncode(c['incoming']) == jsonEncode(incoming))) return;
    mergeConflicts.add({'collection': collection, 'id': id, 'local': local, 'incoming': incoming});
  }

  void recordDeletions(String collection, Iterable<String> before, Iterable<String> after) {
    if (_dataLoadInProgress) return;
    final remaining = after.toSet();
    for (final id in before.where((id) => !remaining.contains(id))) {
      tombstones.putIfAbsent(collection, () => {})[id] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  void mergeRemoteTombstones(Map<String, dynamic> data) {
    final raw = data['tombstones'];
    if (raw is! Map) return;
    for (final collection in raw.entries) {
      final local = tombstones.putIfAbsent(collection.key.toString(), () => {});
      for (final e in (collection.value as Map).entries) {
        final ts = (e.value as num).toInt();
        if (ts > (local[e.key.toString()] ?? 0)) local[e.key.toString()] = ts;
      }
    }
  }

  bool isDeletedRecord(String collection, String id) => tombstones[collection]?.containsKey(id) ?? false;

  List<T> parseItems<T>(String collection, dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) throw FormatException('$collection must be a list');
    final result = <T>[];
    for (var i = 0; i < raw.length; i++) {
      try {
        result.add(parse(Map<String, dynamic>.from(raw[i] as Map)));
      } catch (e) {
        failedCollections.add(collection);
        protectedCollections[collection] = raw;
        quarantine.add({'collection': collection, 'index': i, 'raw': raw[i], 'error': e.toString()});
      }
    }
    return result;
  }

  Future<void> persistCloudBaseline(int timestamp, {String? version}) async {
    final user = currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (currentUser?.uid != user.uid) return;
    await prefs.setInt('cloud_baseline_${user.uid}', timestamp);
    await prefs.setString('cloud_baseline_version_${user.uid}', version ?? '');
    if (!kIsWeb) await StateDatabase.instance.setMeta(user.uid, 'cloudBaseline', '$timestamp');
    if (!kIsWeb) await StateDatabase.instance.setMeta(user.uid, 'cloudBaselineVersion', version ?? '');
    if (currentUser?.uid == user.uid) { cloudBaseline = timestamp; cloudBaselineVersion = version; }
  }

  Future<void> loadCloudBaseline() async {
    final user = currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (currentUser?.uid != user.uid) return;
    await prefs.setString('active_energy_user', user.uid);
    cloudBaseline = prefs.getInt('cloud_baseline_${user.uid}');
    cloudBaselineVersion = prefs.getString('cloud_baseline_version_${user.uid}');
    if (!kIsWeb) {
      final stored = await StateDatabase.instance.getMeta(user.uid, 'cloudBaseline');
      if (currentUser?.uid != user.uid) return;
      if (stored != null) cloudBaseline = int.tryParse(stored);
      final storedVersion = await StateDatabase.instance.getMeta(user.uid, 'cloudBaselineVersion');
      if (currentUser?.uid != user.uid) return;
      if (storedVersion != null) cloudBaselineVersion = storedVersion;
    }
    if (cloudBaselineVersion?.isEmpty == true) cloudBaselineVersion = null;
    _cloudSyncPending = prefs.getBool('cloud_sync_pending_v2_${user.uid}') ?? false;
    _pendingManualCloudSync = prefs.getBool('cloud_pending_manual_${user.uid}') ?? false;
    _hasUnsavedChanges |= prefs.getBool('cloud_dirty_${user.uid}') ?? _cloudSyncPending;
    cloudSyncError = prefs.getString('cloud_sync_error_${user.uid}');
    final last = prefs.getString('last_cloud_push_${user.uid}');
    _lastSuccessfulSaveTimestamp = last == null ? null : DateTime.tryParse(last);
    _deviceId = prefs.getString('cloud_device_id') ?? const Uuid().v4();
    await prefs.setString('cloud_device_id', _deviceId);
  }

  Future<void> ensureWeeklyOffsiteBackup() async {
    final user = currentUser;
    if (user == null || _offsiteRunning || cloudAttachRequired || localLoadError != null) return;
    final now = DateTime.now();
    final week = now.subtract(Duration(days: now.weekday - 1)).toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('offsite_week_${user.uid}') == week) return;
    _offsiteRunning = true;
    try {
      final bytes = await compute(_gzipSnapshot, getFullAppState());
      await storageService.saveOffsiteSnapshot(user.uid, bytes, week);
      await prefs.setString('offsite_week_${user.uid}', week);
      try { await storageService.snapshots.prune(user.uid); } catch (e) { debugPrint('Cloud pruning deferred: $e'); }
      if (currentUser?.uid == user.uid) offsiteBackupError = null;
    } catch (e) {
      if (currentUser?.uid == user.uid) offsiteBackupError = 'Weekly offsite backup failed: $e';
    } finally { _offsiteRunning = false; notifyListeners(); }
  }

  void resetSyncState() {
    _saveDebounce?.cancel();
    _cloudRetryTimer?.cancel();
    _localDirtyCollections.clear();
    _dirtyCollections.clear();
    _hasUnsavedChanges = false;
    _endOfDaySyncQueued = false;
    failedCollections.clear();
    mergeConflicts.clear();
    tombstones.clear();
    protectedCollections.clear();
    quarantine.clear();
    localLoadError = null;
    cloudBaseline = null;
    cloudBaselineVersion = null;
    cloudAttachRequired = false;
    cloudAttachHasLocalData = false;
    cloudSyncError = null;
    allowConfirmedShrink = false;
    _lastSuccessfulSaveTimestamp = null;
    offsiteBackupError = null;
    _cloudSyncPending = false;
    _pendingManualCloudSync = false;
  }

  Future<void> maybeAutomaticCloudBackup() async {
    if (!_dataLoadInProgress && settings.autoSaveEnabled && cloudBaseline != null) unawaited(ensureWeeklyOffsiteBackup());
    if (!_hasUnsavedChanges || _dataLoadInProgress || cloudAttachRequired || localLoadError != null || !settings.autoSaveEnabled) return;
    if (_lastSuccessfulSaveTimestamp == null || DateTime.now().difference(_lastSuccessfulSaveTimestamp!) >= const Duration(hours: 6)) {
      await syncEndOfDay(showNotification: false, maxAttempts: 1);
    }
  }

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

  String get _cloudSyncPendingKey => 'cloud_sync_pending_v2_${currentUser?.uid ?? 'signed_out'}';

  /// Set when an end-of-day push failed (offline, server error). Persisted so a
  /// restart still retries; cleared only after a verified successful push.
  bool _cloudSyncPending = false;
  bool get cloudSyncPending => _cloudSyncPending;
  bool _endOfDaySyncQueued = false;
  bool _pendingManualCloudSync = false;

  /// True while the signed-in user's data is being loaded, or the in-memory state reset.
  /// Nothing may be saved or marked dirty in that window: a save would write default or partial
  /// state to the local cache (with a fresh timestamp), and the next sync would push it over the
  /// real cloud data. Crash restarts made this window common.
  bool _dataLoadInProgress = false;
  bool get dataLoadInProgress => _dataLoadInProgress;

  /// Set when the saved state could not be read. While it is set nothing is written to the local
  /// database or the cloud, so the broken data stays as it is until the user fixes it.
  LocalStateException? localLoadError;
  bool _syncStarted = false;
  bool _disposed = false;

  void beginDataLoad() {
    _dataLoadInProgress = true;
    _saveDebounce?.cancel();
  }

  /// Ends a load/reset: what's in memory now is the saved state, so nothing is pending.
  void endDataLoad({bool hasUnsavedChanges = false}) {
    _dataLoadInProgress = false;
    _dirtyCollections.clear();
    _localDirtyCollections.clear();
    _hasUnsavedChanges = hasUnsavedChanges;
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
    _periodicCloudTimer = Timer.periodic(const Duration(minutes: 10), (_) => unawaited(maybeAutomaticCloudBackup()));
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
    _disposed = true;
    _saveDebounce?.cancel();
    _cloudRetryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _periodicCloudTimer?.cancel();
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
    _localDirtyCollections.add(collection);
    _localDirtyCollections.add('settings');
    _hasUnsavedChanges = true;
    _editGeneration++;
    _scheduleLocalSave();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // Only data edits schedule a write. UI notifications never serialize state.
  void _scheduleLocalSave() {
    if (_dataLoadInProgress || currentUser == null || localLoadError != null || cloudAttachRequired) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () => unawaited(_saveLocalSnapshot()));
  }

  /// Kept for call-site compatibility: saves locally, never touches the network.
  void scheduleRealtimeSync() {
    _saveLocalSnapshot();
  }

  Future<void> forceLocalBackup() async {
    _saveDebounce?.cancel();
    await _saveLocalSnapshot(forceFlush: true);
    await LocalStorageService.flushPendingSaves();
  }

  bool _localSaveRunning = false;
  bool _localSaveAgain = false;

  Future<void> _saveLocalSnapshot({bool forceFlush = false, Map<String, dynamic>? precomputedState}) async {
    if (currentUser == null || _dataLoadInProgress || localLoadError != null || cloudAttachRequired) return;
    // One serialization pass at a time: edits that arrive meanwhile are folded into a single
    // follow-up save, so a burst of taps can't queue several multi-MB encodes behind each other.
    if (_localSaveRunning && precomputedState == null && !forceFlush) {
      _localSaveAgain = true;
      return;
    }
    // A flush (app pausing, before a cloud push) must leave the newest state on disk: wait for
    // the save in flight, then write again.
    while (forceFlush && _localSaveRunning) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _localSaveRunning = true;
    try {
      // Reuse a just-built state map when the caller already has one instead of re-running
      // getFullAppState()'s full serialization pass.
      final uid = currentUser!.uid;
      final generation = _editGeneration;
      final dirty = Set<String>.from(_localDirtyCollections);
      final fullData = precomputedState ?? (forceFlush ? getFullAppState() : _localChanges(dirty));
      await _localStorageService.saveState(uid, fullData, partial: !forceFlush && precomputedState == null);
      if (_hasUnsavedChanges && currentUser?.uid == uid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cloud_dirty_$uid', true);
      }
      if (currentUser?.uid == uid && _editGeneration == generation) _localDirtyCollections.removeAll(dirty);
    } catch (e) {
      debugPrint("Local snapshot failed: $e. Retrying shortly.");
      if (forceFlush) rethrow;
      // Preserve the failure in the UI and stop an endless write retry loop.
      localLoadError = LocalStateException('Local data could not be saved.', e.toString());
      notifyListeners();
      _saveDebounce?.cancel();
    } finally {
      _localSaveRunning = false;
      if (_localSaveAgain) {
        _localSaveAgain = false;
        unawaited(_saveLocalSnapshot());
      }
    }
  }

  Map<String, dynamic> _localChanges(Set<String> dirty) {
    final result = <String, dynamic>{};
    if (dirty.contains('tasks')) {
      final tasks = getTaskStateMap()..remove('completedByDay');
      result.addAll(tasks);
    }
    if (dirty.contains('settings')) result.addAll(getTaskSessionStateMap());
    if (dirty.contains('history')) result.addAll(getHistoryStateMap());
    if (dirty.contains('finance')) result.addAll(getFinanceStateMap());
    if (dirty.contains('health')) result.addAll(getHealthStateMap());
    if (dirty.contains('trading')) result['trading'] = getTradingStateMap();
    if (dirty.contains('launcher')) result['launcher'] = getLauncherStateMap();
    if (dirty.contains('settings') || dirty.contains('reflections')) {
      final user = getUserStateMap(includeReflections: dirty.contains('reflections'));
      if (!dirty.contains('reflections')) user.remove('reflectionLogs');
      result.addAll(user);
    }
    result.addAll(protectedCollections);
    if (quarantine.isNotEmpty) result['_quarantine'] = quarantine;
    return result;
  }

  Future<void> _setCloudSyncPending(bool value) async {
    _cloudSyncPending = value;
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cloud_sync_pending_v2_$uid', value);
      await prefs.setBool('cloud_pending_manual_$uid', value && _pendingManualCloudSync);
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
  Future<bool> syncEndOfDay({bool showNotification = true, int? maxAttempts, bool manual = false}) async {
    if (currentUser == null || _dataLoadInProgress || localLoadError != null || cloudAttachRequired || failedCollections.isNotEmpty) return false;
    if (!manual && !settings.autoSaveEnabled) return false;
    if (_isSyncing) {
      // A push is already running: queue exactly one more so the newest state is also pushed.
      _endOfDaySyncQueued = true;
      _pendingManualCloudSync |= manual;
      return false;
    }
    _pendingManualCloudSync |= manual;
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
        if (!ok && cloudSyncError != null) return false;
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
        unawaited(syncEndOfDay(showNotification: showNotification, maxAttempts: maxAttempts, manual: _pendingManualCloudSync));
      }
    }
  }

  /// Backstop for a push that gave up (bounded attempts, unexpected error): try again in a minute.
  void _scheduleCloudRetry() {
    _cloudRetryTimer?.cancel();
    _cloudRetryTimer = Timer(const Duration(minutes: 1), () {
      if (_cloudSyncPending && currentUser != null && !_dataLoadInProgress && !_isSyncing) {
        unawaited(syncEndOfDay(manual: _pendingManualCloudSync));
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
  Map<String, dynamic> getUserStateMap({bool includeReflections = true}) => {};
  Map<String, dynamic> getTaskSessionStateMap() => {};
  Map<String, dynamic> getHistoryStateMap() => {};
  Map<String, dynamic> getHealthStateMap() => {};
  Map<String, dynamic> getTradingStateMap() => {};
  Map<String, dynamic> getLauncherStateMap() => {};

  Future<bool> _manuallyLoadFromCloudInternal() async {
    final uid = currentUser!.uid;
    final snapshot = await storageService.getUserSnapshot(uid);
    final cloudData = snapshot?['state'] as Map<String, dynamic>?;
    if (currentUser?.uid != uid) return false;
    if (cloudData != null && cloudData.isNotEmpty) {
      // Keep a copy of exactly what's on this device before anything from the cloud is merged in.
      _saveDebounce?.cancel();
      await _localStorageService.writeSnapshot(currentUser!.uid, getFullAppState(), 'before_restore');
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
        final remoteTs = await storageService.getLastModified(currentUser!.uid);
        if (remoteTs > settings.lastModified) {
          settings.lastModified = remoteTs;
        }
      } catch (_) {}

      if (failedCollections.isNotEmpty) throw StateError('Cloud snapshot contains unreadable records.');
      await persistCloudBaseline((snapshot!['lastModified'] as num).toInt(), version: snapshot['version'] as String?);
      cloudAttachRequired = false;
      localLoadError = null;
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
    final success = await syncEndOfDay(showNotification: false, maxAttempts: 3, manual: true);
    if (success) unawaited(ensureWeeklyOffsiteBackup());
    if (success) {
      showGlobalToast("Data successfully synced to cloud");
    } else {
      showGlobalToast(cloudSyncError ?? "Cloud unreachable. Your data is safe here and will keep retrying.");
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
    if (currentUser == null || _dataLoadInProgress || localLoadError != null || cloudAttachRequired || failedCollections.isNotEmpty) return false;
    final uid = currentUser!.uid;
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

      onProgress?.call(0, 1, 'Uploading and verifying snapshot');
      await loadCloudBaseline();
      if (currentUser?.uid != uid || _dataLoadInProgress) return false;
      cloudSyncError = null;
      if (cloudBaseline == null) {
        final remote = await storageService.getLastModified(currentUser!.uid);
        if (remote > 0) throw const CloudConflictException('Restore or merge existing cloud data before uploading from this device.');
        await persistCloudBaseline(0);
      }
      final saved = await storageService.saveSnapshot(uid, {
        'tasks': tasksData, 'history': historyData, 'reflections': reflectionsData,
        'finance': financeData, 'health': healthData, 'trading': tradingData,
        'launcher': launcherData, 'settings': settingsData,
      }, baseline: cloudBaseline!, baselineVersion: cloudBaselineVersion, deviceId: _deviceId, allowShrink: allowConfirmedShrink);
      if (currentUser?.uid != uid) return false;
      final committedTs = (saved['lastModified'] as num).toInt();
      await persistCloudBaseline(committedTs, version: saved['version'] as String?);
      allowConfirmedShrink = false;
      onProgress?.call(1, 1, 'Cloud snapshot committed');

      if (LauncherNative.isSupported) {
        try {
          final crashLogs = await LauncherNative.getCrashLog();
          if (crashLogs.isNotEmpty) {
            await storageService.saveCrashLogs(currentUser!.uid, crashLogs);
          }
        } catch (_) {}
      }

      {
        _lastSuccessfulSaveTimestamp = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_cloud_push_${currentUser!.uid}', _lastSuccessfulSaveTimestamp!.toIso8601String());
        await prefs.remove('cloud_sync_error_${currentUser!.uid}');
        unawaited(ensureWeeklyOffsiteBackup());
        // Only forget the edits this push actually carried. Anything changed while it was
        // running stays marked, and one more push is queued for it.
        if (_editGeneration == startGeneration) {
          _dirtyCollections.clear();
          _hasUnsavedChanges = false;
          await prefs.setBool('cloud_dirty_$uid', false);
        } else {
          await prefs.setBool('cloud_dirty_$uid', true);
          _endOfDaySyncQueued = true;
        }
        // Deliberately NO local write here: the payload above is a snapshot from when the push
        // started (it can be minutes old), and writing it back would erase newer local edits.
        return true;
      }
    } on CloudConflictException catch (e) {
      if (currentUser?.uid == uid) cloudSyncError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      return false;
    }
  }
}
