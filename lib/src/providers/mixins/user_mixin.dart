import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/habit_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

mixin UserMixin on ChangeNotifier {
  // Auth
  User? _currentUser;
  bool _authLoading = true;
  bool _isUsernameMissing = false;
  String? _lastLoginDate;

  // Settings & Profile
  AppSettings _settings = AppSettings();
  List<Skill> _skills = [];
  List<ReflectionLog> _reflectionLogs = [];
  
  // AI Memory
  ChatbotMemory _chatbotMemory = ChatbotMemory();
  int _apiKeyIndex = 0;

  // Getters
  User? get currentUser => _currentUser;
  bool get authLoading => _authLoading;
  bool get isUsernameMissing => _isUsernameMissing;
  String? get lastLoginDate => _lastLoginDate;
  AppSettings get settings => _settings;
  List<Skill> get skills => _skills;
  List<ReflectionLog> get reflectionLogs => _reflectionLogs;
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  int get apiKeyIndex => _apiKeyIndex;

  // Sync Dependency
  SyncMixin get sync => this as SyncMixin;

  void setCurrentUser(User? user) {
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
        log.xpGained.forEach((k, v) => rollingXp[k] = (rollingXp[k] ?? 0) + v);
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
      'chatbotMemory': _chatbotMemory.toJson(),
      'apiKeyIndex': _apiKeyIndex,
    };
  }
}