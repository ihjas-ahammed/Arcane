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
    _headSubscription?.cancel();
    _headSubscription = null;
    _headWatchUid = null;
    _remoteHeadVersion = null;
    _conflictPullNeeded = false;
    _conflictPulls = 0;
    _pullRetryTimer?.cancel();
  }

  Future<void> maybeAutomaticCloudBackup() async {
    if (!_dataLoadInProgress && settings.autoSaveEnabled && cloudBaseline != null) unawaited(ensureWeeklyOffsiteBackup());
    if (!_hasUnsavedChanges || _dataLoadInProgress || cloudAttachRequired || localLoadError != null) return;
    if (settings.alwaysWriteCloud) {
      await syncEndOfDay(showNotification: false, maxAttempts: 1);
      return;
    }
    if (!settings.autoSaveEnabled) return;
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

  /// Starts cloud sync. With "Realtime Sync" on (the default) every edit is pushed a moment after
  /// it is made, and a snapshot committed by another device is merged into this one as soon as
  /// the cloud announces it ([_pullRemoteChanges]). With it off, the cloud is written every six
  /// hours, after the daily briefing, and from the manual sync button.
  void initSync() {
    _watchCloudHead();
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
      } else if (isOnline) {
        unawaited(_pullRemoteChanges());
      }
    });
  }

  StreamSubscription<String?>? _headSubscription;
  String? _headWatchUid;
  String? _remoteHeadVersion;
  bool _remotePullRunning = false;
  bool _conflictPullNeeded = false;
  int _conflictPulls = 0;
  Timer? _pullRetryTimer;

  /// When another device's snapshot was last merged into this one.
  DateTime? lastRemoteMerge;

  /// Listens to the small `head/version` value. It changes exactly once per committed snapshot,
  /// so this costs a few bytes per change and nothing while idle.
  void _watchCloudHead() {
    final uid = currentUser?.uid;
    if (uid == null || uid == _headWatchUid) return;
    _headSubscription?.cancel();
    _headWatchUid = uid;
    _remoteHeadVersion = null;
    try {
      _headSubscription = storageService.watchHeadVersion(uid).listen((version) {
        if (currentUser?.uid != uid || version == null || version.isEmpty) return;
        _remoteHeadVersion = version;
        unawaited(_pullRemoteChanges());
      }, onError: (Object e) {
        debugPrint('[SyncMixin] Cloud head listener error: $e');
        _headWatchUid = null;
      });
    } catch (e) {
      debugPrint('[SyncMixin] Cloud head listener unavailable: $e');
      _headWatchUid = null;
    }
  }

  /// Runs after a remote snapshot was merged; lets the provider wait for parts that load async.
  Future<void> afterRemoteMerge() async {}

  /// Realtime pull. Merges a snapshot committed by another device into the state in memory.
  ///
  /// Nothing local is replaced: this is the same record-by-record merge as "Merge from cloud" in
  /// Settings (tombstones, preserved conflicts), a full copy of this device's state is written
  /// to backups/ first, and local edits that the cloud does not hold yet are pushed afterwards.
  /// It never runs before this device is attached to the cloud (no baseline), while data is
  /// loading, or while local data is unreadable.
  Future<void> _pullRemoteChanges({bool force = false}) async {
    final user = currentUser;
    if (user == null || !settings.alwaysWriteCloud) return;
    if (_dataLoadInProgress || localLoadError != null || cloudAttachRequired || failedCollections.isNotEmpty) return;
    if (cloudBaseline == null) return;
    if (!force && (_remoteHeadVersion == null || _remoteHeadVersion == cloudBaselineVersion)) return;
    // A push or pull in flight re-checks from its own finally block.
    if (_isSyncing || _remotePullRunning || _isManuallyLoading) return;
    final uid = user.uid;
    _remotePullRunning = true;
    _isSyncing = true;
    _pullRetryTimer?.cancel();
    notifyListeners();
    try {
      final snapshot = await storageService.getUserSnapshot(uid);
      if (currentUser?.uid != uid || snapshot == null) return;
      final remoteVersion = snapshot['version'] as String?;
      final remoteTs = (snapshot['lastModified'] as num?)?.toInt() ?? 0;
      if (remoteVersion == cloudBaselineVersion && remoteTs <= (cloudBaseline ?? 0)) return;
      final cloudData = snapshot['state'] as Map<String, dynamic>?;
      if (cloudData == null || cloudData.isEmpty) return;
      // Keep a copy of exactly what's on this device before anything from the cloud is merged in.
      _saveDebounce?.cancel();
      await _localStorageService.writeSnapshot(uid, getFullAppState(), 'before_realtime');
      await _saveLocalSnapshot(forceFlush: true);
      if (currentUser?.uid != uid || _dataLoadInProgress || localLoadError != null || cloudAttachRequired) return;
      final hadLocalEdits = _hasUnsavedChanges;
      // Merge under the load guard so the setters don't re-stamp cloud data as a local change.
      // The merge is synchronous, so no edit can land in the middle of it.
      _dataLoadInProgress = true;
      _confirmedFullLoadDepth++;
      try {
        mergeAppStateFromMap(cloudData);
      } finally {
        _confirmedFullLoadDepth--;
        _dataLoadInProgress = false;
      }
      await afterRemoteMerge();
      if (currentUser?.uid != uid) return;
      if (failedCollections.isNotEmpty) {
        cloudSyncError = 'Some records could not be read and were preserved: ${failedCollections.join(', ')}. Cloud upload is paused until they are repaired.';
      }
      await persistCloudBaseline(remoteTs, version: remoteVersion);
      _hasUnsavedChanges = hadLocalEdits || _hasUnsavedChanges;
      await _saveLocalSnapshot(forceFlush: true);
      lastRemoteMerge = DateTime.now();
    } catch (e) {
      debugPrint('[SyncMixin] Realtime pull failed: $e');
      _pullRetryTimer = Timer(const Duration(minutes: 1), () => unawaited(_pullRemoteChanges(force: force)));
    } finally {
      _remotePullRunning = false;
      _isSyncing = false;
      notifyListeners();
      if ((_endOfDaySyncQueued || _hasUnsavedChanges) && currentUser?.uid == uid && failedCollections.isEmpty) {
        _endOfDaySyncQueued = false;
        unawaited(syncEndOfDay(showNotification: false, maxAttempts: 3, manual: _pendingManualCloudSync));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _saveDebounce?.cancel();
    _alwaysWriteTimer?.cancel();
    _cloudRetryTimer?.cancel();
    _pullRetryTimer?.cancel();
    _headSubscription?.cancel();
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
    if (settings.alwaysWriteCloud) _scheduleAlwaysWrite();
    notifyListeners();
  }

  Timer? _alwaysWriteTimer;

  /// "Realtime Sync": a push two seconds after the last edit.
  void _scheduleAlwaysWrite() {
    if (currentUser == null || _dataLoadInProgress || localLoadError != null || cloudAttachRequired) return;
    _alwaysWriteTimer?.cancel();
    _alwaysWriteTimer = Timer(const Duration(seconds: 2), () {
      unawaited(syncEndOfDay(showNotification: false, maxAttempts: 3));
    });
  }

  /// Full-state loads (replacing or merging everything) are allowed only inside an explicit
  /// confirmation made in Settings. Startup loads from this device's own database do not use this.
  int _confirmedFullLoadDepth = 0;
  /// Test-only switch so merge logic can be exercised without the Settings confirmation.
  static bool debugAllowFullLoads = false;

  Future<T> runConfirmedFullLoad<T>(Future<T> Function() action) async {
    _confirmedFullLoadDepth++;
    try {
      return await action();
    } finally {
      _confirmedFullLoadDepth--;
    }
  }

  void requireConfirmedFullLoad(String operation) {
    if (_confirmedFullLoadDepth == 0 && !debugAllowFullLoads) {
      throw StateError('$operation is blocked. Full-state loads run only after you confirm them in Settings.');
    }
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
    if (!manual && !settings.autoSaveEnabled && !settings.alwaysWriteCloud) return false;
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
        if (!ok && (cloudSyncError != null || _conflictPullNeeded)) return false;
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
      if (_conflictPullNeeded) {
        // Another device committed first: merge its snapshot, then the pull pushes the result.
        _conflictPullNeeded = false;
        unawaited(_pullRemoteChanges(force: true));
      } else if (_endOfDaySyncQueued) {
        _endOfDaySyncQueued = false;
        unawaited(syncEndOfDay(showNotification: showNotification, maxAttempts: maxAttempts, manual: _pendingManualCloudSync));
      } else {
        unawaited(_pullRemoteChanges());
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
    requireConfirmedFullLoad('Loading from cloud');
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
      _conflictPulls = 0;
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
      // Realtime sync resolves "another device committed first" by merging that snapshot and
      // uploading again. Bounded, so a conflict that merging cannot clear is shown instead.
      if (e.remoteAdvanced && settings.alwaysWriteCloud && cloudBaseline != null && currentUser?.uid == uid && _conflictPulls < 3) {
        _conflictPulls++;
        _conflictPullNeeded = true;
        return false;
      }
      if (currentUser?.uid == uid) cloudSyncError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      return false;
    }
  }
}
