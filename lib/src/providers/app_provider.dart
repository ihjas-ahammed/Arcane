// ... [Imports]
import 'package:flutter/foundation.dart';
import 'package:arcane/src/services/firebase_service.dart' as fb_service;
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/models/project_models.dart';

import 'actions/task_actions.dart';
import 'actions/ai_generation_actions.dart';
import 'actions/timer_actions.dart';
import 'actions/project_actions.dart';
import 'package:arcane/src/services/ai_service.dart';

class AppProvider with ChangeNotifier {
  // ... [Existing fields same as before]
  final StorageService _storageService = StorageService();
  final AIService _aiService = AIService();

  // Expose AIService for widgets that need direct access (like graph anomaly detection)
  AIService get aiService => _aiService;

  Timer? _periodicUiTimer;
  Timer? _autoSaveTimer;
  Timer? _realtimeSyncDebouncer;

  String? _loadingTaskName;
  String? get loadingTaskName => _loadingTaskName;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _authLoading = true;
  bool get authLoading => _authLoading;
  bool _isDataLoadingAfterLogin = false;
  bool get isDataLoadingAfterLogin => _isDataLoadingAfterLogin;
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

  List<LifeValue> _lifeValues = [];
  List<LifeValue> get lifeValues => _lifeValues;

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

  TimeOfDay get wakeupTime => TimeOfDay(
      hour: _settings.wakeupTimeHour, minute: _settings.wakeupTimeMinute);

  ChatbotMemory _chatbotMemory = ChatbotMemory();
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  bool _isChatbotMemoryInitialized = false;

  late final TaskActions _taskActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;
  late final ProjectActions _projectActions;

  AppProvider() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _projectActions = ProjectActions(this);
    _initializeSkills();
    _initializeValues();
    _initialize();

