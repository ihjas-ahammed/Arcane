// lib/src/models/chatbot_models.dart

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

class ChatbotMemory {
  List<ChatbotMessage> conversationHistory;
  String? lastWeeklySummary;
  List<String> dailyCompletedGoals;
  List<String> userRememberedItems;

  ChatbotMemory({
    List<ChatbotMessage>? conversationHistory,
    this.lastWeeklySummary,
    List<String>? dailyCompletedGoals,
    List<String>? userRememberedItems,
  })  : conversationHistory = conversationHistory ?? [],
        dailyCompletedGoals = dailyCompletedGoals ?? [],
        userRememberedItems = userRememberedItems ?? [];

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationHistory':
          conversationHistory.map((msg) => msg.toJson()).toList(),
      'lastWeeklySummary': lastWeeklySummary,
      'dailyCompletedGoals': dailyCompletedGoals,
      'userRememberedItems': userRememberedItems,
    };
  }
}