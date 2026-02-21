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
  String? customContext; // Added for simulations

  NoraSession({
    required this.id,
    required this.title,
    required this.tone,
    required this.startDate,
    required this.endDate,
    List<ChatbotMessage>? messages,
    DateTime? createdAt,
    this.customContext,
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

class ChatbotMemory {
  List<ChatbotMessage> conversationHistory;
  String? lastWeeklySummary;
  List<String> dailyCompletedGoals;
  List<String> userRememberedItems;

  // Features for Nora
  List<NoraSession> noraSessions;
  String? activeNoraSessionId;

  // New features for advanced tools
  List<PersonInfo> people;

  ChatbotMemory({
    List<ChatbotMessage>? conversationHistory,
    this.lastWeeklySummary,
    List<String>? dailyCompletedGoals,
    List<String>? userRememberedItems,
    List<NoraSession>? noraSessions,
    this.activeNoraSessionId,
    List<PersonInfo>? people,
  })  : conversationHistory = conversationHistory ?? [],
        dailyCompletedGoals = dailyCompletedGoals ?? [],
        userRememberedItems = userRememberedItems ?? [],
        noraSessions = noraSessions ?? [],
        people = people ?? [];

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
    };
  }
}