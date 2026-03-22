// lib/src/models/chatbot_models.dart
import 'package:uuid/uuid.dart';

enum MessageSender { user, bot }
enum DynamicUiType { graph, unknown }

class DynamicUiPayload {
  final DynamicUiType type;
  final Map<String, dynamic> data;

  DynamicUiPayload({required this.type, required this.data});

  factory DynamicUiPayload.fromJson(Map<String, dynamic> json) {
    DynamicUiType uiType;
    try {
      uiType = DynamicUiType.values.firstWhere((e) =>
          e.toString() ==
          'DynamicUiType.${json['type'] as String? ?? 'unknown'}');
    } catch (e) {
      uiType = DynamicUiType.unknown;
    }
    return DynamicUiPayload(
      type: uiType,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'data': data,
    };
  }
}

class ChatbotMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final DynamicUiPayload? uiPayload;

  ChatbotMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.uiPayload,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: MessageSender.values
          .firstWhere((e) => e.toString() == json['sender'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      uiPayload: json['uiPayload'] != null
          ? DynamicUiPayload.fromJson(json['uiPayload'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.toString(),
      'timestamp': timestamp.toIso8601String(),
      'uiPayload': uiPayload?.toJson(),
    };
  }
}

class NoraSession {
  final String id;
  String title;
  String tone;
  DateTime startDate;
  DateTime endDate;
  List<ChatbotMessage> messages;
  final DateTime createdAt;
  String? customContext; 
  
  // Advanced Controls
  int messageLimit;
  String? modelOverride;
  int contextDays;
  String? systemPromptOverride;

  NoraSession({
    required this.id,
    required this.title,
    required this.tone,
    required this.startDate,
    required this.endDate,
    List<ChatbotMessage>? messages,
    DateTime? createdAt,
    this.customContext,
    this.messageLimit = 0,
    this.modelOverride,
    this.contextDays = 7,
    this.systemPromptOverride,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory NoraSession.fromJson(Map<String, dynamic> json) {
    return NoraSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Session',
      tone: json['tone'] as String? ?? 'Assistant',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((msgJson) => ChatbotMessage.fromJson(msgJson as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      customContext: json['customContext'] as String?,
      messageLimit: (json['messageLimit'] as num?)?.toInt() ?? 0,
      modelOverride: json['modelOverride'] as String?,
      contextDays: (json['contextDays'] as num?)?.toInt() ?? 7,
      systemPromptOverride: json['systemPromptOverride'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'tone': tone,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'customContext': customContext,
      'messageLimit': messageLimit,
      'modelOverride': modelOverride,
      'contextDays': contextDays,
      'systemPromptOverride': systemPromptOverride,
    };
  }
}

class PersonInfo {
  String id;
  String name;
  String relation;
  String? details;
  DateTime? lastUpdated;

  PersonInfo({
    required this.id,
    required this.name,
    required this.relation,
    this.details,
    this.lastUpdated,
  });

  factory PersonInfo.fromJson(Map<String, dynamic> json) {
    return PersonInfo(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Unknown',
      relation: json['relation'] as String? ?? 'Acquaintance',
      details: json['details'] as String?,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'details': details,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}

class GratitudeItem {
  String id;
  String type; // 'skill', 'object', 'person', 'resource'
  String name;
  String why;
  String how;
  String what;

  GratitudeItem({
    required this.id,
    required this.type,
    required this.name,
    this.why = '',
    this.how = '',
    this.what = '',
  });

  factory GratitudeItem.fromJson(Map<String, dynamic> json) {
    // FIX: Self-healing ID for legacy corrupted items that used empty strings
    String parsedId = json['id'] as String? ?? '';
    if (parsedId.trim().isEmpty) {
      parsedId = const Uuid().v4();
    }

    return GratitudeItem(
      id: parsedId,
      type: json['type'] as String? ?? 'resource',
      name: json['name'] as String? ?? 'Unknown',
      why: json['why'] as String? ?? '',
      how: json['how'] as String? ?? '',
      what: json['what'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'why': why,
      'how': how,
      'what': what,
    };
  }
}

class ChatbotMemory {
  List<ChatbotMessage> conversationHistory;
  String? lastWeeklySummary;
  List<String> dailyCompletedGoals;
  List<String> userRememberedItems;

  List<NoraSession> noraSessions;
  String? activeNoraSessionId;

  List<PersonInfo> people;
  
  List<GratitudeItem> gratitudeList; 

  ChatbotMemory({
    List<ChatbotMessage>? conversationHistory,
    this.lastWeeklySummary,
    List<String>? dailyCompletedGoals,
    List<String>? userRememberedItems,
    List<NoraSession>? noraSessions,
    this.activeNoraSessionId,
    List<PersonInfo>? people,
    List<GratitudeItem>? gratitudeList,
  })  : conversationHistory = conversationHistory ?? [],
        dailyCompletedGoals = dailyCompletedGoals ?? [],
        userRememberedItems = userRememberedItems ?? [],
        noraSessions = noraSessions ?? [],
        people = people ?? [],
        gratitudeList = gratitudeList ?? [];

  factory ChatbotMemory.fromJson(Map<String, dynamic> json) {
    return ChatbotMemory(
      conversationHistory: (json['conversationHistory'] as List<dynamic>?)
              ?.map((msgJson) =>
                  ChatbotMessage.fromJson(msgJson as Map<String, dynamic>))
              .toList() ??
          [],
      lastWeeklySummary: json['lastWeeklySummary'] as String?,
      dailyCompletedGoals: (json['dailyCompletedGoals'] as List<dynamic>?)
              ?.map((goal) => goal as String)
              .toList() ??
          [],
      userRememberedItems: (json['userRememberedItems'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          [],
      noraSessions: (json['noraSessions'] as List<dynamic>?)
              ?.map((sessionJson) =>
                  NoraSession.fromJson(sessionJson as Map<String, dynamic>))
              .toList() ??
          [],
      activeNoraSessionId: json['activeNoraSessionId'] as String?,
      people: (json['people'] as List<dynamic>?)
              ?.map((personJson) =>
                  PersonInfo.fromJson(personJson as Map<String, dynamic>))
              .toList() ??
          [],
      gratitudeList: (json['gratitudeList'] as List<dynamic>?)
              ?.map((item) {
                if (item is String) {
                  return GratitudeItem(id: const Uuid().v4(), type: 'resource', name: item);
                } else if (item is Map<String, dynamic>) {
                  return GratitudeItem.fromJson(item);
                }
                return GratitudeItem(id: const Uuid().v4(), type: 'resource', name: 'Unknown');
              })
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationHistory': conversationHistory.map((msg) => msg.toJson()).toList(),
      'lastWeeklySummary': lastWeeklySummary,
      'dailyCompletedGoals': dailyCompletedGoals,
      'userRememberedItems': userRememberedItems,
      'noraSessions': noraSessions.map((session) => session.toJson()).toList(),
      'activeNoraSessionId': activeNoraSessionId,
      'people': people.map((person) => person.toJson()).toList(),
      'gratitudeList': gratitudeList.map((item) => item.toJson()).toList(),
    };
  }
}