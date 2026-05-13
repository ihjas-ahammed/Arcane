import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/services/firebase_service.dart' as fb_service;
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/history_helper.dart'; 
import 'package:missions/src/utils/constants.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

// Import Mixins
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:missions/src/providers/mixins/task_mixin.dart';
import 'package:missions/src/providers/mixins/finance_mixin.dart';
import 'package:missions/src/providers/mixins/user_mixin.dart';
import 'package:missions/src/providers/mixins/health_mixin.dart';

// Import Actions
import 'package:missions/src/providers/actions/task_actions.dart';
import 'package:missions/src/providers/actions/ai_generation_actions.dart';
import 'package:missions/src/providers/actions/timer_actions.dart';
import 'package:missions/src/providers/actions/report_actions.dart';
import 'package:missions/src/providers/actions/schedule_actions.dart';
import 'package:missions/src/providers/actions/finance_actions.dart';
import 'package:missions/src/providers/actions/journaling_actions.dart';

class AppProvider with ChangeNotifier, SyncMixin, TaskMixin, FinanceMixin, UserMixin, HealthMixin, WidgetsBindingObserver {
  
  final AIService _aiService = AIService();
  final DataExportService _exportService = DataExportService();
  final StorageService _cloudStorage = StorageService();
  final LocalStorageService _localStorage = LocalStorageService();

  AIService get aiService => _aiService;

  /// Fires whenever a reflection's AI analysis completes successfully.
  /// Carries the payload needed to render the "INSIGHT ACQUIRED" dialog.
  final ValueNotifier<InsightReadyEvent?> insightReady =
      ValueNotifier<InsightReadyEvent?>(null);

  /// Set of reflection log ids currently being analyzed in the background.
  final Set<String> _processingReflections = {};
  Set<String> get processingReflections => Set.unmodifiable(_processingReflections);
  bool isReflectionProcessing(String logId) => _processingReflections.contains(logId);

  // UI State
  String? _loadingTaskName;
  String? get loadingTaskName => _loadingTaskName;
  bool _isGeneratingSubquestsForTask = false;
  bool get isGeneratingSubquests => _isGeneratingSubquestsForTask;
  
  bool get isDataLoadingAfterLogin => false; 

  // Actions
  late final TaskActions _taskActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;
  late final ReportActions _reportActions;
  late final ScheduleActions _scheduleActions;
  late final FinanceActions _financeActions;
  late final JournalingActions _journalingActions;

  TaskActions get taskActions => _taskActions;
  AIGenerationActions get aiGenerationActions => _aiGenerationActions;
  TimerActions get timerActions => _timerActions;
  ReportActions get reportActions => _reportActions;
  ScheduleActions get scheduleActions => _scheduleActions;
  FinanceActions get financeActions => _financeActions;
  JournalingActions get journalingActions => _journalingActions;

  AppProvider() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _reportActions = ReportActions(this);
    _scheduleActions = ScheduleActions(this);
    _financeActions = FinanceActions(this);
    _journalingActions = JournalingActions(this);

