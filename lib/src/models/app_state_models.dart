// lib/src/models/app_state_models.dart
import 'package:arcane/src/models/habit_models.dart';
import 'package:uuid/uuid.dart';

class SomedayItem {
  String id;
  String title;
  DateTime createdAt;

  SomedayItem({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory SomedayItem.fromJson(Map<String, dynamic> json) {
    return SomedayItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Idea',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AppSettings {
  bool descriptionsVisible;
  bool dailyAutoGenerateContent;
  bool autoSaveEnabled;
  int wakeupTimeHour;
  int wakeupTimeMinute;
  List<String> liteModels;
  List<String> heavyModels;
  List<String> customApiKeys; 
  String? customChatbotPrompt;
  String? customReflectionPrompt;
  String? customBriefingPrompt;
  List<String> savedPrompts;
  int startOfWeek;
  int dataVersion;
  int lastModified; 
  
  // Security and Nora AI Settings
  String? journalPin;
  bool noraAccessSessions;
  bool noraAccessFinance;

  // Habit / Override Framework
  List<HabitRule> habitRules;
  
  // Someday / Maybe List
  List<SomedayItem> somedayList;

  // Bus Schedules
  Map<String, Map<String, List<String>>>? customBusSchedules;

  // Onboarding
  bool hasCompletedTour;

  AppSettings({
    this.descriptionsVisible = true,
    this.dailyAutoGenerateContent = true,
    this.autoSaveEnabled = true,
    this.wakeupTimeHour = 7,
    this.wakeupTimeMinute = 0,
    this.liteModels = const [
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash'
    ],
    this.heavyModels = const [
      'gemini-2.0-flash',
      'gemini-2.0-pro-exp-02-05',
      'gemini-1.5-pro'
    ],
    this.customApiKeys = const [],
    this.customChatbotPrompt,
    this.customReflectionPrompt,
    this.customBriefingPrompt,
    this.savedPrompts = const [],
    this.startOfWeek = 1,
    this.dataVersion = 0,
    int? lastModified,
    this.journalPin,
    this.noraAccessSessions = false,
    this.noraAccessFinance = false,
    this.habitRules = const [],
    this.somedayList = const [],
    this.hasCompletedTour = false,
    this.customBusSchedules,
  }) : lastModified = lastModified ?? DateTime.now().millisecondsSinceEpoch;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    List<String> keys = [];
    if (json['customApiKeys'] != null) {
      keys = (json['customApiKeys'] as List).map((e) => e.toString()).toList();
    } else if (json['customApiKey'] != null &&
        json['customApiKey'].toString().isNotEmpty) {
      keys.add(json['customApiKey'].toString());
    }

    return AppSettings(
      descriptionsVisible: json['descriptionsVisible'] as bool? ?? true,
      dailyAutoGenerateContent: json['dailyAutoGenerateContent'] as bool? ??
          json['autoGenerateContent'] as bool? ??
          true,
      autoSaveEnabled: json['autoSaveEnabled'] as bool? ?? true,
      wakeupTimeHour: json['wakeupTimeHour'] as int? ?? 7,
      wakeupTimeMinute: json['wakeupTimeMinute'] as int? ?? 0,
      liteModels: (json['liteModels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['gemini-2.0-flash-lite', 'gemini-2.0-flash', 'gemini-1.5-flash'],
      heavyModels: (json['heavyModels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['gemini-2.0-flash', 'gemini-2.0-pro-exp-02-05', 'gemini-1.5-pro'],
      customApiKeys: keys,
      customChatbotPrompt: json['customChatbotPrompt'] as String?,
      customReflectionPrompt: json['customReflectionPrompt'] as String?,
      customBriefingPrompt: json['customBriefingPrompt'] as String?,
      savedPrompts: (json['savedPrompts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      startOfWeek: json['startOfWeek'] as int? ?? 1,
      dataVersion: json['dataVersion'] as int? ?? 0,
      lastModified: json['lastModified'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      journalPin: json['journalPin'] as String?,
      noraAccessSessions: json['noraAccessSessions'] as bool? ?? false,
      noraAccessFinance: json['noraAccessFinance'] as bool? ?? false,
      habitRules: (json['habitRules'] as List<dynamic>?)
              ?.map((e) => HabitRule.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      somedayList: (json['somedayList'] as List<dynamic>?)
              ?.map((e) => SomedayItem.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      hasCompletedTour: json['hasCompletedTour'] as bool? ?? false,
      customBusSchedules: json['customBusSchedules'] != null 
          ? (json['customBusSchedules'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
                (k2, v2) => MapEntry(k2, (v2 as List<dynamic>).map((e) => e.toString()).toList())
              ))
            )
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'descriptionsVisible': descriptionsVisible,
      'dailyAutoGenerateContent': dailyAutoGenerateContent,
      'autoSaveEnabled': autoSaveEnabled,
      'wakeupTimeHour': wakeupTimeHour,
      'wakeupTimeMinute': wakeupTimeMinute,
      'liteModels': liteModels,
      'heavyModels': heavyModels,
      'customApiKeys': customApiKeys,
      'customChatbotPrompt': customChatbotPrompt,
      'customReflectionPrompt': customReflectionPrompt,
      'customBriefingPrompt': customBriefingPrompt,
      'savedPrompts': savedPrompts,
      'startOfWeek': startOfWeek,
      'dataVersion': dataVersion,
      'lastModified': lastModified,
      'journalPin': journalPin,
      'noraAccessSessions': noraAccessSessions,
      'noraAccessFinance': noraAccessFinance,
      'habitRules': habitRules.map((e) => e.toJson()).toList(),
      'somedayList': somedayList.map((e) => e.toJson()).toList(),
      'hasCompletedTour': hasCompletedTour,
      'customBusSchedules': customBusSchedules,
    };
  }
}

class ActiveTimerInfo {
  DateTime startTime;
  double accumulatedDisplayTime; // In seconds
  bool isRunning;
  String type;
  String mainTaskId;

  ActiveTimerInfo({
    required this.startTime,
    this.accumulatedDisplayTime = 0,
    required this.isRunning,
    required this.type,
    required this.mainTaskId,
  });

  factory ActiveTimerInfo.fromJson(Map<String, dynamic> json) {
    return ActiveTimerInfo(
      startTime: DateTime.parse(json['startTime'] as String),
      accumulatedDisplayTime:
          (json['accumulatedDisplayTime'] as num? ?? 0).toDouble(),
      isRunning: json['isRunning'] as bool? ?? false,
      type: json['type'] as String? ?? 'subtask',
      mainTaskId: json['mainTaskId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'accumulatedDisplayTime': accumulatedDisplayTime,
      'isRunning': isRunning,
      'type': type,
      'mainTaskId': mainTaskId,
    };
  }
}
