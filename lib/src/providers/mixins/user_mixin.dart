import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/providers/mixins/sync_mixin.dart';

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
    sync.markDirty('settings'); // Skills stored in settings chunk usually
  }

  void setReflectionLogs(List<ReflectionLog> l) {
    _reflectionLogs = l;
    sync.markDirty('reflections');
  }

  void setChatbotMemory(ChatbotMemory m) {
    _chatbotMemory = m;
    sync.markDirty('settings'); // Memory in settings chunk
  }

  void setApiKeyIndex(int i) {
    _apiKeyIndex = i;
    sync.markDirty('settings');
  }

  void initializeSkills() {
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