    _initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (currentUser != null) {
        fetchDailyReportsFromCloud();
      }
    }
  }

  @override
  Future<void> manuallyLoadFromCloud() async {
    await super.manuallyLoadFromCloud();
    await fetchDailyReportsFromCloud();
  }

  // --- Initialization ---

  Future<void> _initialize() async {
    initializeSkills();
    initializeDefaultFinanceCategories();
    
    fb_service.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user != null) {
      if (currentUser == null || currentUser!.uid != user.uid) {
        setCurrentUser(user);
        
        // IMMEDIATE OFFLINE FIRST BOOT
        final localData = await _localStorage.loadState(user.uid);
        if (localData != null) {
          loadStateFromMap(localData);
        } else {
          // FIX: Auto load from cloud if local state is missing (Fixes web resets)
          await _resetToInitialState();
          await manuallyLoadFromCloud();
        }
        setAuthLoading(false); 
      }

      // Background Validation and Maintenance
      _cleanOverlappingSessions();
      _fixTimerAnomalies();
      await _taskActions.recalibrateTimeLogs(silent: true);
      _handleDailyReset();
      
      try {
        await fetchDailyReportsFromCloud();
      } catch (_) {}

    } else {
      setCurrentUser(null);
      await _resetToInitialState();
      setAuthLoading(false);
    }
  }

  Future<void> fetchDailyReportsFromCloud() async {
    if (currentUser == null) return;
    final recentDaily = await _cloudStorage.fetchRecentDailyData(currentUser!.uid, 14); 
    if (recentDaily.isNotEmpty) {
      final newHistory = Map<String, dynamic>.from(completedByDay);
      recentDaily.forEach((date, data) {
        final dayData = Map<String, dynamic>.from(newHistory[date] ?? {});
        bool changed = false;
        if (data.containsKey('briefing')) {
          dayData['aiBriefing'] = data['briefing'];
          changed = true;
        }
        if (data.containsKey('report')) {
          dayData['startDayReport'] = data['report'];
          changed = true;
        }
        if (changed) {
          newHistory[date] = dayData;
        }
      });
      setCompletedByDay(newHistory);
    }
  }

  Future<void> _resetToInitialState() async {
    setLastLoginDate(null);
    setSettings(AppSettings());
    setMainTasks(initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList());
    setCompletedByDay({});
    setActiveTimers({});
    setReflectionLogs([]);
    setTransactions([]);
    setCategories([]);
    setSavingsGoals([]);
    setChatbotMemory(ChatbotMemory());
    initializeSkills();
    initializeDefaultFinanceCategories();
  }

  // --- Mixin Implementations & Legacy Compat ---

  @override
  Map<String, dynamic> getFullAppState() {
    final map = <String, dynamic>{};
    map.addAll(getTaskStateMap());
    map.addAll(getFinanceStateMap());
    map.addAll(getUserStateMap());
    map.addAll(getHealthStateMap());
    return map;
  }

  Map<String, dynamic> getAppStateAsMap() => getFullAppState();
  
  void loadAppStateFromMap(Map<String, dynamic> data) => loadStateFromMap(data);

  @override
  void loadStateFromMap(Map<String, dynamic> data) {
    loadTaskState(data);
    loadFinanceState(data);
    loadUserState(data);
    loadHealthState(data);
    
    if (settings.dataVersion < 1) {
      settings.dataVersion = 1;
      markDirty('settings');
    }
  }

  // --- UI Helpers ---

  void setLoadingTask(String? name) {
    _loadingTaskName = name;
    notifyListeners();
  }

  void setProviderAISubquestLoading(bool loading) {
    _isGeneratingSubquestsForTask = loading;
    notifyListeners();
  }

  void setProviderApiKeyIndex(int index) => setApiKeyIndex(index);

  // --- State Bridge ---
  
  void setProviderState({
      String? lastLoginDate,
      List<MainTask>? mainTasks,
      Map<String, dynamic>? completedByDay,
      Map<String, dynamic>? activeTimers,
      DateTime? lastSuccessfulSaveTimestamp,
      bool? isUsernameMissing,
      ChatbotMemory? chatbotMemory,
      List<FinanceTransaction>? transactions,
      List<FinanceCategory>? categories,
      List<SavingsGoal>? savingsGoals,
      bool doNotify = true,
      bool doPersist = true
  }) {
    if (lastLoginDate != null) setLastLoginDate(lastLoginDate);
    if (mainTasks != null) setMainTasks(mainTasks);
    if (completedByDay != null) setCompletedByDay(completedByDay);
    if (activeTimers != null) setActiveTimers(activeTimers);
    if (chatbotMemory != null) setChatbotMemory(chatbotMemory);
    if (transactions != null) setTransactions(transactions);
    if (categories != null) setCategories(categories);
    if (savingsGoals != null) setSavingsGoals(savingsGoals);
    
    if (doNotify) notifyListeners();
  }

  // --- Delegated Actions ---

  void addMainTask({required String name, required String description, required String theme, required String colorHex}) => _taskActions.addMainTask(name: name, description: description, theme: theme, colorHex: colorHex);
  void editMainTask(String taskId, {required String name, required String description, required String theme, required String colorHex}) => _taskActions.editMainTask(taskId, name: name, description: description, theme: theme, colorHex: colorHex);
  void logToDailySummary(String type, Map<String, dynamic> data) => _taskActions.logToDailySummary(type, data);
  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) => _taskActions.addSubtask(mainTaskId, subtaskData);
  void updateSubtask(String mainTaskId, String subtaskId, Map<String, dynamic> updates) => _taskActions.updateSubtask(mainTaskId, subtaskId, updates);
  bool addSessionToSubtask(String mainTaskId, String subTaskId, DateTime start, DateTime end) => _taskActions.addSessionToSubtask(mainTaskId, subTaskId, start, end);
  void updateSessionInSubtask(String mainTaskId, String subTaskId, String sessionId, DateTime newStart, DateTime newEnd) => _taskActions.updateSessionInSubtask(mainTaskId, subTaskId, sessionId, newStart, newEnd);
  void deleteSessionFromSubtask(String mainTaskId, String subTaskId, String sessionId) => _taskActions.deleteSessionFromSubtask(mainTaskId, subTaskId, sessionId);
  bool completeSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) => _taskActions.completeSubtask(mainTaskId, subtaskId, fromSync: fromSync);
  void uncompleteSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) => _taskActions.uncompleteSubtask(mainTaskId, subtaskId, fromSync: fromSync);
  void deleteSubtask(String mainTaskId, String subtaskId) => _taskActions.deleteSubtask(mainTaskId, subtaskId);
  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) => _taskActions.duplicateCompletedSubtask(mainTaskId, subtaskId);
  void addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData, {String? parentCheckpointId}) => _taskActions.addSubSubtask(mainTaskId, parentSubtaskId, subSubtaskData, parentCheckpointId: parentCheckpointId);
  void updateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, Map<String, dynamic> updates) => _taskActions.updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
  void completeSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) => _taskActions.completeSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, fromSync: fromSync);
  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) => _taskActions.uncompleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, fromSync: fromSync);
  void deleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) => _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) => _taskActions.reorderSubtasks(mainTaskId, oldIndex, newIndex);
  Future<void> recalibrateTimeLogs({bool silent = false}) => _taskActions.recalibrateTimeLogs(silent: silent); 
  void startTimer(String id, String type, String mainTaskId) => _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);
  Future<void> triggerAISubquestGeneration(MainTask mainTask, String generationMode, String userInput, int numSubquests) => _aiGenerationActions.triggerAISubquestGeneration(mainTask, generationMode, userInput, numSubquests);

  // --- Auth & Wrappers ---

  Future<void> loginUser(String email, String password) async => await fb_service.signInWithEmail(email, password);
  Future<void> logoutUser() async => await fb_service.signOut();
  
  Future<void> signupUser(String email, String password) async {
    final user = await fb_service.signUpWithEmail(email, password);
    if (user != null) {
      await user.updateDisplayName("OPERATIVE");
      await user.reload();
      setCurrentUser(fb_service.firebaseAuthInstance.currentUser);
    }
  }
  
  Future<void> changePasswordHandler(String pwd) async => await fb_service.changePassword(pwd);
  Future<void> updateUserDisplayName(String name) async {
    if (currentUser != null) {
      await currentUser!.updateDisplayName(name);
      await currentUser!.reload();
      setCurrentUser(fb_service.firebaseAuthInstance.currentUser);
    }
  }

  Future<void> clearAllData() async {
    if (currentUser == null) return;
    await _cloudStorage.deleteUserData(currentUser!.uid);
    await _localStorage.clearState(currentUser!.uid);
    await _resetToInitialState();
    markDirty('settings');
    markDirty('tasks');
    markDirty('history');
    markDirty('reflections');
    markDirty('finance');
    markDirty('health');
  }

  Future<void> restoreFromLocalSnapshot(File backupFile) async {
    try {
      final contents = await backupFile.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      loadStateFromMap(data);
    } catch (e) {
      rethrow;
    }
  }

  void initializeChatbotMemory() {
    notifyListeners(); 
  }

  Future<void> exportReflections() async {
    final data = {'reflectionLogs': reflectionLogs.map((l) => l.toJson()).toList()};
    await _exportService.exportJson(data, 'arcane_reflections');
  }

  Future<void> importReflections() async {
    final data = await _exportService.importJson();
    if (data != null && data['reflectionLogs'] != null) {
      final List<dynamic> logsJson = data['reflectionLogs'];
      final importedLogs = logsJson.map((l) => ReflectionLog.fromJson(l as Map<String, dynamic>)).toList();
      final currentIds = reflectionLogs.map((l) => l.id).toSet();
      final newLogs = importedLogs.where((l) => !currentIds.contains(l.id)).toList();
      if (newLogs.isNotEmpty) {
        setReflectionLogs([...reflectionLogs, ...newLogs]..sort((a,b) => a.timestamp.compareTo(b.timestamp)));
      }
    }
  }

  // --- Gratitude / Assets Actions ---
  void updateGratitudeList(List<GratitudeItem> newList) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.gratitudeList = newList;
    setChatbotMemory(newMemory);
  }

  void updateGratitudeItem(GratitudeItem updatedItem) {
    final currentList = List<GratitudeItem>.from(chatbotMemory.gratitudeList);
    final index = currentList.indexWhere((i) => i.id == updatedItem.id);
    if (index != -1) {
      currentList[index] = updatedItem;
    } else {
      currentList.insert(0, updatedItem);
    }
    updateGratitudeList(currentList);
  }
  
  // --- Someday List Actions ---
  void addSomedayItem(String title) {
    final newItem = SomedayItem(id: const Uuid().v4(), title: title, createdAt: DateTime.now());
    final newSettings = AppSettings.fromJson(settings.toJson());
    newSettings.somedayList.insert(0, newItem);
    setSettings(newSettings);
  }

  void removeSomedayItem(String id) {
    final newSettings = AppSettings.fromJson(settings.toJson());
    newSettings.somedayList.removeWhere((i) => i.id == id);
    setSettings(newSettings);
  }

  // --- Reports Logic ---
  Map<String, dynamic> getLast7DaysData() { 
    final historyStr = HistoryHelper.getSessionHistoryString(mainTasks, 7); 
    final recentReflections = reflectionLogs
        .where((l) => l.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}")
        .join("\n");
    return {'logs': recentReflections, 'times': historyStr, 'sessions': historyStr};
  }
  
  String getWeeklyWellbeingComparison() {
    final now = DateTime.now();
    final last7 = now.subtract(const Duration(days: 7));
    final prev7 = now.subtract(const Duration(days: 14));
    
    Map<String, int> currentXp = {};
    Map<String, int> prevXp = {};
    
    for (var log in reflectionLogs) {
      if (log.timestamp.isAfter(last7)) {
        log.xpGained.forEach((k, v) => currentXp[k] = (currentXp[k] ?? 0) + v);
      } else if (log.timestamp.isAfter(prev7) && log.timestamp.isBefore(last7)) {
        log.xpGained.forEach((k, v) => prevXp[k] = (prevXp[k] ?? 0) + v);
      }
    }

    final buffer = StringBuffer();
    for (var skill in getBaseWellbeingSkills()) {
      final curr = currentXp[skill.name] ?? 0;
      final prev = prevXp[skill.name] ?? 0;
      if (curr > 0 || prev > 0) {
        buffer.writeln("${skill.name}: $curr XP (Prev week: $prev XP)");
      }
    }
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> getArchivedWeeklyReports() async {
    if (currentUser == null) return[];
    return await _cloudStorage.fetchWeeklyReports(currentUser!.uid);
  }

  Future<void> saveWeeklyReport(String date, Map<String, dynamic> data) async {
    if (currentUser != null) {
      await _cloudStorage.saveWeeklyReport(currentUser!.uid, date, data);
    }
  }

  void saveTacticalBriefing(String date, Map<String, dynamic> data) { 
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['aiBriefing'] = data;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'briefing', data);
    }
  }

  void saveStartDayReport(String date, Map<String, dynamic> data) { 
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['startDayReport'] = data;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'report', data);
    }
  }

  Map<String, dynamic>? getTacticalBriefing(String date) {
    if (completedByDay[date] != null && completedByDay[date]['aiBriefing'] != null) {
      return completedByDay[date]['aiBriefing'] as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? getStartDayReport(String date) {
    if (completedByDay[date] != null && completedByDay[date]['startDayReport'] != null) {
      return completedByDay[date]['startDayReport'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> generateTacticalBriefing(String date, List<ReflectionLog> logs) async { 
    final logsFormatted = logs.map((l) => {'trigger': l.trigger, 'emotion': l.emotion, 'reason': l.reason, 'action': l.action}).toList();
    final recentBriefings = <String>[];
    for (int i=1; i<=3; i++) {
       final d = DateTime.parse(date).subtract(Duration(days: i));
       final dStr = DateFormat('yyyy-MM-dd').format(d);
       final b = getTacticalBriefing(dStr);
       if (b != null && b['summary'] != null) recentBriefings.add(b['summary']);
    }
    
    final allLogsContext = reflectionLogs.reversed.take(50).map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join("\n");
    
    final result = await _aiService.generateDailySummary(
      reflections: logsFormatted, 
      previousBriefings: recentBriefings, 
      fullContext: allLogsContext,
      modelCandidates: settings.heavyModels, 
      currentApiKeyIndex: apiKeyIndex, 
      customApiKeys: settings.customApiKeys,
      onNewApiKeyIndex: (idx) => setApiKeyIndex(idx), 
      onLog: (m) => debugPrint(m),
      customInstruction: settings.customBriefingPrompt
    );

    if (result['grateful_assets'] != null) {
      final extracted = result['grateful_assets'] as List<dynamic>;
      final currentAssets = List<GratitudeItem>.from(chatbotMemory.gratitudeList);
      bool changed = false;
      for (var e in extracted) {
        final map = e as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        final type = map['type'] as String? ?? 'resource';
        final why = map['why'] as String? ?? '';
        final what = map['what'] as String? ?? '';
        if (name.isEmpty) continue;

        final existingIdx = currentAssets.indexWhere((a) => a.name.toLowerCase() == name.toLowerCase());
        if (existingIdx != -1) {
          if (why.isNotEmpty && !currentAssets[existingIdx].why.contains(why)) {
            currentAssets[existingIdx].why += (currentAssets[existingIdx].why.isEmpty ? "" : " ") + why;
            changed = true;
          }
          if (what.isNotEmpty && !currentAssets[existingIdx].what.contains(what)) {
             currentAssets[existingIdx].what += (currentAssets[existingIdx].what.isEmpty ? "" : " ") + what;
             changed = true;
          }
        } else {
          currentAssets.insert(0, GratitudeItem(id: const Uuid().v4(), type: type, name: name, why: why, what: what));
          changed = true;
        }
      }
      if (changed) updateGratitudeList(currentAssets);
    }

    if (result['grateful_people'] != null) {
      final extracted = result['grateful_people'] as List<dynamic>;
      final currentPeople = List<PersonInfo>.from(chatbotMemory.people);
      bool changed = false;
      for (var e in extracted) {
        final map = e as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        final relation = map['relation'] as String? ?? 'Acquaintance';
        if (name.isEmpty) continue;

        final existingIdx = currentPeople.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
        if (existingIdx == -1) {
          currentPeople.add(PersonInfo(id: const Uuid().v4(), name: name, relation: relation));
          changed = true;
        }
      }
      if (changed) {
        chatbotMemory.people = currentPeople;
        markDirty('settings');
      }
    }

    return result;
  }

  void _cleanOverlappingSessions() {
    bool changed = false;
    final newMainTasks = mainTasks.map((task) {
      return task.copyWith(
        subTasks: task.subTasks.map((sub) {
          if (sub.sessions.length <= 1) return sub;
          final sorted = List<TaskSession>.from(sub.sessions)..sort((a, b) => a.startTime.compareTo(b.startTime));
          final List<TaskSession> cleaned =[sorted.first];
          for (int i = 1; i < sorted.length; i++) {
            final current = sorted[i];
            final previous = cleaned.last;
            if (current.startTime.isBefore(previous.endTime)) {
              changed = true;
              if (current.endTime.isAfter(previous.endTime)) {
                cleaned.removeLast();
                cleaned.add(TaskSession(id: previous.id, startTime: previous.startTime, endTime: current.endTime));
              }
            } else {
              cleaned.add(current);
            }
          }
          if (cleaned.length != sub.sessions.length) {
            final totalSeconds = cleaned.fold(0, (sum, s) => sum + s.durationSeconds);
            return SubTask(
              id: sub.id, name: sub.name, description: sub.description, completed: sub.completed, currentTimeSpent: totalSeconds,
              completedDate: sub.completedDate, isCountable: sub.isCountable, targetCount: sub.targetCount, currentCount: sub.currentCount,
              subSubTasks: sub.subSubTasks, sessions: cleaned, isRecurring: sub.isRecurring, lastCompletedDate: sub.lastCompletedDate, createdAt: sub.createdAt, updatedAt: sub.updatedAt, why: sub.why, what: sub.what, resources: sub.resources,
            );
          }
          return sub;
        }).toList()
      );
    }).toList();

    if (changed) setMainTasks(newMainTasks);
  }

  void _fixTimerAnomalies() {
    // Handled in mixins
  }

  Future<void> _handleDailyReset() async {
    final todayStr = helper.getTodayDateString();
    if (lastLoginDate != todayStr) {
      bool changed = false;
      final newMainTasks = mainTasks.map((task) {
        final updatedSubtasks = task.subTasks.map((st) {
          if (st.isRecurring) {
            bool shouldReset = false;
            if (st.completed && st.lastCompletedDate != null) {
              if (DateFormat('yyyy-MM-dd').format(st.lastCompletedDate!) != todayStr) shouldReset = true;
            } else if (st.completed) {
              shouldReset = true;
            }
            if (shouldReset) {
              changed = true;
              // Stable reset: only flip completion + counters. Preserve every
              // other field (subSubTasks, substeps, sessions, why/what/etc.)
              // via copyWith. Recurring resets must NEVER drop checkpoints.
              return st.copyWith(
                completed: false,
                currentCount: 0,
                subSubTasks: st.subSubTasks.map(_resetCheckpoint).toList(),
                updatedAt: DateTime.now(),
              );
            }
          }
          return st;
        }).toList();

        if (task.dailyTimeSpent > 0) {
          changed = true;
          return task.copyWith(subTasks: updatedSubtasks, dailyTimeSpent: 0);
        }
        return task.copyWith(subTasks: updatedSubtasks);
      }).toList();

      setLastLoginDate(todayStr);
      if (changed) setMainTasks(newMainTasks);
    }
  }

  /// Recursively flip a checkpoint (and any nested substeps) back to
  /// incomplete while preserving structure, names, and configuration.
  SubSubTask _resetCheckpoint(SubSubTask cp) {
    return SubSubTask(
      id: cp.id,
      name: cp.name,
      completed: false,
      isCountable: cp.isCountable,
      targetCount: cp.targetCount,
      currentCount: 0,
      completionTimestamp: null,
      type: cp.type,
      substeps: cp.substeps.map(_resetCheckpoint).toList(),
      why: cp.why,
      what: cp.what,
    );
  }

  List<bool> getCompletionStatusForCurrentWeek(MainTask task) {
    List<bool> weeklyStatus = List.filled(7, false);
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final startOffset = settings.startOfWeek;
    int diff = currentWeekday - startOffset;
    if (diff < 0) diff += 7;
    final startOfWeekDate = now.subtract(Duration(days: diff));

    for (int i = 0; i < 7; i++) {
      final targetDate = startOfWeekDate.add(Duration(days: i));
      if (targetDate.isAfter(now)) break;
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final dayData = completedByDay[dateStr];
      if (dayData != null && dayData['taskTimes'] != null) {
         final times = dayData['taskTimes'] as Map<String, dynamic>;
         if (times.containsKey(task.id) && (times[task.id] as int) > 0) weeklyStatus[i] = true;
      }
    }
    return weeklyStatus;
  }

  int getYesterdaysTimeForTask(String taskId) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final dayData = completedByDay[dateStr];
    if (dayData != null && dayData['taskTimes'] != null) {
      return (dayData['taskTimes'] as Map<String, dynamic>)[taskId] as int? ?? 0;
    }
    return 0;
  }

  int get7DayWellbeingMomentum(String skillName) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    int total = 0;
    for (var log in reflectionLogs) {
      if (log.timestamp.isAfter(sevenDaysAgo)) {
        total += log.xpGained[skillName] ?? 0;
      }
    }
    return total;
  }

  Future<void> syncWeeklyWellbeing() async {
    setLoadingTask("Analyzing Weekly Wellbeing...");
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentLogs = reflectionLogs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
      if (recentLogs.isEmpty) {
        throw Exception("No reflection logs in the past 7 days to analyze.");
      }
      
      final logsPayload = recentLogs.map((l) => {
        "log_id": l.id,
        "trigger": l.trigger,
        "emotion": l.emotion,
        "action": l.action,
      }).toList();
      
      final updates = await aiService.evaluateBatchReflections(
        logsPayload: logsPayload,
        modelCandidates: settings.heavyModels, 
        currentApiKeyIndex: apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        onNewApiKeyIndex: (i) => setApiKeyIndex(i),
        onLog: (msg) => debugPrint(msg),
      );
      
      final newLogs = List<ReflectionLog>.from(reflectionLogs);
      bool logsChanged = false;
      for (var update in updates) {
        final logId = update['log_id'];
        final xpMap = Map<String, int>.from(update['xp_allocation'] ?? {});
        final idx = newLogs.indexWhere((l) => l.id == logId);
        if (idx != -1) {
          newLogs[idx] = ReflectionLog(
            id: newLogs[idx].id,
            timestamp: newLogs[idx].timestamp,
            trigger: newLogs[idx].trigger,
            emotion: newLogs[idx].emotion,
            reason: newLogs[idx].reason,
            action: newLogs[idx].action,
            aiFeedback: newLogs[idx].aiFeedback,
            xpGained: xpMap, 
          );
          logsChanged = true;
        }
      }
      
      if (logsChanged) {
        setReflectionLogs(newLogs);
      }
      
    } finally {
      setLoadingTask(null);
    }
  }

  /// Synchronously persists a stub reflection log, then runs AI analysis in
  /// the background. When the analysis completes, [insightReady] is fired and
  /// a system notification is posted via [NotificationService].
  ///
  /// Returns the new log's id so callers can correlate completion if needed.
  String startReflectionAnalysis({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    DateTime? timestamp,
  }) {
    final logId = const Uuid().v4();
    final log = ReflectionLog(
      id: logId,
      timestamp: timestamp ?? DateTime.now(),
      trigger: trigger,
      emotion: emotion,
      reason: reason,
      action: action,
      aiFeedback: 'Pending AI analysis...',
      xpGained: {},
    );
    setReflectionLogs([...reflectionLogs, log]);
    _processingReflections.add(logId);
    notifyListeners();

    // Fire-and-forget; the future is intentionally not awaited.
    // ignore: discarded_futures
    _runReflectionAnalysis(logId, trigger, emotion, reason, action);
    return logId;
  }

  Future<void> _runReflectionAnalysis(
    String logId,
    String trigger,
    String emotion,
    String reason,
    String action,
  ) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentContext = reflectionLogs
          .where((l) => l.timestamp.isAfter(sevenDaysAgo) && l.id != logId)
          .map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}")
          .join("\n");

      final eval = await _aiService.evaluateReflection(
        trigger: trigger, emotion: emotion, reason: reason, action: action,
        modelCandidates: settings.liteModels,
        customApiKeys: settings.customApiKeys,
        recentContext: recentContext,
        systemInstruction: settings.customReflectionPrompt,
      );
      final xpGained = Map<String, int>.from(eval['xp_allocation'] ?? {});
      final feedback = (eval['feedback'] as String?) ?? '';
      updateReflectionLog(logId, aiFeedback: feedback, xpGained: xpGained);

      insightReady.value = InsightReadyEvent(
        logId: logId,
        feedback: feedback,
        xpGained: xpGained,
        timestamp: DateTime.now(),
      );

      final preview = feedback.length > 120 ? '${feedback.substring(0, 117)}…' : feedback;
      // ignore: discarded_futures
      NotificationService.instance.showInsightReady(
        title: 'TACTICAL INSIGHT ACQUIRED',
        body: preview.isEmpty ? 'Reflection analysis complete.' : preview,
        payload: logId,
      );
    } catch (e) {
      updateReflectionLog(logId, aiFeedback: 'AI Analysis failed or offline.', xpGained: {});
    } finally {
      _processingReflections.remove(logId);
      notifyListeners();
    }
  }

  /// Legacy synchronous path retained for any caller that still needs to
  /// await the AI result inline (returns log + xp once analysis completes).
  Future<Map<String, dynamic>> processReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    DateTime? timestamp,
  }) async {
    final logId = startReflectionAnalysis(
      trigger: trigger, emotion: emotion, reason: reason, action: action, timestamp: timestamp,
    );
    final completer = Completer<Map<String, dynamic>>();
    void listener() {
      if (_processingReflections.contains(logId)) return;
      removeListener(listener);
      final log = reflectionLogs.firstWhereOrNull((l) => l.id == logId);
      if (log == null) {
        if (!completer.isCompleted) completer.completeError(StateError('Log $logId vanished'));
        return;
      }
      if (!completer.isCompleted) {
        completer.complete({'log': log, 'xpGained': log.xpGained});
      }
    }
    addListener(listener);
    return completer.future;
  }

  void updateReflectionLog(String id, {String? trigger, String? emotion, String? reason, String? action, String? aiFeedback, Map<String, int>? xpGained}) {
    final index = reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final old = reflectionLogs[index];
      final updated = ReflectionLog(
        id: old.id,
        timestamp: old.timestamp,
        trigger: trigger ?? old.trigger,
        emotion: emotion ?? old.emotion,
        reason: reason ?? old.reason,
        action: action ?? old.action,
        aiFeedback: aiFeedback ?? old.aiFeedback,
        xpGained: xpGained ?? old.xpGained,
      );
      final newLogs = List<ReflectionLog>.from(reflectionLogs);
      newLogs[index] = updated;
      setReflectionLogs(newLogs);
    }
  }

  void deleteReflectionLog(String id) {
    final index = reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final newLogs = List<ReflectionLog>.from(reflectionLogs)..removeAt(index);
      setReflectionLogs(newLogs);
    }
  }

  NoraSession? get activeNoraSession {
    if (chatbotMemory.activeNoraSessionId == null) return null;
    return chatbotMemory.noraSessions.firstWhereOrNull((s) => s.id == chatbotMemory.activeNoraSessionId);
  }

  void createNoraSession({
    required String title, 
    required String tone, 
    required DateTime startDate, 
    required DateTime endDate, 
    String? customContext,
    int? messageLimit,
    String? modelOverride,
    int? contextDays,
    String? systemPromptOverride,
  }) {
    final newSession = NoraSession(
      id: const Uuid().v4(), 
      title: title, 
      tone: tone, 
      startDate: startDate, 
      endDate: endDate, 
      customContext: customContext,
      messageLimit: messageLimit ?? 0,
      modelOverride: modelOverride,
      contextDays: contextDays ?? 7,
      systemPromptOverride: systemPromptOverride,
    );
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.noraSessions.add(newSession);
    newMemory.activeNoraSessionId = newSession.id;
    setChatbotMemory(newMemory);
  }
  
  void updateNoraSessionConfig({
    required String sessionId,
    int? messageLimit,
    String? modelOverride,
    int? contextDays,
    String? systemPromptOverride,
  }) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    final index = newMemory.noraSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      if (messageLimit != null) newMemory.noraSessions[index].messageLimit = messageLimit;
      newMemory.noraSessions[index].modelOverride = modelOverride; // allow nulling
      if (contextDays != null) newMemory.noraSessions[index].contextDays = contextDays;
      newMemory.noraSessions[index].systemPromptOverride = systemPromptOverride; // allow nulling
      setChatbotMemory(newMemory);
    }
  }

  void switchNoraSession(String sessionId) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.activeNoraSessionId = sessionId;
    setChatbotMemory(newMemory);
  }

  void deleteNoraSession(String sessionId) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.noraSessions.removeWhere((s) => s.id == sessionId);
    if (newMemory.activeNoraSessionId == sessionId) {
      newMemory.activeNoraSessionId = newMemory.noraSessions.isNotEmpty ? newMemory.noraSessions.last.id : null;
    }
    setChatbotMemory(newMemory);
  }

  Future<void> sendNoraMessage(String text) async {
    final session = activeNoraSession;
    if (session == null) return;

    final userMsg = ChatbotMessage(id: const Uuid().v4(), text: text, sender: MessageSender.user, timestamp: DateTime.now());
    session.messages.add(userMsg);
    markDirty('settings'); 

    // Gather Context bounded by session config
    DateTime start = session.startDate;
    DateTime end = session.endDate.add(const Duration(days: 1)); // Include end day fully
    
    // If contextDays is configured, override the date range to just look back X days from now
    if (session.contextDays > 0) {
       start = DateTime.now().subtract(Duration(days: session.contextDays));
       end = DateTime.now();
    }

    final refs = reflectionLogs.where((l) => l.timestamp.isAfter(start) && l.timestamp.isBefore(end)).toList();
    final refStr = refs.map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join(" | ");

    final List<String> sessionStrs = [];
    if (settings.noraAccessSessions) {
      for (var task in mainTasks) {
        for (var sub in task.subTasks) {
          for (var sess in sub.sessions) {
            if (sess.startTime.isAfter(start) && sess.startTime.isBefore(end)) {
              sessionStrs.add("[${DateFormat('MM-dd').format(sess.startTime)}] ${task.name}(${sub.name}): ${sess.durationMinutes}m");
            }
          }
        }
      }
    }

    final peopleStr = chatbotMemory.people.map((p) => "${p.name} (${p.relation})").join(", ");
    final assetsStr = chatbotMemory.gratitudeList.map((a) => "${a.name} (${a.type})").join(", ");

    String systemPrompt = session.systemPromptOverride ?? settings.customChatbotPrompt ?? "You are NORA. Tone: ${session.tone}.";

    final fullContext = """
    SYSTEM: $systemPrompt
    ${session.customContext ?? ''}

    CONTEXT DATA FOR REQUESTED PERIOD:
    Reflections: $refStr
    Sessions: ${sessionStrs.join(" | ")}
    Known Entities: $peopleStr
    Known Assets: $assetsStr
    """;
    
    final modelCandidates = session.modelOverride != null ? [session.modelOverride!] : settings.liteModels;
    final maxMessagesToGen = session.messageLimit > 0 ? session.messageLimit : 4; // Use limit or default to a sane 4
    
    try {
      final responses = await _aiService.queryNeuralArchive(
        query: text, 
        logsContext: fullContext, 
        maxMessages: maxMessagesToGen,
        modelCandidates: modelCandidates, 
        currentApiKeyIndex: apiKeyIndex, 
        customApiKeys: settings.customApiKeys, 
        onNewApiKeyIndex: (i) => setApiKeyIndex(i), 
        onLog: (m) {}
      );
      
      final clampLimit = session.messageLimit > 0 ? session.messageLimit : 15;
      final clampedResponses = responses.take(clampLimit).toList();

      for (String resp in clampedResponses) {
        // dynamic typing delay
        await Future.delayed(Duration(milliseconds: 1000 + (resp.length * 15).clamp(0, 3000)));
        final botMsg = ChatbotMessage(id: const Uuid().v4(), text: resp, sender: MessageSender.bot, timestamp: DateTime.now());
        session.messages.add(botMsg);
        markDirty('settings');
        notifyListeners();
      }
    } catch(e) {
      final errorMsg = ChatbotMessage(id: const Uuid().v4(), text: "Error: $e", sender: MessageSender.bot, timestamp: DateTime.now());
      session.messages.add(errorMsg);
      markDirty('settings');
      notifyListeners();
    }
  }
  
  Future<void> sendMessageToChatbot(String text) async => await sendNoraMessage(text);
  
  void addCustomApiKey(String key) {
    final newKeys = List<String>.from(settings.customApiKeys)..add(key);
    setSettings(settings..customApiKeys = newKeys);
  }
  
  void removeCustomApiKey(String key) {
    final newKeys = List<String>.from(settings.customApiKeys)..remove(key);
    setSettings(settings..customApiKeys = newKeys);
  }
  
  void setJournalPin(String pin) {
    setSettings(settings..journalPin = pin);
  }
}

class InsightReadyEvent {
  final String logId;
  final String feedback;
  final Map<String, int> xpGained;
  final DateTime timestamp;

  const InsightReadyEvent({
    required this.logId,
    required this.feedback,
    required this.xpGained,
    required this.timestamp,
  });
}