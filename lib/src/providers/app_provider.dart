import 'package:flutter/foundation.dart';
import 'package:arcane/src/services/firebase_service.dart' as fb_service;
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/models/skill_models.dart'; 

import 'actions/task_actions.dart';
import 'actions/ai_generation_actions.dart';
import 'actions/timer_actions.dart';
import 'package:arcane/src/services/ai_service.dart';

class AppProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final AIService _aiService = AIService();
  Timer? _periodicUiTimer;
  Timer? _autoSaveTimer;

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

  // Skills and Reflections
  List<Skill> _skills = [];
  List<Skill> get skills => _skills;
  List<ReflectionLog> _reflectionLogs = [];
  List<ReflectionLog> get reflectionLogs => _reflectionLogs;

  AppSettings _settings = AppSettings();
  String? _selectedTaskId = initialMainTaskTemplates.isNotEmpty
      ? initialMainTaskTemplates[0].id
      : null;
  int _apiKeyIndex = 0;
  Map<String, ActiveTimerInfo> _activeTimers = {};

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

  TimeOfDay get wakeupTime =>
      TimeOfDay(hour: _settings.wakeupTimeHour, minute: _settings.wakeupTimeMinute);

  ChatbotMemory _chatbotMemory = ChatbotMemory();
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  bool _isChatbotMemoryInitialized = false;

  late final TaskActions _taskActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;

  AppProvider() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _initializeSkills(); // Init default skills
    _initialize();

    _periodicUiTimer?.cancel();
    _periodicUiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimers.values.any((info) => info.isRunning)) {
        notifyListeners();
      }
    });
  }

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

  @override
  void dispose() {
    _periodicUiTimer?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    fb_service.authStateChanges.listen(_onAuthStateChanged);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_hasUnsavedChanges &&
          _currentUser != null &&
          !_isManuallySaving &&
          !_isManuallyLoading) {
        _performActualSave();
      }
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (_authLoading &&
        _currentUser != null &&
        user != null &&
        _currentUser!.uid == user.uid) {
      return;
    }

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

      if (_currentUser?.displayName == null ||
          _currentUser!.displayName!.trim().isEmpty) {
        _isUsernameMissing = true;
      } else {
        _isUsernameMissing = false;
      }
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
    };
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
        // Remove energy logs loading
      }
    });

    _settings = data['settings'] != null
        ? AppSettings.fromJson(data['settings'] as Map<String, dynamic>)
        : AppSettings();

    _selectedTaskId = data['selectedTaskId'] as String? ??
        (_mainTasks.isNotEmpty ? _mainTasks[0].id : null);
    _apiKeyIndex = data['apiKeyIndex'] as int? ?? 0;

    _activeTimers = (data['activeTimers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
                key, ActiveTimerInfo.fromJson(value as Map<String, dynamic>))) ??
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
    if (_skills.isEmpty) {
      _initializeSkills();
    }

    if (data['reflectionLogs'] != null && data['reflectionLogs'] is List) {
      _reflectionLogs = (data['reflectionLogs'] as List)
          .where((l) => l != null && l is Map<String, dynamic>)
          .map((l) => ReflectionLog.fromJson(l as Map<String, dynamic>))
          .toList();
    }

    _isChatbotMemoryInitialized = true;
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
    _reflectionLogs = [];
    _hasUnsavedChanges = true;
  }

  Future<void> _performActualSave() async {
    if (_currentUser != null) {
      final success =
          await _storageService.setUserData(_currentUser!.uid, _appStateToMap());
      if (success) {
        _lastSuccessfulSaveTimestamp = DateTime.now();
        _hasUnsavedChanges = false;
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
        if (_currentUser?.displayName == null ||
            _currentUser!.displayName!.trim().isEmpty) {
          _isUsernameMissing = true;
        } else {
          _isUsernameMissing = false;
        }
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
  
  Future<void> loginUser(String email, String password) async {
    await fb_service.signInWithEmail(email, password);
  }

  Future<void> signupUser(
      String email, String password, String username) async {
    _authLoading = true;
    notifyListeners();
    try {
      UserCredential userCredential =
          await fb_service.firebaseAuthInstance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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
    if (_hasUnsavedChanges && _currentUser != null) {
      await _performActualSave();
    }
    await fb_service.signOut();
  }

  Future<void> changePasswordHandler(String newPassword) async {
    if (_currentUser == null) throw Exception("No user is currently signed in.");
    await fb_service.changePassword(newPassword);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  Future<void> updateUserDisplayName(String newUsername) async {
    if (_currentUser == null) return;
    await _currentUser!.updateDisplayName(newUsername);
    await _currentUser!.reload();
    _currentUser = fb_service.firebaseAuthInstance.currentUser;
    _isUsernameMissing = false;
    _hasUnsavedChanges = true;
    notifyListeners();
    await _performActualSave();
  }

  void setSelectedTaskId(String? taskId) {
    if (_selectedTaskId != taskId) {
      _selectedTaskId = taskId;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void setSettings(AppSettings newSettings) {
    _settings = newSettings;
    _hasUnsavedChanges = true;
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

    task.weeklyCompletionStatus.putIfAbsent(weekKey, () => List.filled(7, false));
    if (task.weeklyCompletionStatus[weekKey]![dayOfWeekIndex] == false) {
      task.weeklyCompletionStatus[weekKey]![dayOfWeekIndex] = true;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  // New Method to get Yesterday's Time for Comparison
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

    if (_lastLoginDate != today) {
      hasResetRun = true;
      _lastLoginDate = today;
      _hasUnsavedChanges = true;
      // Reset daily time spent for all tasks on a new day
      for (var task in _mainTasks) {
        if (task.lastWorkedDate != today) {
          task.dailyTimeSpent = 0;
        }
      }
    }

    if (hasResetRun) {
      _chatbotMemory.lastWeeklySummary = _generateWeeklySummaryForChatbot();
      _getCompletedGoalsForChatbotMemory();
      setProviderState(
          chatbotMemory: _chatbotMemory, doNotify: false);
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------
  // Logging Management (Reflections only, Energy Removed)
  // ----------------------------------------------------------------

  String _generateWeeklySummaryForChatbot() {
      return "Summary placeholder";
  }
  
  void _getCompletedGoalsForChatbotMemory() {
  }

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

  // Helper to build data context for AI
  String _buildUserDataContext() {
    final sb = StringBuffer();
    sb.writeln("Active Missions:");
    for (var t in _mainTasks) {
      sb.writeln("- ${t.name} (${t.theme}): ${t.description}");
      sb.writeln("  Sub-missions:");
      for (var st in t.subTasks) {
        sb.writeln("  - ${st.name} [${st.completed ? 'Completed' : 'Pending'}]");
      }
    }
    
    sb.writeln("\nLogs from Last 7 Days:");
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      if (_completedByDay.containsKey(dateStr)) {
        sb.writeln("Date: $dateStr");
        // Reflections
        final reflections = _reflectionLogs.where((r) {
           final rd = r.timestamp;
           return rd.year == d.year && rd.month == d.month && rd.day == d.day;
        }).map((r) => "  Reflection: ${r.trigger} -> ${r.emotion}").join("\n");
        if (reflections.isNotEmpty) sb.writeln(reflections);
      }
    }
    return sb.toString();
  }

  Future<void> sendMessageToChatbot(String userMessageText) async {
     if (!_isChatbotMemoryInitialized) initializeChatbotMemory();
    final userMessage = ChatbotMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: userMessageText,
        sender: MessageSender.user,
        timestamp: DateTime.now());
    _chatbotMemory.conversationHistory.add(userMessage);

    notifyListeners();

    try {
      final dataContext = _buildUserDataContext();
      
      final botResponseText = await _aiService.getChatbotResponse(
        modelName: settings.aiModelName,
        memory: _chatbotMemory,
        userMessage: userMessageText,
        dataContext: dataContext,
        currentApiKeyIndex: _apiKeyIndex,
        customApiKey: settings.customApiKey, 
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
          text: "I'm having trouble connecting right now. Please try again later. ${e.toString()}",
          sender: MessageSender.bot,
          timestamp: DateTime.now()));
    }
    setProviderState(chatbotMemory: _chatbotMemory);
  }

  // ----------------------------------------------------------------
  // Reflection & Skills Logic
  // ----------------------------------------------------------------

  int getXpGainedForSkillToday(String skillName) {
    final today = DateTime.now();
    
    return _reflectionLogs.where((log) {
       final logDt = log.timestamp;
       return logDt.year == today.year && logDt.month == today.month && logDt.day == today.day;
    }).fold(0, (sum, log) => sum + (log.xpGained[skillName] ?? 0));
  }

  Future<Map<String, int>> processReflection({
    required String trigger,
    required String emotion,
    required String reason,
  }) async {
    final result = await _aiService.evaluateReflection(
      trigger: trigger,
      emotion: emotion,
      reason: reason,
      modelName: settings.aiModelName,
      customApiKey: settings.customApiKey,
      systemInstruction: settings.customReflectionPrompt,
    );

    // Apply XP
    Map<String, int> xpAllocation = {};
    if (result['xp_allocation'] is Map) {
      (result['xp_allocation'] as Map).forEach((key, value) {
        xpAllocation[key.toString()] = (value as num).toInt();
      });
    }

    List<Skill> updatedSkills = List.from(_skills);
    xpAllocation.forEach((skillName, xp) {
      final skill = updatedSkills.firstWhereOrNull((s) => s.name.toLowerCase() == skillName.toLowerCase());
      if (skill != null) {
        skill.addXp(xp);
      }
    });

    final log = ReflectionLog(
      id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      trigger: trigger,
      emotion: emotion,
      reason: reason,
      aiFeedback: result['feedback'] ?? "Log recorded.",
      xpGained: xpAllocation,
    );

    _reflectionLogs.add(log);
    _skills = updatedSkills;
    _hasUnsavedChanges = true;
    notifyListeners();
    
    return xpAllocation;
  }

  void updateReflectionLog(String id, {String? trigger, String? emotion, String? reason}) {
    final index = _reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final old = _reflectionLogs[index];
      if (trigger != null) old.trigger = trigger;
      if (emotion != null) old.emotion = emotion;
      if (reason != null) old.reason = reason;
      
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void deleteReflectionLog(String id) {
    final index = _reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final log = _reflectionLogs[index];
      List<Skill> updatedSkills = List.from(_skills);
      log.xpGained.forEach((skillName, xp) {
         final skill = updatedSkills.firstWhereOrNull((s) => s.name.toLowerCase() == skillName.toLowerCase());
         if (skill != null) {
           skill.currentXp = (skill.currentXp - xp).clamp(0, skill.maxXp);
         }
      });
      _skills = updatedSkills;
      _reflectionLogs.removeAt(index);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  Future<void> clearAllData() async {
    if (_currentUser == null) return;
    await _storageService.deleteUserData(_currentUser!.uid);
    await _resetToInitialState();
    await _performActualSave();
    notifyListeners();
  }

  void setProviderState({
    String? lastLoginDate,
    List<MainTask>? mainTasks,
    Map<String, dynamic>? completedByDay,
    Map<String, ActiveTimerInfo>? activeTimers,
    DateTime? lastSuccessfulSaveTimestamp,
    bool? isUsernameMissing,
    ChatbotMemory? chatbotMemory,
    bool doNotify = true,
    bool doPersist = true,
  }) {
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
      if (doPersist) _hasUnsavedChanges = true;
      if (doNotify) notifyListeners();
    }
  }

  void setProviderAISubquestLoading(bool isLoading) {
    if (_isGeneratingSubquestsForTask != isLoading) {
      _isGeneratingSubquestsForTask = isLoading;
      notifyListeners();
    }
  }

  void setProviderApiKeyIndex(int index) {
    if (_apiKeyIndex != index) {
      _apiKeyIndex = index;
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
  bool completeSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.completeSubtask(mainTaskId, subtaskId);
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
  void deleteSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);

  void startTimer(String id, String type, String mainTaskId) =>
      _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);
}