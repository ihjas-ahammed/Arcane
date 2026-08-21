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
  String? personaId;
  
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
    this.personaId,
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
      personaId: json['personaId'] as String?,
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
      'personaId': personaId,
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

  // New range & manual entries fields
  DateTime? scanRangeStart;
  DateTime? scanRangeEnd;
  int? manualAge;
  String? manualGender;
  String? manualNotes;
  String? manualNextMeetPlan;
  List<String>? manualLastContactIntel;

  // Additional Biodata Fields
  String? manualOccupation;
  String? manualLocation;
  String? manualBirthday;
  String? manualContact;

  PersonInfo({
    required this.id,
    required this.name,
    required this.relation,
    this.details,
    this.lastUpdated,
    this.scanRangeStart,
    this.scanRangeEnd,
    this.manualAge,
    this.manualGender,
    this.manualNotes,
    this.manualNextMeetPlan,
    this.manualLastContactIntel,
    this.manualOccupation,
    this.manualLocation,
    this.manualBirthday,
    this.manualContact,
  });

  /// Categorize any relationship string into standard default categories
  static String getRelationCategory(String relation) {
    final rel = relation.toLowerCase().trim();
    if (rel.contains('spouse') || rel.contains('partner') || rel.contains('wife') || rel.contains('husband') ||
        rel.contains('mother') || rel.contains('father') || rel.contains('parent') || rel.contains('sibling') ||
        rel.contains('sister') || rel.contains('brother') || rel.contains('family') || rel.contains('son') ||
        rel.contains('daughter') || rel.contains('girlfriend') || rel.contains('boyfriend') ||
        rel.contains('mom') || rel.contains('dad') || rel.contains('cousin') || rel.contains('uncle') || rel.contains('aunt') ||
        rel.contains('grandmother') || rel.contains('grandfather') || rel.contains('grandma') || rel.contains('grandpa')) {
      return 'Family & Partner';
    }
    if (rel.contains('friend') || rel.contains('buddy') || rel.contains('mate') || rel.contains('bestie') || rel.contains('pal') || rel.contains('roommate')) {
      return 'Friends';
    }
    if (rel.contains('boss') || rel.contains('colleague') || rel.contains('mentor') || rel.contains('manager') ||
        rel.contains('teacher') || rel.contains('coworker') || rel.contains('work') || rel.contains('client') ||
        rel.contains('advisor') || rel.contains('lead') || rel.contains('director') || rel.contains('prof') ||
        rel.contains('professor') || rel.contains('doctor') || rel.contains('investor')) {
      return 'Professional & Mentors';
    }
    return 'Acquaintances & Others';
  }

  String get defaultCategory => getRelationCategory(relation);

  factory PersonInfo.fromJson(Map<String, dynamic> json) {
    return PersonInfo(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Unknown',
      relation: json['relation'] as String? ?? 'Acquaintance',
      details: json['details'] as String?,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
      scanRangeStart: json['scanRangeStart'] != null
          ? DateTime.parse(json['scanRangeStart'] as String)
          : null,
      scanRangeEnd: json['scanRangeEnd'] != null
          ? DateTime.parse(json['scanRangeEnd'] as String)
          : null,
      manualAge: json['manualAge'] as int?,
      manualGender: json['manualGender'] as String?,
      manualNotes: json['manualNotes'] as String?,
      manualNextMeetPlan: json['manualNextMeetPlan'] as String?,
      manualLastContactIntel: json['manualLastContactIntel'] != null
          ? List<String>.from(json['manualLastContactIntel'] as List)
          : null,
      manualOccupation: json['manualOccupation'] as String?,
      manualLocation: json['manualLocation'] as String?,
      manualBirthday: json['manualBirthday'] as String?,
      manualContact: json['manualContact'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'details': details,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'scanRangeStart': scanRangeStart?.toIso8601String(),
      'scanRangeEnd': scanRangeEnd?.toIso8601String(),
      'manualAge': manualAge,
      'manualGender': manualGender,
      'manualNotes': manualNotes,
      'manualNextMeetPlan': manualNextMeetPlan,
      'manualLastContactIntel': manualLastContactIntel,
      'manualOccupation': manualOccupation,
      'manualLocation': manualLocation,
      'manualBirthday': manualBirthday,
      'manualContact': manualContact,
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

class NoraAgentSkill {
  final String id;
  final String name;
  final String description;
  final String instructions;

  NoraAgentSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
  });

  factory NoraAgentSkill.fromJson(Map<String, dynamic> json) {
    return NoraAgentSkill(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'instructions': instructions,
    };
  }
}

class NoraMemoryItem {
  final String id;
  final String key;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoraMemoryItem({
    required this.id,
    required this.key,
    required this.content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NoraMemoryItem.fromJson(Map<String, dynamic> json) {
    return NoraMemoryItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      key: json['key'] as String? ?? 'general',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NoraMemoryItem copyWith({
    String? key,
    String? content,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return NoraMemoryItem(
      id: id,
      key: key ?? this.key,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class NoraPersona {
  final String id;
  final String name;
  final String tagline;
  final String avatarIcon;
  final String systemPrompt;
  final String greetingMessage;
  final bool isBuiltIn;
  final String sourceType; // 'builtin' | 'movie_character' | 'whatsapp_chat' | 'custom'
  final List<NoraMemoryItem> memorySpace;
  final DateTime createdAt;

  NoraPersona({
    required this.id,
    required this.name,
    required this.tagline,
    this.avatarIcon = 'creation',
    required this.systemPrompt,
    this.greetingMessage = "Hello. How can I assist you today?",
    this.isBuiltIn = false,
    this.sourceType = 'custom',
    List<NoraMemoryItem>? memorySpace,
    DateTime? createdAt,
  })  : memorySpace = memorySpace ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory NoraPersona.fromJson(Map<String, dynamic> json) {
    return NoraPersona(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Assistant',
      tagline: json['tagline'] as String? ?? '',
      avatarIcon: json['avatarIcon'] as String? ?? 'creation',
      systemPrompt: json['systemPrompt'] as String? ?? 'You are NORA.',
      greetingMessage: json['greetingMessage'] as String? ?? 'Hello.',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      sourceType: json['sourceType'] as String? ?? 'custom',
      memorySpace: (json['memorySpace'] as List<dynamic>?)
              ?.map((m) => NoraMemoryItem.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'avatarIcon': avatarIcon,
      'systemPrompt': systemPrompt,
      'greetingMessage': greetingMessage,
      'isBuiltIn': isBuiltIn,
      'sourceType': sourceType,
      'memorySpace': memorySpace.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  NoraPersona copyWith({
    String? name,
    String? tagline,
    String? avatarIcon,
    String? systemPrompt,
    String? greetingMessage,
    bool? isBuiltIn,
    String? sourceType,
    List<NoraMemoryItem>? memorySpace,
  }) {
    return NoraPersona(
      id: id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      greetingMessage: greetingMessage ?? this.greetingMessage,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sourceType: sourceType ?? this.sourceType,
      memorySpace: memorySpace ?? this.memorySpace,
      createdAt: createdAt,
    );
  }

  static List<NoraPersona> defaultBuiltInPersonas() {
    return [
      NoraPersona(
        id: 'persona_assistant',
        name: 'Assistant',
        tagline: 'Tactical productivity and daily orchestrator',
        avatarIcon: 'creation',
        isBuiltIn: true,
        sourceType: 'builtin',
        systemPrompt: 'You are NORA, a sharp, ultra-efficient tactical assistant. You help the user manage goals, track progress, navigate life tasks, and stay on top of reflections.',
        greetingMessage: "Hello, Operative. I'm NORA. How can I assist with your objectives today?",
      ),
      NoraPersona(
        id: 'persona_therapist',
        name: 'Therapist',
        tagline: 'Compassionate psychological counselor & emotional mirror',
        avatarIcon: 'heart-pulse',
        isBuiltIn: true,
        sourceType: 'builtin',
        systemPrompt: 'You are NORA in Therapist Mode. Grounded in positive psychology, CBT, and empathetic inquiry. You listen attentively, validate emotional states, explore triggers and underlying needs, and guide the user toward clarity without judgment.',
        greetingMessage: "Welcome. Take a deep breath. Whatever you're feeling right now, I'm here to listen and explore with you.",
      ),
      NoraPersona(
        id: 'persona_philosopher',
        name: 'Philosopher',
        tagline: 'Stoic thinker & Socratic mentor exploring deep questions',
        avatarIcon: 'school',
        isBuiltIn: true,
        sourceType: 'builtin',
        systemPrompt: 'You are NORA in Philosopher Mode. Grounded in Stoicism, existentialism, Socratic dialogue, and timeless wisdom. You challenge assumptions with kindness, encourage virtuous action, and find meaning in obstacles.',
        greetingMessage: "Greetings, fellow seeker. What ideas, questions, or quandaries are occupying your mind today?",
      ),
      NoraPersona(
        id: 'persona_tactician',
        name: 'Tactical Commander',
        tagline: 'Ruthless focus, military clarity & GTD next-action discipline',
        avatarIcon: 'target-account',
        isBuiltIn: true,
        sourceType: 'builtin',
        systemPrompt: 'You are NORA in Tactical Commander Mode. Direct, concise, no-nonsense. You demand clarity of objectives, identify friction, prioritize high-leverage execution, and enforce ruthless discipline.',
        greetingMessage: "Standing by for mission parameters. State your objective and current roadblock.",
      ),
      NoraPersona(
        id: 'persona_friend',
        name: 'Friend',
        tagline: 'Casual, supportive buddy who knows your life story',
        avatarIcon: 'account-heart',
        isBuiltIn: true,
        sourceType: 'builtin',
        systemPrompt: 'You are NORA as a close, warm, genuine best friend. You talk casually, use relaxed language, celebrate the user’s wins, check in on how they are actually doing, and give real talk when they need it.',
        greetingMessage: "Hey! What's up? How are you really doing today?",
      ),
    ];
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
  List<NoraAgentSkill> noraAgentSkills;
  List<NoraPersona> customPersonas;

  ChatbotMemory({
    List<ChatbotMessage>? conversationHistory,
    this.lastWeeklySummary,
    List<String>? dailyCompletedGoals,
    List<String>? userRememberedItems,
    List<NoraSession>? noraSessions,
    this.activeNoraSessionId,
    List<PersonInfo>? people,
    List<GratitudeItem>? gratitudeList,
    List<NoraAgentSkill>? noraAgentSkills,
    List<NoraPersona>? customPersonas,
  })  : conversationHistory = conversationHistory ?? [],
        dailyCompletedGoals = dailyCompletedGoals ?? [],
        userRememberedItems = userRememberedItems ?? [],
        noraSessions = noraSessions ?? [],
        people = people ?? [],
        gratitudeList = gratitudeList ?? [],
        noraAgentSkills = noraAgentSkills ?? [],
        customPersonas = customPersonas ?? [];

  /// Returns all available personas: standard built-in plus user-created characters.
  List<NoraPersona> get allPersonas {
    final builtins = NoraPersona.defaultBuiltInPersonas();
    // Merge any memory space stored in customPersonas matching builtin IDs
    final result = <NoraPersona>[];
    for (final b in builtins) {
      final customMatch = customPersonas.firstWhere((c) => c.id == b.id, orElse: () => b);
      if (customMatch != b) {
        result.add(b.copyWith(memorySpace: customMatch.memorySpace));
      } else {
        result.add(b);
      }
    }
    for (final c in customPersonas) {
      if (!builtins.any((b) => b.id == c.id)) {
        result.add(c);
      }
    }
    return result;
  }

  /// Finds persona by ID, or falls back to tone name, or returns default Assistant.
  NoraPersona getPersona(String? idOrTone) {
    if (idOrTone == null || idOrTone.isEmpty) {
      return NoraPersona.defaultBuiltInPersonas().first;
    }
    final all = allPersonas;
    final match = all.firstWhere(
      (p) => p.id == idOrTone || p.name.toLowerCase() == idOrTone.toLowerCase(),
      orElse: () => all.first,
    );
    return match;
  }

  /// Adds or updates a custom persona.
  void saveCustomPersona(NoraPersona persona) {
    final idx = customPersonas.indexWhere((p) => p.id == persona.id);
    if (idx != -1) {
      customPersonas[idx] = persona;
    } else {
      customPersonas.add(persona);
    }
  }

  /// Deletes a custom persona by ID.
  void deleteCustomPersona(String id) {
    customPersonas.removeWhere((p) => p.id == id);
  }

  /// Adds or updates a memory item in a persona's dedicated memory space.
  void addPersonaMemoryItem(String personaId, NoraMemoryItem item) {
    final persona = getPersona(personaId);
    final updatedList = List<NoraMemoryItem>.from(persona.memorySpace);
    final existingIdx = updatedList.indexWhere((m) => m.id == item.id || m.key.toLowerCase() == item.key.toLowerCase());
    if (existingIdx != -1) {
      updatedList[existingIdx] = item.copyWith(updatedAt: DateTime.now());
    } else {
      updatedList.insert(0, item);
    }
    saveCustomPersona(persona.copyWith(memorySpace: updatedList));
  }

  /// Deletes a memory item from a persona's dedicated memory space.
  void deletePersonaMemoryItem(String personaId, String memoryIdOrKey) {
    final persona = getPersona(personaId);
    final updatedList = List<NoraMemoryItem>.from(persona.memorySpace)
      ..removeWhere((m) => m.id == memoryIdOrKey || m.key.toLowerCase() == memoryIdOrKey.toLowerCase());
    saveCustomPersona(persona.copyWith(memorySpace: updatedList));
  }

  /// Gets all memory items for a persona.
  List<NoraMemoryItem> getPersonaMemories(String personaId) {
    return getPersona(personaId).memorySpace;
  }

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
      noraAgentSkills: (json['noraAgentSkills'] as List<dynamic>?)
              ?.map((skillJson) =>
                  NoraAgentSkill.fromJson(skillJson as Map<String, dynamic>))
              .toList() ??
          [],
      customPersonas: (json['customPersonas'] as List<dynamic>?)
              ?.map((pJson) =>
                  NoraPersona.fromJson(pJson as Map<String, dynamic>))
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
      'noraAgentSkills': noraAgentSkills.map((skill) => skill.toJson()).toList(),
      'customPersonas': customPersonas.map((p) => p.toJson()).toList(),
    };
  }
}