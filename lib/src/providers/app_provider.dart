import 'package:flutter/foundation.dart';
import 'package:arcane/src/services/firebase_service.dart' as fb_service;
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/services/local_storage_service.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/utils/time_validation_helper.dart';

import 'package:arcane/src/providers/actions/task_actions.dart';
import 'package:arcane/src/providers/actions/ai_generation_actions.dart';
import 'package:arcane/src/providers/actions/timer_actions.dart';
import 'package:arcane/src/providers/actions/project_actions.dart';
import 'package:arcane/src/providers/actions/report_actions.dart';
import 'package:arcane/src/services/ai_service.dart';

class AppProvider with ChangeNotifier, WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final AIService _aiService = AIService();

  AIService get aiService => _aiService;

  Timer? _autoSaveTimer;
  Timer? _realtimeSyncDebouncer;

  String? _loadingTaskName;
  String? get loadingTaskName => _loadingTaskName;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _authLoading = true;
  bool get authLoading => _authLoading;
  
  bool _isSyncing = false; 
  bool get isSyncing => _isSyncing;
  bool get isDataLoadingAfterLogin => false;

  bool _isUsernameMissing = false;
  bool get isUsernameMissing => _isUsernameMissing;

  String? _lastLoginDate;
  List<MainTask> _mainTasks =
      initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
  Map<String, dynamic> _completedByDay = {};

  List<Skill> _skills = [];
  List<Skill> get skills => _skills;
  List<ReflectionLog> _reflectionLogs = [];
  List<ReflectionLog> get reflectionLogs => _reflectionLogs;

  // Values feature removed

  AppSettings _settings = AppSettings();
  String? _selectedTaskId;
  int _apiKeyIndex = 0;
  Map<String, ActiveTimerInfo> _activeTimers = {};

  final Set<String> _dirtyCollections = {};

  bool _hasUnsavedChanges = false;
  bool _isManuallySaving = false;
  bool get isManuallySaving => _isManuallySaving;
  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;
  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  bool _isGeneratingSubquestsForTask = false;
  bool get isGeneratingSubquests => _isGeneratingSubquestsForTask;

  String? get lastLoginDate => _lastLoginDate;
  List<MainTask> get mainTasks => _mainTasks;
  Map<String, dynamic> get completedByDay => _completedByDay;

  AppSettings get settings => _settings;
  String? get selectedTaskId => _selectedTaskId;
  int get apiKeyIndex => _apiKeyIndex;
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;

  ChatbotMemory _chatbotMemory = ChatbotMemory();
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  bool _isChatbotMemoryInitialized = false;

  late final TaskActions _taskActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;
  late final ProjectActions _projectActions;
  late final ReportActions _reportActions;

  AppProvider() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _projectActions = ProjectActions(this);
    _reportActions = ReportActions(this);
    _initializeSkills();
    _initialize();
    
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _realtimeSyncDebouncer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_hasUnsavedChanges && _currentUser != null) {
        _saveLocalSnapshot(forceFlush: true);
        if (_settings.autoSaveEnabled) {
          _performActualSave();
        }
      }
    }
  }

  // --- ACTIONS EXPOSURE ---
  void addMainTask({required String name, required String description, required String theme, required String colorHex}) =>
      _taskActions.addMainTask(name: name, description: description, theme: theme, colorHex: colorHex);
  void editMainTask(String taskId, {required String name, required String description, required String theme, required String colorHex}) =>
      _taskActions.editMainTask(taskId, name: name, description: description, theme: theme, colorHex: colorHex);
  void logToDailySummary(String type, Map<String, dynamic> data) => _taskActions.logToDailySummary(type, data);
  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) => _taskActions.addSubtask(mainTaskId, subtaskData);
  void updateSubtask(String mainTaskId, String subtaskId, Map<String, dynamic> updates) => _taskActions.updateSubtask(mainTaskId, subtaskId, updates);
  bool addSessionToSubtask(String mainTaskId, String subTaskId, DateTime start, DateTime end) => _taskActions.addSessionToSubtask(mainTaskId, subTaskId, start, end);
  void updateSessionInSubtask(String mainTaskId, String subTaskId, String sessionId, DateTime newStart, DateTime newEnd) => _taskActions.updateSessionInSubtask(mainTaskId, subTaskId, sessionId, newStart, newEnd);
  void deleteSessionFromSubtask(String mainTaskId, String subTaskId, String sessionId) => _taskActions.deleteSessionFromSubtask(mainTaskId, subTaskId, sessionId);
  bool completeSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) => _taskActions.completeSubtask(mainTaskId, subtaskId, fromSync: fromSync);
  void uncompleteSubtask(String mainTaskId, String subtaskId) => _taskActions.uncompleteSubtask(mainTaskId, subtaskId);
  void deleteSubtask(String mainTaskId, String subtaskId) => _taskActions.deleteSubtask(mainTaskId, subtaskId);
  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) => _taskActions.duplicateCompletedSubtask(mainTaskId, subtaskId);
  void addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData) => _taskActions.addSubSubtask(mainTaskId, parentSubtaskId, subSubtaskData);
  void updateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, Map<String, dynamic> updates) => _taskActions.updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
  void completeSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) => _taskActions.completeSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) => _taskActions.uncompleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void deleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) => _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) => _taskActions.reorderSubtasks(mainTaskId, oldIndex, newIndex);
  void startTimer(String id, String type, String mainTaskId) => _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);

  // Expose Proxies
  Future<void> triggerAISubquestGeneration(MainTask mainTask, String generationMode, String userInput, int numSubquests) =>
      _aiGenerationActions.triggerAISubquestGeneration(mainTask, generationMode, userInput, numSubquests);

  ProjectActions get projectActions => _projectActions;
  TaskActions get taskActions => _taskActions;
  AIGenerationActions get aiGenerationActions => _aiGenerationActions;
  ReportActions get reportActions => _reportActions;

  // --- INITIALIZATION ---

  void _initializeSkills() {
    if (_skills.isEmpty) {
      _skills = [
        Skill(id: 'wis', name: 'Wisdom', description: 'Good judgment, learning, perspective.'),
        Skill(id: 'cou', name: 'Courage', description: 'Bravery, persistence, integrity.'),
        Skill(id: 'hum', name: 'Humanity', description: 'Love, kindness, social intelligence.'),
        Skill(id: 'jus', name: 'Justice', description: 'Teamwork, fairness, leadership.'),
        Skill(id: 'tem', name: 'Temperance', description: 'Forgiveness, humility, self-regulation.'),
        Skill(id: 'tra', name: 'Transcendence', description: 'Appreciation of beauty, gratitude, hope.'),
      ];
    }
  }

  Future<void> _initialize() async {
    fb_service.authStateChanges.listen(_onAuthStateChanged);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_hasUnsavedChanges &&
          _currentUser != null &&
          !_isManuallySaving &&
          !_isManuallyLoading &&
          _settings.autoSaveEnabled) {
        _performActualSave();
      }
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (_authLoading && _currentUser != null && user != null && _currentUser!.uid == user.uid) return;
    
    _authLoading = true;
    notifyListeners();

    if (user != null) {
      _currentUser = user;
      
      // 1. Try Load Local Cache First (Instant UI)
      final localData = await _localStorageService.loadState();
      bool loadedLocal = false;
      if (localData != null) {
        _loadStateFromMap(localData);
        loadedLocal = true;
        
        _hasUnsavedChanges = false;
        _cleanOverlappingSessions();
        _fixTimerAnomalies();
        _handleDailyReset();
        
        _authLoading = false;
        notifyListeners();
      }

      _isUsernameMissing = _currentUser?.displayName == null || _currentUser!.displayName!.trim().isEmpty;
      _isChatbotMemoryInitialized = false;
      initializeChatbotMemory();

      // 2. Fetch Cloud Data in Background
      _isSyncing = true;
      if (loadedLocal) notifyListeners();

      try {
        final cloudData = await _storageService.getUserData(user.uid);
        if (cloudData != null) {
          int cloudTs = cloudData['settings']?['lastModified'] ?? 0;
          
          if (!loadedLocal || cloudTs > _settings.lastModified) {
            _loadStateFromMap(cloudData);
            _hasUnsavedChanges = false;
            // Offload initial local save to avoid UI jank
            _saveLocalSnapshot(forceFlush: true);
          } else if (loadedLocal && _settings.lastModified > cloudTs) {
            _hasUnsavedChanges = true;
            _scheduleRealtimeSync();
          }
        } else if (!loadedLocal) {
          await _resetToInitialState();
          _lastLoginDate = helper.getTodayDateString();
          _hasUnsavedChanges = true;
          await _performActualSave();
        }
        _cleanOverlappingSessions();
        _fixTimerAnomalies();
        _handleDailyReset();
      } catch (e) {
        debugPrint("Cloud sync init failed: $e");
      } finally {
        _isSyncing = false;
        _authLoading = false;
        notifyListeners();
      }

    } else {
      _currentUser = null;
      await _resetToInitialState();
      await _localStorageService.clearState();
      _hasUnsavedChanges = false;
      _isChatbotMemoryInitialized = false;
      _authLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLocalSnapshot({bool forceFlush = false}) async {
    try {
      final fullData = getAppStateAsMap();
      // LocalStorageService now uses compute/isolate internally to avoid blocking UI
      await _localStorageService.saveState(fullData);
      
      if (forceFlush) {
        if (Platform.isAndroid || Platform.isWindows) {
          final docsDir = await getApplicationDocumentsDirectory();
          final backupDir = Directory('${docsDir.path}/backups');
          if (!await backupDir.exists()) await backupDir.create(recursive: true);
          
          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
          final file = File('${backupDir.path}/backup_$timestamp.json');
          
          // Offload encoding to isolate for backup as well
          final jsonString = await compute((Map<String, dynamic> data) => jsonEncode(data), fullData);
          await file.writeAsString(jsonString);
          
          final files = backupDir.listSync().whereType<File>().toList();
          files.sort((a, b) => a.path.compareTo(b.path));
          if (files.length > 5) {
            for (var i = 0; i < files.length - 5; i++) {
              await files[i].delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Local snapshot failed: $e");
    }
  }

  Future<void> _performActualSave() async {
    if (_currentUser != null) {
      bool isAutoSave = !_isManuallySaving;
      if (!isAutoSave) setLoadingTask("Syncing Database...");
      _isSyncing = true;
      notifyListeners();

      try {
        // Awaiting here ensures local cache is updated, but since it's async/isolate, UI won't freeze
        await _saveLocalSnapshot();

        bool success = true;
        final nowTs = DateTime.now().millisecondsSinceEpoch;
        _settings.lastModified = nowTs;

        if (_dirtyCollections.isNotEmpty) {
          if (_dirtyCollections.contains('tasks')) {
            if (!await _storageService.saveTasks(_currentUser!.uid, {
              'mainTasks': _mainTasks.map((mt) => mt.toJson()).toList()
            })) success = false;
          }
          if (_dirtyCollections.contains('history')) {
            if (!await _storageService.saveHistory(
                _currentUser!.uid, {'completedByDay': _completedByDay}))
              success = false;
          }
          if (_dirtyCollections.contains('reflections')) {
            if (!await _storageService.saveReflections(_currentUser!.uid, {
              'reflectionLogs': _reflectionLogs.map((l) => l.toJson()).toList()
            })) success = false;
          }
          
          if (_dirtyCollections.contains('settings') || success) {
             final settingsData = {
                'lastLoginDate': _lastLoginDate,
                'settings': settings.toJson(),
                'selectedTaskId': _selectedTaskId,
                'apiKeyIndex': _apiKeyIndex,
                'activeTimers': _activeTimers.map((key, value) => MapEntry(key, value.toJson())),
                'lastSuccessfulSaveTimestamp': DateTime.now().toIso8601String(),
                'chatbotMemory': _chatbotMemory.toJson(),
                'skills': _skills.map((s) => s.toJson()).toList(),
              };
              if (!await _storageService.saveSettings(_currentUser!.uid, settingsData)) success = false;
          }
          if (success) _dirtyCollections.clear();
        }

        if (success) {
          _lastSuccessfulSaveTimestamp = DateTime.now();
          _hasUnsavedChanges = false;
        }
      } finally {
        _isSyncing = false;
        if (!isAutoSave) setLoadingTask(null);
        notifyListeners();
      }
    }
  }

  void _scheduleRealtimeSync() {
    // Fire local save immediately (async/isolate) but don't await to block UI thread logic flow if called from sync functions
    _saveLocalSnapshot(); 
    
    if (!_settings.autoSaveEnabled || _currentUser == null || _isManuallyLoading) return;
    if (_realtimeSyncDebouncer?.isActive ?? false) {
      _realtimeSyncDebouncer!.cancel();
    }
    _realtimeSyncDebouncer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges && !_isManuallySaving) {
        _performActualSave();
      }
    });
  }

  void _markDirty(String collection) {
    _dirtyCollections.add(collection);
    _hasUnsavedChanges = true;
    _settings.lastModified = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> getAppStateAsMap() {
    return {
      'lastLoginDate': _lastLoginDate,
      'mainTasks': _mainTasks.map((mt) => mt.toJson()).toList(),
      'completedByDay': _completedByDay,
      'settings': settings.toJson(),
      'selectedTaskId': _selectedTaskId,
      'apiKeyIndex': _apiKeyIndex,
      'activeTimers': _activeTimers.map((key, value) => MapEntry(key, value.toJson())),
      'lastSuccessfulSaveTimestamp': _lastSuccessfulSaveTimestamp?.toIso8601String(),
      'chatbotMemory': _chatbotMemory.toJson(),
      'skills': _skills.map((s) => s.toJson()).toList(),
      'reflectionLogs': _reflectionLogs.map((l) => l.toJson()).toList(),
    };
  }

  void loadAppStateFromMap(Map<String, dynamic> data) {
    _loadStateFromMap(data);
    _saveLocalSnapshot(forceFlush: true);
    _hasUnsavedChanges = true;
    _markDirty('settings');
    _scheduleRealtimeSync();
    notifyListeners();
  }

  void _loadStateFromMap(Map<String, dynamic> data) {
    _lastLoginDate = data['lastLoginDate'] as String?;
    _mainTasks = (data['mainTasks'] as List<dynamic>?)
            ?.map((mtJson) => MainTask.fromJson(mtJson as Map<String, dynamic>))
            .toList() ??
        initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    _completedByDay = data['completedByDay'] as Map<String, dynamic>? ?? {};
    _completedByDay.forEach((date, dayDataMap) {
      if (dayDataMap is Map<String, dynamic>) {
        dayDataMap.putIfAbsent('taskTimes', () => <String, int>{});
        dayDataMap.putIfAbsent('subtasksCompleted', () => <Map<String, dynamic>>[]);
        dayDataMap.putIfAbsent('checkpointsCompleted', () => <Map<String, dynamic>>[]);
      }
    });
    
    _settings = data['settings'] != null
        ? AppSettings.fromJson(data['settings'] as Map<String, dynamic>)
        : AppSettings();
    
    _selectedTaskId = data['selectedTaskId'] as String? ?? (_mainTasks.isNotEmpty ? _mainTasks[0].id : null);
    _apiKeyIndex = data['apiKeyIndex'] as int? ?? 0;
    _activeTimers = (data['activeTimers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, ActiveTimerInfo.fromJson(value as Map<String, dynamic>))) ??
        {};
    
    final timestampString = data['lastSuccessfulSaveTimestamp'] as String?;
    _lastSuccessfulSaveTimestamp = timestampString != null ? DateTime.tryParse(timestampString) : null;
    
    _chatbotMemory = data['chatbotMemory'] != null
        ? ChatbotMemory.fromJson(data['chatbotMemory'] as Map<String, dynamic>)
        : ChatbotMemory();
    
    if (data['skills'] != null && data['skills'] is List) {
      _skills = (data['skills'] as List)
          .where((s) => s != null && s is Map<String, dynamic>)
          .map((s) => Skill.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    if (_skills.isEmpty) _initializeSkills();

    if (data['reflectionLogs'] != null && data['reflectionLogs'] is List) {
      _reflectionLogs = (data['reflectionLogs'] as List)
          .where((l) => l != null && l is Map<String, dynamic>)
          .map((l) => ReflectionLog.fromJson(l as Map<String, dynamic>))
          .toList();
    }

    _isChatbotMemoryInitialized = true;
    if (_settings.dataVersion < 1) {
      _settings.dataVersion = 1;
      _hasUnsavedChanges = true; 
    }
  }

  void setProviderState(
      {String? lastLoginDate,
      List<MainTask>? mainTasks,
      Map<String, dynamic>? completedByDay,
      Map<String, ActiveTimerInfo>? activeTimers,
      DateTime? lastSuccessfulSaveTimestamp,
      bool? isUsernameMissing,
      ChatbotMemory? chatbotMemory,
      bool doNotify = true,
      bool doPersist = true}) {
    bool changed = false;
    if (lastLoginDate != null && _lastLoginDate != lastLoginDate) {
      _lastLoginDate = lastLoginDate;
      changed = true;
    }
    if (mainTasks != null && !listEquals(_mainTasks, mainTasks)) {
      _mainTasks = List.from(mainTasks);
      changed = true;
    }
    if (completedByDay != null && !mapEquals(_completedByDay, completedByDay)) {
      _completedByDay = Map.from(completedByDay);
      changed = true;
    }
    if (activeTimers != null && !mapEquals(_activeTimers, activeTimers)) {
      _activeTimers = Map.from(activeTimers);
      changed = true;
    }
    if (lastSuccessfulSaveTimestamp != null &&
        _lastSuccessfulSaveTimestamp != lastSuccessfulSaveTimestamp) {
      _lastSuccessfulSaveTimestamp = lastSuccessfulSaveTimestamp;
      changed = true;
    }
    if (isUsernameMissing != null && _isUsernameMissing != isUsernameMissing) {
      _isUsernameMissing = isUsernameMissing;
      changed = true;
    }
    if (chatbotMemory != null && _chatbotMemory != chatbotMemory) {
      _chatbotMemory = chatbotMemory;
      changed = true;
    }
    if (changed) {
      if (doPersist) {
        if (mainTasks != null) _markDirty('tasks');
        if (completedByDay != null) _markDirty('history');
        if (lastLoginDate != null || activeTimers != null || lastSuccessfulSaveTimestamp != null || chatbotMemory != null) _markDirty('settings');
        
        _scheduleRealtimeSync();
      }
      if (doNotify) notifyListeners();
    }
  }

  void _fixTimerAnomalies() {
    final runningTimers = _activeTimers.entries.where((e) => e.value.isRunning).toList();
    if (runningTimers.length > 1) {
      runningTimers.sort((a, b) => b.value.startTime.compareTo(a.value.startTime));
      for (var entry in runningTimers.sublist(1)) {
        _timerActions.pauseTimer(entry.key);
      }
      _markDirty('settings');
      _scheduleRealtimeSync();
    }
  }

  void setSettings(AppSettings newSettings) {
    _settings = newSettings;
    _markDirty('settings');
    _scheduleRealtimeSync();
    notifyListeners();
  }
  
  void setSelectedTaskId(String? taskId) {
    if (_selectedTaskId != taskId) {
      _selectedTaskId = taskId;
      _markDirty('settings');
      _scheduleRealtimeSync();
      notifyListeners();
    }
  }
  
  Future<void> restoreFromLocalSnapshot(File backupFile) async {
    try {
      final content = await backupFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _loadStateFromMap(data);
      _hasUnsavedChanges = true;
      _scheduleRealtimeSync();
      notifyListeners();
    } catch (e) {
      debugPrint("Error restoring snapshot: $e");
      rethrow;
    }
  }
  
  Future<void> manuallySaveToCloud() async {
    if (_currentUser == null) throw Exception("Not logged in.");
    _isManuallySaving = true;
    notifyListeners();
    try {
      await _performActualSave();
    } finally {
      _isManuallySaving = false;
      notifyListeners();
    }
  }

  Future<void> manuallyLoadFromCloud() async {
    if (_currentUser == null) throw Exception("Not logged in.");
    _isManuallyLoading = true;
    notifyListeners();
    try {
      final data = await _storageService.getUserData(_currentUser!.uid);
      if (data != null) {
        _loadStateFromMap(data);
        _saveLocalSnapshot(forceFlush: true);
        _hasUnsavedChanges = false;
      }
    } finally {
      _isManuallyLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loginUser(String email, String password) async => await fb_service.signInWithEmail(email, password);
  Future<void> logoutUser() async {
    if (_currentUser != null) { 
       await _saveLocalSnapshot(forceFlush: true);
       await _localStorageService.clearState();
    }
    await fb_service.signOut();
  }
  
  Future<void> signupUser(String email, String password, String username) async {
    _authLoading = true;
    notifyListeners();
    try {
      UserCredential uc = await fb_service.firebaseAuthInstance.createUserWithEmailAndPassword(email: email, password: password);
      _currentUser = uc.user;
      if (_currentUser != null) {
        await _currentUser!.updateDisplayName(username);
        await _currentUser!.reload();
        _currentUser = fb_service.firebaseAuthInstance.currentUser;
        await _resetToInitialState();
        _lastLoginDate = helper.getTodayDateString();
        _hasUnsavedChanges = true;
        await _performActualSave();
      }
    } finally {
      _authLoading = false;
      notifyListeners();
    }
  }
  
  void setProviderApiKeyIndex(int index) {
    if (_apiKeyIndex != index) _apiKeyIndex = index;
  }
  void setProviderAISubquestLoading(bool isLoading) {
    _isGeneratingSubquestsForTask = isLoading;
    notifyListeners();
  }
  void setLoadingTask(String? taskName) {
    _loadingTaskName = taskName;
    notifyListeners();
  }
  
  void _cleanOverlappingSessions() {
    bool hasChanges = false;
    List<Map<String, dynamic>> allSessions = [];
    
    for (var main in _mainTasks) {
      for (var sub in main.subTasks) {
        for (var session in sub.sessions) {
          allSessions.add({
            'session': session,
            'subId': sub.id,
            'mainId': main.id,
          });
        }
      }
    }

    if (allSessions.isEmpty) return;

    allSessions.sort((a, b) {
      final sA = (a['session'] as TaskSession);
      final sB = (b['session'] as TaskSession);
      return sA.startTime.compareTo(sB.startTime);
    });

    List<Map<String, dynamic>> sessionsToDelete = [];

    for (int i = 0; i < allSessions.length - 1; i++) {
      final current = allSessions[i];
      final next = allSessions[i + 1];
      
      final cSess = current['session'] as TaskSession;
      final nSess = next['session'] as TaskSession;

      if (nSess.startTime.isBefore(cSess.endTime)) {
        final cTimestamp = TimeValidationHelper.getCreationTimestamp(cSess.id);
        final nTimestamp = TimeValidationHelper.getCreationTimestamp(nSess.id);

        if (nTimestamp > cTimestamp) {
          sessionsToDelete.add(next);
        } else {
          sessionsToDelete.add(current);
        }
      }
    }

    if (sessionsToDelete.isNotEmpty) {
      final idsToDelete = sessionsToDelete.map((e) => (e['session'] as TaskSession).id).toSet();
      
      for (var main in _mainTasks) {
        for (var sub in main.subTasks) {
          final initialCount = sub.sessions.length;
          sub.sessions.removeWhere((s) => idsToDelete.contains(s.id));
          if (sub.sessions.length != initialCount) {
            int totalSeconds = 0;
            for (var s in sub.sessions) totalSeconds += s.durationSeconds;
            sub.currentTimeSpent = totalSeconds;
            hasChanges = true;
          }
        }
      }
    }

    if (hasChanges) {
      _markDirty('tasks');
      _scheduleRealtimeSync();
    }
  }

  Future<void> _resetToInitialState() async {
    _lastLoginDate = null;
    _mainTasks = initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    _settings = AppSettings();
    _activeTimers = {};
    _reflectionLogs = [];
    _completedByDay = {};
    _initializeSkills();
  }

  Future<void> _handleDailyReset() async {
    if (_currentUser == null) return;
    final today = helper.getTodayDateString();
    bool hasResetRun = false;

    if (_lastLoginDate != today) {
      hasResetRun = true;
      _lastLoginDate = today;
      _markDirty('settings');
      for (var task in _mainTasks) {
        if (task.lastWorkedDate != today) task.dailyTimeSpent = 0;
      }
      _markDirty('tasks');
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    bool tasksChanged = false;

    for (var mainTask in _mainTasks) {
      for (var subTask in mainTask.subTasks) {
        if (subTask.isRecurring) {
          if (subTask.completed &&
              subTask.lastCompletedDate != null &&
              subTask.lastCompletedDate!.isBefore(todayMidnight)) {
            subTask.completed = false;
            subTask.completedDate = null;
            tasksChanged = true;
          }
          if (subTask.isCountable &&
              subTask.currentCount > 0 &&
              subTask.updatedAt.isBefore(todayMidnight)) {
            subTask.currentCount = 0;
            tasksChanged = true;
          }
          for (var checkpoint in subTask.subSubTasks) {
            if (checkpoint.completed) {
              DateTime? cpDate;
              if (checkpoint.completionTimestamp != null) {
                try {
                  cpDate = DateTime.parse(checkpoint.completionTimestamp!);
                } catch (_) {}
              }
              if (cpDate == null || cpDate.isBefore(todayMidnight)) {
                checkpoint.completed = false;
                checkpoint.completionTimestamp = null;
                tasksChanged = true;
              }
            }
          }
        }
      }
    }

    if (tasksChanged) {
      _markDirty('tasks');
    }

    if (hasResetRun) {
      _chatbotMemory.lastWeeklySummary = "Weekly summary pending...";
      initializeChatbotMemory();
      notifyListeners();
    } else if (tasksChanged) {
      notifyListeners();
    }
  }

  void initializeChatbotMemory() { 
    if (!_isChatbotMemoryInitialized) {
       if (_chatbotMemory.conversationHistory.isEmpty) {
         _chatbotMemory.conversationHistory.add(ChatbotMessage(id: 'init_${DateTime.now().millisecondsSinceEpoch}', text: 'Hello Agent.', sender: MessageSender.bot, timestamp: DateTime.now()));
       }
       _isChatbotMemoryInitialized = true;
    }
  }

  Future<void> changePasswordHandler(String pwd) async { 
    await fb_service.changePassword(pwd); 
    _markDirty('settings');
    _scheduleRealtimeSync();
  }
  
  Future<void> updateUserDisplayName(String name) async { 
    await _currentUser?.updateDisplayName(name); 
    notifyListeners(); 
    _markDirty('settings');
    _scheduleRealtimeSync();
  }
  
  Future<void> clearAllData() async { 
    await _storageService.deleteUserData(_currentUser!.uid); 
    await _resetToInitialState(); 
    await _localStorageService.clearState();
    notifyListeners(); 
  }
  
  void addCustomApiKey(String key) { 
    settings.customApiKeys.add(key); 
    _markDirty('settings'); 
    _scheduleRealtimeSync(); 
    notifyListeners(); 
  }
  void removeCustomApiKey(String key) { 
    settings.customApiKeys.remove(key); 
    _markDirty('settings'); 
    _scheduleRealtimeSync(); 
    notifyListeners(); 
  }
  
  Future<void> sendMessageToChatbot(String userMessageText) async { 
    if (!_isChatbotMemoryInitialized) initializeChatbotMemory();
    _chatbotMemory.conversationHistory.add(ChatbotMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: userMessageText,
        sender: MessageSender.user,
        timestamp: DateTime.now()));
    notifyListeners();
    setLoadingTask("Consulting Advisor...");
    try {
      final botResponseText = await _aiService.getChatbotResponse(
        modelCandidates: settings.liteModels,
        memory: _chatbotMemory,
        userMessage: userMessageText,
        dataContext: "User Context Placeholder",
        currentApiKeyIndex: _apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        systemInstruction: settings.customChatbotPrompt,
        onNewApiKeyIndex: (newIndex) => _apiKeyIndex = newIndex,
        onLog: (logMsg) => {},
      );
      _chatbotMemory.conversationHistory.add(ChatbotMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          text: botResponseText,
          sender: MessageSender.bot,
          timestamp: DateTime.now()));
    } catch (e) {
      _chatbotMemory.conversationHistory.add(ChatbotMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: "Error connecting. ${e.toString()}",
          sender: MessageSender.bot,
          timestamp: DateTime.now()));
    } finally {
      setLoadingTask(null);
      _markDirty('settings');
      notifyListeners();
    }
  }
  
  Map<String, dynamic> getLast7DaysData() { 
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final logsBuffer = StringBuffer();
    final Map<String, int> totalTimePerTask = {};

    final relevantLogs = _reflectionLogs.where((log) =>
      log.timestamp.isAfter(sevenDaysAgo) && log.timestamp.isBefore(now.add(const Duration(days: 1)))
    ).toList();

    for (var log in relevantLogs) {
      logsBuffer.writeln("- [${DateFormat('yyyy-MM-dd').format(log.timestamp)}] ${log.trigger} -> ${log.emotion} (${log.reason})");
    }

    for (var task in _mainTasks) {
      int taskTotal = 0;
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isAfter(sevenDaysAgo) && session.startTime.isBefore(now.add(const Duration(days: 1)))) {
            taskTotal += session.durationSeconds;
          }
        }
      }
      if (taskTotal > 0) {
        totalTimePerTask[task.name] = taskTotal;
      }
    }

    final timeBuffer = StringBuffer();
    totalTimePerTask.forEach((name, seconds) {
      final hours = (seconds / 3600).toStringAsFixed(1);
      timeBuffer.writeln("- $name: $hours hrs");
    });

    return {
      'logs': logsBuffer.toString(),
      'times': timeBuffer.toString(),
    };
  }
  
  Future<Map<String, dynamic>> generateTacticalBriefing(String date, List<ReflectionLog> logs) async { 
    final result = await _aiService.generateDailySummary(
      reflections: logs.map((l) => {'trigger': l.trigger, 'emotion': l.emotion, 'reason': l.reason}).toList(),
      previousBriefings: [],
      modelCandidates: settings.liteModels,
      currentApiKeyIndex: apiKeyIndex,
      customApiKeys: settings.customApiKeys,
      onNewApiKeyIndex: (idx) => setProviderApiKeyIndex(idx),
      onLog: (msg) => debugPrint(msg)
    );
    return result; 
  }
  
  Map<String, dynamic>? getTacticalBriefing(String date) {
    if (_completedByDay.containsKey(date) && _completedByDay[date] is Map) {
      final data = _completedByDay[date]['aiBriefing'];
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }
  
  void saveTacticalBriefing(String date, Map<String, dynamic> data) {
    if (!_completedByDay.containsKey(date)) _completedByDay[date] = {};
    if (_completedByDay[date] is! Map) _completedByDay[date] = <String, dynamic>{};
    _completedByDay[date]['aiBriefing'] = data;
    _markDirty('history');
    _scheduleRealtimeSync();
    notifyListeners();
  }
  
  Future<List<Map<String, dynamic>>> generateStartDayReport() async { 
    return await _reportActions.generateStartDayReport();
  }
  
  void saveStartDayReport(String date, Map<String, dynamic> data) {
    if (!_completedByDay.containsKey(date)) _completedByDay[date] = {};
    if (_completedByDay[date] is! Map) _completedByDay[date] = <String, dynamic>{};
    _completedByDay[date]['startDayReport'] = data;
    _markDirty('history');
    _scheduleRealtimeSync();
    notifyListeners();
  }
  
  Map<String, dynamic>? getStartDayReport(String date) {
    if (_completedByDay.containsKey(date) && _completedByDay[date] is Map) {
      return _completedByDay[date]['startDayReport'] as Map<String, dynamic>?;
    }
    return null;
  }
  
  int get7DaySkillMomentum(String skillName) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _reflectionLogs
        .where((log) =>
            log.timestamp.isAfter(sevenDaysAgo) &&
            log.timestamp.isBefore(now.add(const Duration(days: 1))))
        .fold(0, (sum, log) => sum + (log.xpGained[skillName] ?? 0));
  }
  
  Future<Map<String, dynamic>> processReflection({required String trigger, required String emotion, required String reason, DateTime? timestamp}) async { 
    final actualTimestamp = timestamp ?? DateTime.now();
    setLoadingTask("Analyzing...");
    
    final result = await _aiService.evaluateReflection(
        trigger: trigger,
        emotion: emotion,
        reason: reason,
        modelCandidates: settings.liteModels,
        customApiKeys: settings.customApiKeys,
        systemInstruction: settings.customReflectionPrompt);
    
    setLoadingTask(null);

    Map<String, int> xpAllocation = {};
    if (result['xp_allocation'] is Map) {
      (result['xp_allocation'] as Map).forEach((key, value) =>
          xpAllocation[key.toString()] = (value as num).toInt());
    }

    List<Skill> updatedSkills = List.from(_skills);
    xpAllocation.forEach((skillName, xp) {
      final skill = updatedSkills.firstWhereOrNull(
          (s) => s.name.toLowerCase() == skillName.toLowerCase());
      if (skill != null) skill.addXp(xp);
    });

    _reflectionLogs.add(ReflectionLog(
        id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: actualTimestamp,
        trigger: trigger,
        emotion: emotion,
        reason: reason,
        aiFeedback: result['feedback'] ?? "Log recorded.",
        xpGained: xpAllocation));

    _skills = updatedSkills;
    _markDirty('reflections');
    _markDirty('settings');
    _scheduleRealtimeSync();
    notifyListeners();

    return {
      'xpGained': xpAllocation,
    };
  }
  
  void quickSaveReflection({required String trigger, required String emotion, required String reason, DateTime? timestamp}) {
    _reflectionLogs.add(ReflectionLog(
        id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: timestamp ?? DateTime.now(),
        trigger: trigger,
        emotion: emotion,
        reason: reason,
        aiFeedback: "Log recorded manually...",
        xpGained: {}));
    _markDirty('reflections');
    _scheduleRealtimeSync();
    notifyListeners();
  }
  
  void updateReflectionLog(String id, {String? trigger, String? emotion, String? reason}) {
    final index = _reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final old = _reflectionLogs[index];
      if (trigger != null) old.trigger = trigger;
      if (emotion != null) old.emotion = emotion;
      if (reason != null) old.reason = reason;
      _markDirty('reflections');
      _scheduleRealtimeSync();
      notifyListeners();
    }
  }
  
  void deleteReflectionLog(String id) {
    _reflectionLogs.removeWhere((l) => l.id == id);
    _markDirty('reflections');
    _scheduleRealtimeSync();
    notifyListeners();
  }
  
  MainTask? getSelectedTask() => _mainTasks.firstWhereOrNull((t) => t.id == _selectedTaskId);
  
  List<bool> getCompletionStatusForCurrentWeek(MainTask task) {
    // Basic stub, real impl used helpers
    return List.filled(7, false);
  }
  
  int getYesterdaysTimeForTask(String taskId) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final dayData = _completedByDay[yesterdayStr];
    if (dayData != null && dayData['taskTimes'] != null) {
      final taskTimes = dayData['taskTimes'] as Map<String, dynamic>;
      return (taskTimes[taskId] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
  
  Map<String, dynamic>? findLinkedProjectStepInfo(String targetId) {
    for (var mainTask in _mainTasks) {
      for (var project in mainTask.projects) {
        final result = _findStepLinkedToRecursive(project.steps, targetId);
        if (result != null) {
          return {
            'mainTaskId': mainTask.id,
            'projectId': project.id,
            'projectTitle': project.title,
            'stepId': result.id,
            'stepTitle': result.title,
          };
        }
      }
    }
    return null;
  }

  ProjectStep? _findStepLinkedToRecursive(List<ProjectStep> steps, String targetId) {
    for (var step in steps) {
      if (step.linkedTaskId == targetId) return step;
      final found = _findStepLinkedToRecursive(step.substeps, targetId);
      if (found != null) return found;
    }
    return null;
  }
}