    _periodicUiTimer?.cancel();
    _periodicUiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimers.values.any((info) => info.isRunning)) {
        notifyListeners();
      }
    });

    _ensureBackupDir();
  }

  // ... [Existing methods: _ensureBackupDir, _markDirty, etc.]

  Future<void> _ensureBackupDir() async {
    try {
      if (Platform.isAndroid || Platform.isWindows) {
        final docsDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docsDir.path}/backups');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
      }
    } catch (e) {
      debugPrint("Error creating backup dir: $e");
    }
  }

  void _markDirty(String collection) {
    _dirtyCollections.add(collection);
    _hasUnsavedChanges = true;
  }

  void addCustomApiKey(String key) {
    if (key.trim().isNotEmpty && !settings.customApiKeys.contains(key)) {
      final updatedKeys = List<String>.from(settings.customApiKeys)..add(key.trim());
      setSettings(settings..customApiKeys = updatedKeys);
    }
  }

  void removeCustomApiKey(String key) {
    final updatedKeys = List<String>.from(settings.customApiKeys)..remove(key);
    setSettings(settings..customApiKeys = updatedKeys);
  }

  // --- REVERSE LOOKUP HELPER FOR LINKED TASKS ---
  // Finds if a given task/checkpoint ID is linked to any project step
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

  // --- CHART DATA HELPER ---
  List<Map<String, dynamic>> getProjectProgressHistory(Project project) {
    final List<Map<String, dynamic>> history = [];
    final now = DateTime.now();
    final creation = project.createdAt;

    // Add Start Point
    history.add({
      'date': creation,
      'progress': 0.0,
      'time': 0.0,
    });

    // Collect Events: Session Logs & Completion
    // Iterate Linked Tasks to get their Sessions
    for (var step in project.steps) {
      _collectHistoryRecursive(step, history);
    }

    // Sort by date
    history.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return history;
  }

  void _collectHistoryRecursive(ProjectStep step, List<Map<String, dynamic>> history) {
    // 1. Completion Event
    if (step.isCompleted && step.completedAt != null) {
      history.add({
        'date': step.completedAt!,
        'type': 'completion',
        'stepId': step.id,
      });
    }

    // 2. Linked Task Sessions (Time)
    if (step.linkedTaskId != null && step.linkedTaskType == 'subtask') {
      final mainTask = _mainTasks.firstWhereOrNull((t) => t.id == step.linkedParentTaskId);
      if (mainTask != null) {
        final sub = mainTask.subTasks.firstWhereOrNull((s) => s.id == step.linkedTaskId);
        if (sub != null) {
          for (var session in sub.sessions) {
            history.add({
              'date': session.endTime,
              'type': 'session',
              'duration': session.durationSeconds.toDouble(),
              'sessionId': session.id, // Included for anomaly detection
              'subTaskId': sub.id,     // Included for anomaly detection
              'mainTaskId': mainTask.id, // Included for anomaly detection
            });
          }
        }
      }
    }

    for (var sub in step.substeps) {
      _collectHistoryRecursive(sub, history);
    }
  }

  // ... [Rest of the file: initialization, auth, save/load logic unchanged]

  void reorderValues(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _lifeValues.removeAt(oldIndex);
    _lifeValues.insert(newIndex, item);
    _hasUnsavedChanges = true;
    _scheduleRealtimeSync();
    notifyListeners();
  }

  Future<void> analyzeValueAlignment(String valueId) async {
    final value = _lifeValues.firstWhereOrNull((v) => v.id == valueId);
    if (value == null) return;
    setLoadingTask("Analyzing Value...");
    try {
      final result = await _aiService.analyzeValueAlignment(
        valueName: value.title,
        questionsAndAnswers: value.questions
            .map((q) => {'question': q.question, 'answer': q.answer})
            .toList(),
        modelCandidates: settings.liteModels,
        currentApiKeyIndex: apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        onNewApiKeyIndex: (idx) => setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ValueAI] $msg"),
      );

      value.score = result['score'] as int;
      value.lastInsight = result['insight'] as String?;

      _hasUnsavedChanges = true;
      _scheduleRealtimeSync();
      notifyListeners();
    } finally {
      setLoadingTask(null);
    }
  }

  void setLoadingTask(String? taskName) {
    if (_loadingTaskName != taskName) {
      _loadingTaskName = taskName;
      notifyListeners();
    }
  }

  void setProviderApiKeyIndex(int index) {
    if (_apiKeyIndex != index) _apiKeyIndex = index;
  }

  void updateValueAnswer(String valueId, String questionId, String answer) {
    final valueIndex = _lifeValues.indexWhere((v) => v.id == valueId);
    if (valueIndex != -1) {
      final qIndex = _lifeValues[valueIndex]
          .questions
          .indexWhere((q) => q.id == questionId);
      if (qIndex != -1) {
        _lifeValues[valueIndex].questions[qIndex].answer = answer;
        _markDirty('settings');
        _scheduleRealtimeSync();
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> generateTasksFromValue(
      String valueId) async {
    final value = _lifeValues.firstWhereOrNull((v) => v.id == valueId);
    if (value == null) return [];
    setLoadingTask("Generating Actions...");
    try {
      return await _aiService.generateTasksFromValues(
        valueName: value.title,
        questionsAndAnswers: value.questions
            .map((q) => {'question': q.question, 'answer': q.answer})
            .toList(),
        modelCandidates: settings.liteModels,
        currentApiKeyIndex: apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        onNewApiKeyIndex: (idx) => setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ValueAI] $msg"),
      );
    } finally {
      setLoadingTask(null);
    }
  }

  void _initializeSkills() {
    if (_skills.isEmpty) {
      _skills = [
        Skill(
            id: 'wis',
            name: 'Wisdom',
            description: 'Good judgment, learning, perspective.'),
        Skill(
            id: 'cou',
            name: 'Courage',
            description: 'Bravery, persistence, integrity.'),
        Skill(
            id: 'hum',
            name: 'Humanity',
            description: 'Love, kindness, social intelligence.'),
        Skill(
            id: 'jus',
            name: 'Justice',
            description: 'Teamwork, fairness, leadership.'),
        Skill(
            id: 'tem',
            name: 'Temperance',
            description: 'Forgiveness, humility, self-regulation.'),
        Skill(
            id: 'tra',
            name: 'Transcendence',
            description: 'Appreciation of beauty, gratitude, hope.'),
      ];
    }
  }

  void _initializeValues() {
    if (_lifeValues.isEmpty) {
      _lifeValues = LifeValue.getDefaults();
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

  void _scheduleRealtimeSync() {
    if (!_settings.autoSaveEnabled ||
        _currentUser == null ||
        _isManuallyLoading) return;
    if (_realtimeSyncDebouncer?.isActive ?? false) {
      _realtimeSyncDebouncer!.cancel();
    }
    _realtimeSyncDebouncer = Timer(const Duration(seconds: 3), () {
      if (_hasUnsavedChanges && !_isManuallySaving) {
        _performActualSave();
      }
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (_authLoading &&
        _currentUser != null &&
        user != null &&
        _currentUser!.uid == user.uid) return;
    _authLoading = true;
    notifyListeners();
    if (user != null) {
      _currentUser = user;
      _isDataLoadingAfterLogin = true;
      notifyListeners();
      final data = await _storageService.getUserData(user.uid);
      if (data != null) {
        _loadStateFromMap(data);
        _hasUnsavedChanges = false;
        _handleDailyReset();
      } else {
        await _resetToInitialState();
        _lastLoginDate = helper.getTodayDateString();
        _hasUnsavedChanges = true;
        await _performActualSave();
        _handleDailyReset();
      }
      _isChatbotMemoryInitialized = false;
      initializeChatbotMemory();
      _isUsernameMissing = _currentUser?.displayName == null ||
          _currentUser!.displayName!.trim().isEmpty;
      _isDataLoadingAfterLogin = false;
    } else {
      _currentUser = null;
      await _resetToInitialState();
      _isDataLoadingAfterLogin = false;
      _hasUnsavedChanges = false;
      _isChatbotMemoryInitialized = false;
    }
    _authLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> _appStateToMap() {
    return {
      'lastLoginDate': _lastLoginDate,
      'mainTasks': _mainTasks.map((mt) => mt.toJson()).toList(),
      'completedByDay': _completedByDay,
      'settings': settings.toJson(),
      'selectedTaskId': _selectedTaskId,
      'apiKeyIndex': _apiKeyIndex,
      'activeTimers':
          _activeTimers.map((key, value) => MapEntry(key, value.toJson())),
      'lastSuccessfulSaveTimestamp':
          _lastSuccessfulSaveTimestamp?.toIso8601String(),
      'chatbotMemory': _chatbotMemory.toJson(),
      'skills': _skills.map((s) => s.toJson()).toList(),
      'reflectionLogs': _reflectionLogs.map((l) => l.toJson()).toList(),
      'lifeValues': _lifeValues.map((v) => v.toJson()).toList(),
    };
  }

  Map<String, dynamic> getAppStateAsMap() => _appStateToMap();

  void loadAppStateFromMap(Map<String, dynamic> data) {
    _loadStateFromMap(data);
    _hasUnsavedChanges = true;
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
        dayDataMap.putIfAbsent(
            'subtasksCompleted', () => <Map<String, dynamic>>[]);
        dayDataMap.putIfAbsent(
            'checkpointsCompleted', () => <Map<String, dynamic>>[]);
      }
    });
    _settings = data['settings'] != null
        ? AppSettings.fromJson(data['settings'] as Map<String, dynamic>)
        : AppSettings();
    _selectedTaskId = data['selectedTaskId'] as String? ??
        (_mainTasks.isNotEmpty ? _mainTasks[0].id : null);
    _apiKeyIndex = data['apiKeyIndex'] as int? ?? 0;
    _activeTimers = (data['activeTimers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key,
                ActiveTimerInfo.fromJson(value as Map<String, dynamic>))) ??
        {};
    final timestampString = data['lastSuccessfulSaveTimestamp'] as String?;
    _lastSuccessfulSaveTimestamp =
        timestampString != null ? DateTime.tryParse(timestampString) : null;
    _chatbotMemory = data['chatbotMemory'] != null
        ? ChatbotMemory.fromJson(data['chatbotMemory'] as Map<String, dynamic>)
        : ChatbotMemory();
    if (data['skills'] != null && data['skills'] is List) {
      _skills = (data['skills'] as List)
          .where((s) => s != null && s is Map<String, dynamic>)
          .map((s) => Skill.fromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      _initializeSkills();
    }
    if (_skills.isEmpty) _initializeSkills();
    if (data['reflectionLogs'] != null && data['reflectionLogs'] is List) {
      _reflectionLogs = (data['reflectionLogs'] as List)
          .where((l) => l != null && l is Map<String, dynamic>)
          .map((l) => ReflectionLog.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    if (data['lifeValues'] != null && data['lifeValues'] is List) {
      _lifeValues = (data['lifeValues'] as List)
          .where((v) => v != null && v is Map<String, dynamic>)
          .map((v) => LifeValue.fromJson(v as Map<String, dynamic>))
          .toList();
    } else {
      _initializeValues();
    }
    if (_lifeValues.length < 10) {
      final defaults = LifeValue.getDefaults();
      for (var def in defaults) {
        if (!_lifeValues.any((v) => v.id == def.id)) _lifeValues.add(def);
      }
    }
    _isChatbotMemoryInitialized = true;
    if (_settings.dataVersion < 1) {
      _settings.dataVersion = 1;
      _hasUnsavedChanges = true;
    }
    notifyListeners();
  }

  Future<void> _resetToInitialState() async {
    _lastLoginDate = null;
    _mainTasks =
        initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    _completedByDay = {};
    _settings = AppSettings();
    _selectedTaskId = _mainTasks.isNotEmpty ? _mainTasks[0].id : null;
    _apiKeyIndex = 0;
    _activeTimers = {};
    _isUsernameMissing = false;
    _lastSuccessfulSaveTimestamp = null;
    _chatbotMemory = ChatbotMemory();
    _isChatbotMemoryInitialized = true;
    _initializeSkills();
    _initializeValues();
    _reflectionLogs = [];
    _hasUnsavedChanges = true;
  }

  Future<void> _performActualSave() async {
    if (_currentUser != null) {
      bool isAutoSave = !_isManuallySaving;
      if (!isAutoSave) setLoadingTask("Syncing Database...");
      try {
        await _saveLocalSnapshot();

        bool success = true;
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
            if (_dirtyCollections.contains('settings')) {
              final settingsData = {
                'lastLoginDate': _lastLoginDate,
                'settings': settings.toJson(),
                'selectedTaskId': _selectedTaskId,
                'apiKeyIndex': _apiKeyIndex,
                'activeTimers': _activeTimers
                    .map((key, value) => MapEntry(key, value.toJson())),
                'lastSuccessfulSaveTimestamp':
                    _lastSuccessfulSaveTimestamp?.toIso8601String(),
                'chatbotMemory': _chatbotMemory.toJson(),
                'skills': _skills.map((s) => s.toJson()).toList(),
                'lifeValues': _lifeValues.map((v) => v.toJson()).toList(),
              };
              if (!await _storageService.saveSettings(
                  _currentUser!.uid, settingsData)) success = false;
            }
          }
          if (success) _dirtyCollections.clear();
        }

        if (success) {
          _lastSuccessfulSaveTimestamp = DateTime.now();
          _hasUnsavedChanges = false;
        }
      } finally {
        if (!isAutoSave) setLoadingTask(null);
        notifyListeners();
      }
    }
  }

  Future<void> manuallySaveToCloud() async {
    if (_currentUser == null) throw Exception("Not logged in. Cannot save.");
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
    if (_currentUser == null) throw Exception("Not logged in. Cannot load.");
    _isManuallyLoading = true;
    notifyListeners();
    try {
      final data = await _storageService.getUserData(_currentUser!.uid);
      if (data != null) {
        _loadStateFromMap(data);
        _handleDailyReset();
        _isUsernameMissing = _currentUser?.displayName == null ||
            _currentUser!.displayName!.trim().isEmpty;
        _hasUnsavedChanges = false;
        _isChatbotMemoryInitialized = false;
        initializeChatbotMemory();
      } else {
        throw Exception("No data found on cloud.");
      }
    } finally {
      _isManuallyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginUser(String email, String password) async =>
      await fb_service.signInWithEmail(email, password);

  Future<void> signupUser(
      String email, String password, String username) async {
    _authLoading = true;
    notifyListeners();
    try {
      UserCredential userCredential = await fb_service.firebaseAuthInstance
          .createUserWithEmailAndPassword(email: email, password: password);
      _currentUser = userCredential.user;
      if (_currentUser != null) {
        await _currentUser!.updateDisplayName(username);
        await _currentUser!.reload();
        _currentUser = fb_service.firebaseAuthInstance.currentUser;
        await _resetToInitialState();
        _lastLoginDate = helper.getTodayDateString();
        _hasUnsavedChanges = true;
        await _performActualSave();
        _isChatbotMemoryInitialized = false;
        initializeChatbotMemory();
        _handleDailyReset();
        _isDataLoadingAfterLogin = false;
        _isUsernameMissing = false;
      } else {
        throw Exception("Signup successful but user object is null.");
      }
    } catch (e) {
      _currentUser = null;
      rethrow;
    } finally {
      _authLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutUser() async {
    if (_hasUnsavedChanges && _currentUser != null) await _performActualSave();
    await fb_service.signOut();
  }

  Future<void> changePasswordHandler(String newPassword) async {
    if (_currentUser == null)
      throw Exception("No user is currently signed in.");
    await fb_service.changePassword(newPassword);
    _hasUnsavedChanges = true;
    _scheduleRealtimeSync();
    notifyListeners();
  }

  Future<void> updateUserDisplayName(String newUsername) async {
    if (_currentUser == null) return;
    await _currentUser!.updateDisplayName(newUsername);
    await _currentUser!.reload();
    _currentUser = fb_service.firebaseAuthInstance.currentUser;
    _isUsernameMissing = false;
    _currentUser = fb_service.firebaseAuthInstance.currentUser;
    _isUsernameMissing = false;
    _markDirty('settings');
    notifyListeners();
    await _performActualSave();
  }

  void setSelectedTaskId(String? taskId) {
    if (_selectedTaskId != taskId) {
      _selectedTaskId = taskId;
      _hasUnsavedChanges = true;
      _scheduleRealtimeSync();
      notifyListeners();
    }
  }

  void setSettings(AppSettings newSettings) {
    _settings = newSettings;
    _hasUnsavedChanges = true;
    _scheduleRealtimeSync();
    notifyListeners();
  }

  MainTask? getSelectedTask() {
    if (_selectedTaskId == null) return _mainTasks.firstOrNull;
    return _mainTasks.firstWhereOrNull((t) => t.id == _selectedTaskId) ??
        _mainTasks.firstOrNull;
  }

  String _getWeekKey(DateTime date, int startOfWeek) {
    int day = date.weekday;
    DateTime adjustedDate =
        date.subtract(Duration(days: (day - startOfWeek + 7) % 7));
    int weekOfYear =
        (adjustedDate.difference(DateTime(adjustedDate.year, 1, 1)).inDays / 7)
                .ceil() +
            1;
    return '${adjustedDate.year}-W${weekOfYear.toString().padLeft(2, '0')}';
  }

  List<bool> getCompletionStatusForCurrentWeek(MainTask task) {
    final weekKey = _getWeekKey(DateTime.now(), _settings.startOfWeek);
    return task.weeklyCompletionStatus[weekKey] ?? List.filled(7, false);
  }

  void markDailyTaskGoalMet(String taskId) {
    final task = _mainTasks.firstWhereOrNull((t) => t.id == taskId);
    if (task == null) return;
    final today = DateTime.now();
    final weekKey = _getWeekKey(today, _settings.startOfWeek);
    final dayOfWeekIndex = (today.weekday - _settings.startOfWeek + 7) % 7;
    task.weeklyCompletionStatus
        .putIfAbsent(weekKey, () => List.filled(7, false));
    if (task.weeklyCompletionStatus[weekKey]![dayOfWeekIndex] == false) {
      task.weeklyCompletionStatus[weekKey]![dayOfWeekIndex] = true;
      // This is inside mainTasks, so mark tasks dirty
      _markDirty('tasks');
      _scheduleRealtimeSync();
      notifyListeners();
    }
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

  Future<void> _handleDailyReset() async {
    if (_currentUser == null) return;
    final today = helper.getTodayDateString();
    bool hasResetRun = false;

    // Check for daily login update
    if (_lastLoginDate != today) {
      hasResetRun = true;
      _lastLoginDate = today;
      _markDirty('settings'); // lastLoginDate changed
      for (var task in _mainTasks) {
        if (task.lastWorkedDate != today) task.dailyTimeSpent = 0;
      }
      _markDirty('tasks'); // tasks changed
    }

    // --- Recurring Task Reset Logic ---
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    bool tasksChanged = false;
    for (var mainTask in _mainTasks) {
      for (var subTask in mainTask.subTasks) {
        if (subTask.isRecurring) {

          // 1. Reset Main Subtask if it was completed BEFORE today
          if (subTask.completed &&
              subTask.lastCompletedDate != null &&
              subTask.lastCompletedDate!.isBefore(todayMidnight)) {

            subTask.completed = false;
            subTask.completedDate = null;
            // IMPORTANT: Clear lastCompletedDate locally so we don't reset again today if app restarts
            // But we need to keep it if we want "history".
            // Better logic: we reset it, so now it is NOT completed.
            // But lastCompletedDate helps us know when it was done.
            // If we don't clear it, next app open will see completed=false, so this block won't run.
            // So this block is safe.
            tasksChanged = true;
          }

          // 2. Reset Counter if it was updated BEFORE today
          // We use updatedAt. If user updated counter today, updatedAt >= todayMidnight.
          // If updated yesterday, it < todayMidnight.
          if (subTask.isCountable &&
              subTask.currentCount > 0 &&
              subTask.updatedAt.isBefore(todayMidnight)) {
            subTask.currentCount = 0;
            tasksChanged = true;
          }

          // 3. Reset Checkpoints individually based on THEIR completion time
          for (var checkpoint in subTask.subSubTasks) {
            if (checkpoint.completed) {
              DateTime? cpDate;
              if (checkpoint.completionTimestamp != null) {
                try {
                  cpDate = DateTime.parse(checkpoint.completionTimestamp!);
                } catch (_) {}
              }

              // If no timestamp (legacy) or timestamp is before today -> Reset
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
      _chatbotMemory.lastWeeklySummary = _generateWeeklySummaryForChatbot();
      _getCompletedGoalsForChatbotMemory();
      setProviderState(chatbotMemory: _chatbotMemory, doNotify: false);
      notifyListeners();
    } else if (tasksChanged) {
      notifyListeners();
    }
  }

  String _generateWeeklySummaryForChatbot() => "Summary placeholder";
  void _getCompletedGoalsForChatbotMemory() {}

  void initializeChatbotMemory() {
    if (_isChatbotMemoryInitialized) return;
    _chatbotMemory.lastWeeklySummary = _generateWeeklySummaryForChatbot();
    _getCompletedGoalsForChatbotMemory();
    if (_chatbotMemory.conversationHistory.isEmpty) {
      _chatbotMemory.conversationHistory.add(ChatbotMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          text:
              "Hello! I am Arcane Advisor. How can I assist with your mission logs or goals today?",
          sender: MessageSender.bot,
          timestamp: DateTime.now()));
    }
    _isChatbotMemoryInitialized = true;
    notifyListeners();
  }

  void saveDailySummary(String date, String summary) {
    if (!_completedByDay.containsKey(date)) _completedByDay[date] = {};
    if (_completedByDay[date] is! Map)
      _completedByDay[date] = <String, dynamic>{};
    if (_completedByDay[date] is! Map)
      _completedByDay[date] = <String, dynamic>{};
    _completedByDay[date]['aiSummary'] = summary;
    _markDirty('history');
    _scheduleRealtimeSync();
    notifyListeners();
  }

  void deleteDailySummary(String date) {
    if (_completedByDay.containsKey(date) && _completedByDay[date] is Map) {
      _completedByDay[date].remove('aiSummary');
      _markDirty('history');
      _scheduleRealtimeSync();
      notifyListeners();
    }
  }

  String? getDailySummary(String date) {
    if (_completedByDay.containsKey(date) && _completedByDay[date] is Map)
      return _completedByDay[date]['aiSummary'] as String?;
    return null;
  }

  String _buildUserDataContext() {
    final sb = StringBuffer();
    sb.writeln("Active Missions:");
    for (var t in _mainTasks) {
      sb.writeln("- ${t.name} (${t.theme}): ${t.description}");
      for (var st in t.subTasks)
        sb.writeln(
            "  - ${st.name} [${st.completed ? 'Completed' : 'Pending'}]");
      for (var p in t.projects)
        sb.writeln("  - ${p.title} (${(p.progress * 100).toInt()}% Done)");
    }
    sb.writeln("\nLogs from Last 7 Days:");
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      if (_completedByDay.containsKey(dateStr)) {
        sb.writeln("Date: $dateStr");
        final reflections = _reflectionLogs
            .where((r) =>
                r.timestamp.year == d.year &&
                r.timestamp.month == d.month &&
                r.timestamp.day == d.day)
            .map((r) => "  Reflection: ${r.trigger} -> ${r.emotion}")
            .join("\n");
        if (reflections.isNotEmpty) sb.writeln(reflections);
      }
    }
    return sb.toString();
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
        dataContext: _buildUserDataContext(),
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
      setProviderState(chatbotMemory: _chatbotMemory);
    }
  }

  int getXpGainedForSkillToday(String skillName) {
    final today = DateTime.now();
    return _reflectionLogs
        .where((log) =>
            log.timestamp.year == today.year &&
            log.timestamp.month == today.month &&
            log.timestamp.day == today.day)
        .fold(0, (sum, log) => sum + (log.xpGained[skillName] ?? 0));
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

  // --- Helper for Weekly Report Data Gathering ---
  Map<String, dynamic> getLast7DaysData() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final logsBuffer = StringBuffer();
    final Map<String, int> totalTimePerTask = {};

    // 1. Gather Logs
    final relevantLogs = _reflectionLogs.where((log) =>
      log.timestamp.isAfter(sevenDaysAgo) && log.timestamp.isBefore(now.add(const Duration(days: 1)))
    ).toList();

    for (var log in relevantLogs) {
      logsBuffer.writeln("- [${DateFormat('yyyy-MM-dd').format(log.timestamp)}] ${log.trigger} -> ${log.emotion} (${log.reason})");
    }

    // 2. Gather Time Data
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);

      // Past data
      if (_completedByDay.containsKey(dateStr)) {
        final dayData = _completedByDay[dateStr];
        if (dayData != null && dayData['taskTimes'] != null) {
          (dayData['taskTimes'] as Map<String, dynamic>).forEach((taskId, seconds) {
             final task = _mainTasks.firstWhereOrNull((t) => t.id == taskId);
             if (task != null) {
               totalTimePerTask[task.name] = (totalTimePerTask[task.name] ?? 0) + (seconds as int);
             }
          });
        }
      }

      // Today (Live) if loop hits today
      if (dateStr == DateFormat('yyyy-MM-dd').format(now)) {
         for (var task in _mainTasks) {
           int todaySeconds = 0;
           for (var sub in task.subTasks) {
             for (var session in sub.sessions) {
               if (session.startTime.year == now.year && session.startTime.month == now.month && session.startTime.day == now.day) {
                 todaySeconds += session.durationSeconds;
               }
             }
           }
           if (todaySeconds > 0) {
             // Avoid double counting if today is already in completedByDay (depends on save logic)
             // For simplicity, we assume completedByDay is updated on save/end of day.
             // Ideally we check if we already added it.
             // Since loop iterates dates, and completedByDay stores finalized or saved data,
             // live data might be separate. Let's merge max for safety or just rely on live calculation logic.
             // Actually, simplest is to re-calculate from sessions for the last 7 days directly from mainTasks
             // because completedByDay is a summary.
           }
         }
      }
    }

    // Better Approach: Calculate strictly from MainTasks session history for last 7 days
    // This is more accurate for "active" tasks.
    totalTimePerTask.clear();
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

  Future<Map<String, int>> processReflection(
      {required String trigger,
      required String emotion,
      required String reason,
      DateTime? timestamp}) async {
    final actualTimestamp = timestamp ?? DateTime.now();
    final dailyReflections = _reflectionLogs
        .where((log) =>
            log.timestamp.year == actualTimestamp.year &&
            log.timestamp.month == actualTimestamp.month &&
            log.timestamp.day == actualTimestamp.day)
        .map((r) =>
            {'trigger': r.trigger, 'emotion': r.emotion, 'reason': r.reason})
        .toList();
    setLoadingTask("Analyzing Reflection...");
    final result = await _aiService.evaluateReflection(
        trigger: trigger,
        emotion: emotion,
        reason: reason,
        modelCandidates: settings.liteModels,
        dailyReflections: dailyReflections,
        customApiKeys: settings.customApiKeys,
        systemInstruction: settings.customReflectionPrompt);
    setLoadingTask(null);
    Map<String, int> xpAllocation = {};
    if (result['xp_allocation'] is Map)
      (result['xp_allocation'] as Map).forEach((key, value) =>
          xpAllocation[key.toString()] = (value as num).toInt());
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
    _markDirty('settings'); // skills changed
    _scheduleRealtimeSync();
    notifyListeners();
    return xpAllocation;
  }

  void quickSaveReflection(
      {required String trigger,
      required String emotion,
      required String reason,
      DateTime? timestamp}) {
    _reflectionLogs.add(ReflectionLog(
        id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: timestamp ?? DateTime.now(),
        trigger: trigger,
        emotion: emotion,
        reason: reason,
        aiFeedback: "Log recorded manually. No analysis performed.",
        xpGained: {}));
    _markDirty('reflections');
    _scheduleRealtimeSync();
    notifyListeners();
  }

  void updateReflectionLog(String id,
      {String? trigger, String? emotion, String? reason}) {
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
    final index = _reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final log = _reflectionLogs[index];
      List<Skill> updatedSkills = List.from(_skills);
      log.xpGained.forEach((skillName, xp) {
        final skill = updatedSkills.firstWhereOrNull(
            (s) => s.name.toLowerCase() == skillName.toLowerCase());
        if (skill != null)
          skill.currentXp = (skill.currentXp - xp).clamp(0, skill.maxXp);
      });
      _skills = updatedSkills;
      _reflectionLogs.removeAt(index);
      _markDirty('reflections');
      _markDirty('settings'); // skills
      _scheduleRealtimeSync();
      notifyListeners();
    }
  }

  Future<void> clearAllData() async {
    if (_currentUser == null) return;
    await _storageService.deleteUserData(_currentUser!.uid);
    await _resetToInitialState();
    await _storageService.deleteUserData(_currentUser!.uid);
    await _resetToInitialState();
    // Do not save here, as we just deleted everything. If we save, we might restore empty state.
    // But resetToInitialState sets hasUnsavedChanges=true.
    // We should clear dirty.
    _dirtyCollections.clear();
    _hasUnsavedChanges = false;
    notifyListeners();
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
        // Deduce what changed from the non-null arguments
        if (mainTasks != null) _markDirty('tasks');
        if (completedByDay != null) _markDirty('history');
        if (lastLoginDate != null ||
            activeTimers != null ||
            lastSuccessfulSaveTimestamp != null ||
            isUsernameMissing != null ||
            chatbotMemory != null) _markDirty('settings');
        // If none specifically matched but changed was true (e.g. from a catch-all?), fallback?
        // This covers most cases.

        _hasUnsavedChanges = true;
        _scheduleRealtimeSync();
      }
      if (doNotify) notifyListeners();
    }
  }

  void setProviderAISubquestLoading(bool isLoading) {
    if (_isGeneratingSubquestsForTask != isLoading) {
      _isGeneratingSubquestsForTask = isLoading;
      notifyListeners();
    }
  }

  Future<void> triggerAISubquestGeneration(MainTask mainTask,
          String generationMode, String userInput, int numSubquests) =>
      _aiGenerationActions.triggerAISubquestGeneration(
          mainTask, generationMode, userInput, numSubquests);
  void addMainTask(
          {required String name,
          required String description,
          required String theme,
          required String colorHex}) =>
      _taskActions.addMainTask(
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex);
  void editMainTask(String taskId,
          {required String name,
          required String description,
          required String theme,
          required String colorHex}) =>
      _taskActions.editMainTask(taskId,
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex);
  void logToDailySummary(String type, Map<String, dynamic> data) =>
      _taskActions.logToDailySummary(type, data);
  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) =>
      _taskActions.addSubtask(mainTaskId, subtaskData);
  void updateSubtask(
          String mainTaskId, String subtaskId, Map<String, dynamic> updates) =>
      _taskActions.updateSubtask(mainTaskId, subtaskId, updates);
  void addSessionToSubtask(
          String mainTaskId, String subTaskId, DateTime start, DateTime end) =>
      _taskActions.addSessionToSubtask(mainTaskId, subTaskId, start, end);
  void updateSessionInSubtask(String mainTaskId, String subTaskId,
          String sessionId, DateTime newStart, DateTime newEnd) =>
      _taskActions.updateSessionInSubtask(
          mainTaskId, subTaskId, sessionId, newStart, newEnd);
  void deleteSessionFromSubtask(
          String mainTaskId, String subTaskId, String sessionId) =>
      _taskActions.deleteSessionFromSubtask(mainTaskId, subTaskId, sessionId);
  bool completeSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.completeSubtask(mainTaskId, subtaskId);
  void uncompleteSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.uncompleteSubtask(mainTaskId, subtaskId);
  void deleteSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.deleteSubtask(mainTaskId, subtaskId);
  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.duplicateCompletedSubtask(mainTaskId, subtaskId);
  void addSubSubtask(String mainTaskId, String parentSubtaskId,
          Map<String, dynamic> subSubtaskData) =>
      _taskActions.addSubSubtask(mainTaskId, parentSubtaskId, subSubtaskData);
  void updateSubSubtask(String mainTaskId, String parentSubtaskId,
          String subSubtaskId, Map<String, dynamic> updates) =>
      _taskActions.updateSubSubtask(
          mainTaskId, parentSubtaskId, subSubtaskId, updates);
  void completeSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.completeSubSubtask(
          mainTaskId, parentSubtaskId, subSubtaskId);
  void uncompleteSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.uncompleteSubSubtask(
          mainTaskId, parentSubtaskId, subSubtaskId);
  void deleteSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) =>
      _taskActions.reorderSubtasks(mainTaskId, oldIndex, newIndex);
  void startTimer(String id, String type, String mainTaskId) =>
      _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);
  ProjectActions get projectActions => _projectActions;
  TaskActions get taskActions => _taskActions;
  AIGenerationActions get aiGenerationActions => _aiGenerationActions;

  Future<void> _saveLocalSnapshot() async {
    try {
      if (Platform.isAndroid || Platform.isWindows) {
        final docsDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docsDir.path}/backups');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .split('.')
            .first;
        final file = File('${backupDir.path}/backup_$timestamp.json');
        final fullData = _appStateToMap();
        await file.writeAsString(jsonEncode(fullData));

        // Cleanup old backups
        final files = backupDir.listSync().whereType<File>().toList();
        // Sort by path (timestamp is in name so should be chronological)
        files.sort((a, b) => a.path.compareTo(b.path));
        if (files.length > 5) {
          for (var i = 0; i < files.length - 5; i++) {
            await files[i].delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Snapshot save failed: $e");
    }
  }

  Future<void> restoreFromLocalSnapshot(File backupFile) async {
    try {
      final content = await backupFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      loadAppStateFromMap(data);
    } catch (e) {
      debugPrint("Error restoring snapshot: $e");
      rethrow;
    }
  }
}
