import 'package:flutter/foundation.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/habit_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/models/sop_session_model.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:missions/src/services/app_user.dart';

mixin UserMixin on ChangeNotifier {
  // Auth
  AppUser? _currentUser;
  bool _authLoading = true;
  bool _isUsernameMissing = false;
  String? _lastLoginDate;

  // Settings & Profile
  AppSettings _settings = AppSettings();
  List<Skill> _skills = [];
  List<ReflectionLog> _reflectionLogs = [];
  List<SopModel> _sops = [];
  SopSessionState? _activeSopSession;
  SopSessionState? get activeSopSession => _activeSopSession;
  
  // AI Memory
  ChatbotMemory _chatbotMemory = ChatbotMemory();
  int _apiKeyIndex = 0;

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get authLoading => _authLoading;
  bool get isUsernameMissing => _isUsernameMissing;
  String? get lastLoginDate => _lastLoginDate;
  AppSettings get settings => _settings;
  List<Skill> get skills => _skills;
  List<ReflectionLog> get reflectionLogs => _reflectionLogs;
  List<SopModel> get sops => _sops;
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  int get apiKeyIndex => _apiKeyIndex;

  // Sync Dependency
  SyncMixin get sync => this as SyncMixin;

  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    if (user != null) {
      _isUsernameMissing = user.displayName == null || user.displayName!.isEmpty;
    }
    notifyListeners();
  }

  void setAuthLoading(bool loading) {
    _authLoading = loading;
    notifyListeners();
  }

  void setSettings(AppSettings s) {
    _settings = s;
    sync.markDirty('settings');
  }

  void setLastLoginDate(String? date) {
    if (_lastLoginDate != date) {
      _lastLoginDate = date;
      sync.markDirty('settings');
    }
  }

  void setSkills(List<Skill> s) {
    _skills = s;
    sync.markDirty('settings');
  }

  void setReflectionLogs(List<ReflectionLog> l) {
    _reflectionLogs = l;
    recalculateAllSkills(); 
    sync.markDirty('reflections');
  }

  void setChatbotMemory(ChatbotMemory m) {
    _chatbotMemory = m;
    sync.markDirty('settings'); 
  }

  void setApiKeyIndex(int i) {
    _apiKeyIndex = i;
    sync.markDirty('settings');
  }

  List<Skill> getBaseWellbeingSkills() {
    return [
      Skill(id: 'pos', name: 'Positivity', description: 'More positive emotions: higher frequency and intensity of positive moods and emotions in oneâ€™s daily life.'),
      Skill(id: 'res', name: 'Resilience', description: 'Fewer negative emotions: lower frequency and intensity of negative moods and emotions in oneâ€™s daily life.'),
      Skill(id: 'sat', name: 'Satisfaction', description: 'Life satisfaction: a positive subjective evaluation of oneâ€™s life overall.'),
      Skill(id: 'vit', name: 'Vitality', description: 'Vitality: a positive subjective sense of physical health and energy.'),
      Skill(id: 'env', name: 'Env. Mastery', description: 'Environmental mastery: the ability to shape environments to suit oneâ€™s needs and desires.'),
      Skill(id: 'rel', name: 'Relationships', description: 'Positive relationships: feeling loved, supported, and valued by others.'),
      Skill(id: 'acc', name: 'Self-Acceptance', description: 'Self-acceptance: positive attitudes toward self; a sense of self-worth.'),
      Skill(id: 'mas', name: 'Mastery', description: 'Mastery: feelings of competence in accomplishing challenging tasks.'),
      Skill(id: 'aut', name: 'Autonomy', description: 'Autonomy: feeling independent, free to make oneâ€™s own choices in life.'),
      Skill(id: 'gro', name: 'Growth', description: 'Personal growth: continually seeking development and improvement.'),
      Skill(id: 'eng', name: 'Engagement', description: 'Engagement in life: being absorbed, interested, and involved in oneâ€™s daily activities.'),
      Skill(id: 'mea', name: 'Meaning', description: 'Meaning: feeling that life has purpose and direction.'),
    ];
  }

  void initializeSkills() {
    bool hasLegacy = _skills.any((s) => s.name.toLowerCase() == 'wisdom') || _skills.length < 12;
    if (_skills.isEmpty || hasLegacy) {
      _skills = getBaseWellbeingSkills();
    }
  }

  void recalculateAllSkills() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    Map<String, int> rollingXp = {};
    for (var log in _reflectionLogs) {
      if (log.timestamp.isAfter(sevenDaysAgo)) {
        log.xpGained.forEach((k, v) {
          final normalized = WellbeingTheme.normalizeSkillName(k);
          if (normalized != null) {
            rollingXp[normalized] = (rollingXp[normalized] ?? 0) + v;
          }
        });
      }
    }
    
    final newSkills = getBaseWellbeingSkills();
    for (var skill in newSkills) {
      int xp = rollingXp[skill.name] ?? 0;
      skill.level = 1;
      skill.maxXp = 100;
      int remainingXp = xp;
      while (remainingXp >= skill.maxXp) {
        remainingXp -= skill.maxXp;
        skill.level++;
        skill.maxXp = (skill.maxXp * 1.15).round();
      }
      skill.currentXp = remainingXp;
    }
    _skills = newSkills;
    sync.markDirty('settings');
  }

  // --- Habit Rule Methods ---
  void addHabitRule(HabitRule rule) {
    final newRules = List<HabitRule>.from(_settings.habitRules)..add(rule);
    setSettings(_settings..habitRules = newRules);
  }
  
  void updateHabitRule(HabitRule rule) {
    final newRules = _settings.habitRules.map((r) => r.id == rule.id ? rule : r).toList();
    setSettings(_settings..habitRules = newRules);
  }

  void deleteHabitRule(String id) {
    final newRules = _settings.habitRules.where((r) => r.id != id).toList();
    setSettings(_settings..habitRules = newRules);
  }

  void setSops(List<SopModel> list) {
    _sops = list;
    sync.markDirty('settings');
    notifyListeners();
  }

  void addSop(SopModel sop) {
    _sops = [..._sops, sop];
    sync.markDirty('settings');
    notifyListeners();
  }

  void updateSop(SopModel sop) {
    _sops = _sops.map((s) => s.id == sop.id ? sop : s).toList();
    sync.markDirty('settings');
    notifyListeners();
  }

  void deleteSop(String id) {
    _sops = _sops.where((s) => s.id != id).toList();
    sync.markDirty('settings');
    notifyListeners();
  }

  void addSopExecutionLog(String sopId, SopExecutionLog log) {
    _sops = _sops.map((sop) {
      if (sop.id == sopId) {
        final updatedLogs = [log, ...sop.executionLogs];
        return sop.copyWith(executionLogs: updatedLogs, updatedAt: DateTime.now());
      }
      return sop;
    }).toList();
    sync.markDirty('settings');
    notifyListeners();
  }

  void startSopSession(
    SopModel sop, {
    String? mainTaskId,
    String? subTaskId,
    String? taskTitle,
    int? targetDurationSeconds,
  }) {
    _activeSopSession = SopSessionState(
      sop: sop,
      mainTaskId: mainTaskId,
      subTaskId: subTaskId,
      taskTitle: taskTitle,
      startTime: DateTime.now(),
      targetDurationSeconds: targetDurationSeconds,
    );
    notifyListeners();
  }

  void toggleStepInActiveSopSession(int stepIndex) {
    if (_activeSopSession == null) return;
    final set = Set<int>.from(_activeSopSession!.completedStepIndices);
    if (set.contains(stepIndex)) {
      set.remove(stepIndex);
    } else {
      set.add(stepIndex);
    }

    final elapsedMins = _activeSopSession!.elapsedSeconds / 60.0;
    final totalSteps = _activeSopSession!.sop.steps.length;
    final pct = totalSteps > 0 ? (set.length / totalSteps) * 100.0 : 100.0;

    final newPoints = [
      ..._activeSopSession!.progressPoints,
      SopProgressPoint(elapsedMinutes: elapsedMins, completionPercentage: pct),
    ];

    _activeSopSession = _activeSopSession!.copyWith(
      completedStepIndices: set,
      progressPoints: newPoints,
    );
    notifyListeners();
  }

  void pauseActiveSopSession() {
    if (_activeSopSession == null || _activeSopSession!.isPaused) return;
    _activeSopSession = _activeSopSession!.copyWith(
      isPaused: true,
      pauseStartTime: DateTime.now(),
    );
    notifyListeners();
  }

  void resumeActiveSopSession() {
    if (_activeSopSession == null || !_activeSopSession!.isPaused) return;
    final now = DateTime.now();
    int additionalPaused = 0;
    if (_activeSopSession!.pauseStartTime != null) {
      additionalPaused = now.difference(_activeSopSession!.pauseStartTime!).inSeconds;
    }
    _activeSopSession = _activeSopSession!.copyWith(
      isPaused: false,
      accumulatedPausedSeconds: _activeSopSession!.accumulatedPausedSeconds + additionalPaused,
      pauseStartTime: null,
    );
    notifyListeners();
  }

  void finishActiveSopSession({
    required String notes,
    required int rating,
    required String status,
  }) {
    if (_activeSopSession == null) return;
    final sessionState = _activeSopSession!;

    final log = SopExecutionLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      notes: notes,
      successStatus: status,
      rating: rating,
    );
    addSopExecutionLog(sessionState.sop.id, log);

    _activeSopSession = null;
    notifyListeners();
  }

  void cancelActiveSopSession() {
    _activeSopSession = null;
    notifyListeners();
  }

  void loadUserState(Map<String, dynamic> data) {
    _lastLoginDate = data['lastLoginDate'];
    if (data['settings'] != null) {
      _settings = AppSettings.fromJson(data['settings']);
    }
    
    if (data['skills'] != null) {
      _skills = (data['skills'] as List).map((e) => Skill.fromJson(e)).toList();
    }
    initializeSkills();

    if (data['reflectionLogs'] != null) {
      _reflectionLogs = (data['reflectionLogs'] as List).map((e) => ReflectionLog.fromJson(e)).toList();
    }

    if (data['sops'] != null) {
      _sops = (data['sops'] as List)
          .map((e) => SopModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    
    // Auto-recalculate levels based purely on the 7-day window of logs.
    recalculateAllSkills();

    if (data['chatbotMemory'] != null) {
      _chatbotMemory = ChatbotMemory.fromJson(data['chatbotMemory']);
    }
    
    _apiKeyIndex = data['apiKeyIndex'] as int? ?? 0;
  }

  Map<String, dynamic> getUserStateMap() {
    return {
      'lastLoginDate': _lastLoginDate,
      'settings': _settings.toJson(),
      'skills': _skills.map((e) => e.toJson()).toList(),
      'reflectionLogs': _reflectionLogs.map((e) => e.toJson()).toList(),
      'sops': _sops.map((e) => e.toJson()).toList(),
      'chatbotMemory': _chatbotMemory.toJson(),
      'apiKeyIndex': _apiKeyIndex,
    };
  }
}