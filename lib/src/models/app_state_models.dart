// lib/src/models/app_state_models.dart
import 'package:missions/src/models/habit_models.dart';
import 'package:uuid/uuid.dart';

class ReflectionDraft {
  final String trigger;
  final String emotion;
  final String reason;
  final String action;
  final double energyLevel;
  final DateTime savedAt;

  const ReflectionDraft({
    required this.trigger,
    required this.emotion,
    required this.reason,
    required this.action,
    required this.energyLevel,
    required this.savedAt,
  });

  bool get isEmpty =>
      trigger.isEmpty && emotion.isEmpty && reason.isEmpty && action.isEmpty;

  factory ReflectionDraft.fromJson(Map<String, dynamic> json) => ReflectionDraft(
        trigger: json['trigger'] as String? ?? '',
        emotion: json['emotion'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        action: json['action'] as String? ?? '',
        energyLevel: (json['energyLevel'] as num? ?? 5).toDouble(),
        savedAt: json['savedAt'] != null
            ? DateTime.parse(json['savedAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'trigger': trigger,
        'emotion': emotion,
        'reason': reason,
        'action': action,
        'energyLevel': energyLevel,
        'savedAt': savedAt.toIso8601String(),
      };
}

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

/// A persisted reminder. Persisting these (rather than only handing them to
/// the OS scheduler) is what lets the app show a list of "what is scheduled"
/// and re-arm everything on launch.
class ScheduledReminder {
  String id; // stable, deterministic per target (e.g. 'task_<subId>')
  String title;
  String body;

  /// 'task' | 'planner' | 'custom'
  String type;

  /// 'once' | 'daily'
  String repeat;

  /// For repeat == 'once'.
  DateTime? time;

  /// For repeat == 'daily'.
  int hour;
  int minute;

  bool enabled;

  // Optional linkage back to the thing that owns this reminder.
  String? mainTaskId;
  String? subtaskId;
  String? compoundId; // day-plan compound id ("mainId|subId[|cpId]")

  ScheduledReminder({
    required this.id,
    required this.title,
    this.body = '',
    this.type = 'custom',
    this.repeat = 'once',
    this.time,
    this.hour = 9,
    this.minute = 0,
    this.enabled = true,
    this.mainTaskId,
    this.subtaskId,
    this.compoundId,
  });

  /// Stable notification id for the OS scheduler, derived from [id] so the
  /// same logical reminder always cancels/reschedules against the same slot.
  /// Kept well clear of the fixed ids (1001 insight, 2001 timer, 3001 reflect).
  int get notificationId => 100000 + (id.hashCode.abs() % 800000);

  /// The next moment this reminder will fire (for sorting / display).
  DateTime? get nextFire {
    if (repeat == 'daily') {
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, hour, minute);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      return next;
    }
    return time;
  }

  bool get isActive {
    if (!enabled) return false;
    if (repeat == 'daily') return true;
    return time != null && time!.isAfter(DateTime.now());
  }

  ScheduledReminder copyWith({
    String? title,
    String? body,
    String? type,
    String? repeat,
    DateTime? time,
    bool clearTime = false,
    int? hour,
    int? minute,
    bool? enabled,
    String? mainTaskId,
    String? subtaskId,
    String? compoundId,
  }) {
    return ScheduledReminder(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      repeat: repeat ?? this.repeat,
      time: clearTime ? null : (time ?? this.time),
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      mainTaskId: mainTaskId ?? this.mainTaskId,
      subtaskId: subtaskId ?? this.subtaskId,
      compoundId: compoundId ?? this.compoundId,
    );
  }

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) {
    return ScheduledReminder(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Reminder',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'custom',
      repeat: json['repeat'] as String? ?? 'once',
      time: json['time'] != null ? DateTime.tryParse(json['time'] as String) : null,
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      mainTaskId: json['mainTaskId'] as String?,
      subtaskId: json['subtaskId'] as String?,
      compoundId: json['compoundId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'repeat': repeat,
        'time': time?.toIso8601String(),
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'mainTaskId': mainTaskId,
        'subtaskId': subtaskId,
        'compoundId': compoundId,
      };
}

class AppSettings {
  bool descriptionsVisible;
  bool dailyAutoGenerateContent;
  bool autoSaveEnabled;
  bool dayPlannerWidgetCheckable;
  int wakeupTimeHour;
  int wakeupTimeMinute;
  List<String> liteModels;
  List<String> heavyModels;
  List<String> liveModels;
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

  // Reflection draft (autosaved when user navigates away mid-entry)
  ReflectionDraft? reflectionDraft;

  // Notification reminders
  bool reflectionReminderEnabled;
  int reflectionReminderHour;
  int reflectionReminderMinute;
  bool submissionReminderEnabled;
  int submissionReminderHour;
  int submissionReminderMinute;
  bool financeReminderEnabled;
  int financeReminderHour;
  int financeReminderMinute;

  // Persisted user reminders (task / planner / custom) shown in the
  // Scheduled Reminders screen and re-armed on launch.
  List<ScheduledReminder> scheduledReminders;

  // Writing style adaptation
  bool adaptWritingStyle;
  String? writingStyleMap;

  // Story Mode Character Choice
  String storyCharacter;

  AppSettings({
    this.descriptionsVisible = true,
    this.dailyAutoGenerateContent = true,
    this.autoSaveEnabled = true,
    this.dayPlannerWidgetCheckable = false,
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
    this.liveModels = const [
      'gemini-3.1-flash-live-preview',
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
    this.reflectionDraft,
    this.reflectionReminderEnabled = false,
    this.reflectionReminderHour = 20,
    this.reflectionReminderMinute = 0,
    this.submissionReminderEnabled = false,
    this.submissionReminderHour = 9,
    this.submissionReminderMinute = 0,
    this.financeReminderEnabled = false,
    this.financeReminderHour = 18,
    this.financeReminderMinute = 0,
    List<ScheduledReminder>? scheduledReminders,
    this.adaptWritingStyle = false,
    this.writingStyleMap,
    this.storyCharacter = 'Ayan',
  })  : scheduledReminders = scheduledReminders ?? [],
        lastModified = lastModified ?? DateTime.now().millisecondsSinceEpoch;

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
      dayPlannerWidgetCheckable: json['dayPlannerWidgetCheckable'] as bool? ?? false,
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
      liveModels: (json['liveModels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['gemini-3.1-flash-live-preview'],
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
      reflectionDraft: json['reflectionDraft'] != null
          ? ReflectionDraft.fromJson(json['reflectionDraft'] as Map<String, dynamic>)
          : null,
      reflectionReminderEnabled: json['reflectionReminderEnabled'] as bool? ?? false,
      reflectionReminderHour: json['reflectionReminderHour'] as int? ?? 20,
      reflectionReminderMinute: json['reflectionReminderMinute'] as int? ?? 0,
      submissionReminderEnabled: json['submissionReminderEnabled'] as bool? ?? false,
      submissionReminderHour: json['submissionReminderHour'] as int? ?? 9,
      submissionReminderMinute: json['submissionReminderMinute'] as int? ?? 0,
      financeReminderEnabled: json['financeReminderEnabled'] as bool? ?? false,
      financeReminderHour: json['financeReminderHour'] as int? ?? 18,
      financeReminderMinute: json['financeReminderMinute'] as int? ?? 0,
      scheduledReminders: (json['scheduledReminders'] as List<dynamic>?)
              ?.map((e) => ScheduledReminder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customBusSchedules: json['customBusSchedules'] != null
          ? (json['customBusSchedules'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
                (k2, v2) => MapEntry(k2, (v2 as List<dynamic>).map((e) => e.toString()).toList())
              ))
            )
          : null,
      adaptWritingStyle: json['adaptWritingStyle'] as bool? ?? false,
      writingStyleMap: json['writingStyleMap'] as String?,
      storyCharacter: json['storyCharacter'] as String? ?? 'Ayan',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'descriptionsVisible': descriptionsVisible,
      'dailyAutoGenerateContent': dailyAutoGenerateContent,
      'autoSaveEnabled': autoSaveEnabled,
      'dayPlannerWidgetCheckable': dayPlannerWidgetCheckable,
      'wakeupTimeHour': wakeupTimeHour,
      'wakeupTimeMinute': wakeupTimeMinute,
      'liteModels': liteModels,
      'heavyModels': heavyModels,
      'liveModels': liveModels,
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
      'reflectionDraft': reflectionDraft?.toJson(),
      'reflectionReminderEnabled': reflectionReminderEnabled,
      'reflectionReminderHour': reflectionReminderHour,
      'reflectionReminderMinute': reflectionReminderMinute,
      'submissionReminderEnabled': submissionReminderEnabled,
      'submissionReminderHour': submissionReminderHour,
      'submissionReminderMinute': submissionReminderMinute,
      'financeReminderEnabled': financeReminderEnabled,
      'financeReminderHour': financeReminderHour,
      'financeReminderMinute': financeReminderMinute,
      'scheduledReminders': scheduledReminders.map((e) => e.toJson()).toList(),
      'customBusSchedules': customBusSchedules,
      'adaptWritingStyle': adaptWritingStyle,
      'writingStyleMap': writingStyleMap,
      'storyCharacter': storyCharacter,
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
