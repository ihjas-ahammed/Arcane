// lib/src/models/skill_models.dart

class Skill {
  final String id;
  final String name;
  final String description;
  int level;
  int currentXp;
  int maxXp;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    this.level = 1,
    this.currentXp = 0,
    this.maxXp = 100,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    String name = (json['name'] as String? ??
            json['skillName'] as String? ??
            'Unknown Virtue')
        .trim();

    // Attempt to recover ID if missing or generic
    String id = json['id'] as String? ?? 'unknown_skill';
    if (id == 'unknown_skill') {
      final n = name.toLowerCase();
      if (n.contains('wisdom') ||
          n.contains('tech') ||
          n.contains('learning')) {
        id = 'wis';
      } else if (n.contains('courage') || n.contains('health')) {
        id = 'cou';
      } else if (n.contains('humanity') || n.contains('social')) {
        id = 'hum';
      } else if (n.contains('justice') || n.contains('work')) {
        id = 'jus';
      } else if (n.contains('temperance') || n.contains('order')) {
        id = 'tem';
      } else if (n.contains('transcendence') || n.contains('creative')) {
        id = 'tra';
      }
    }

    return Skill(
        id: id,
        name: name,
        level: (json['level'] as num?)?.toInt() ?? 1,
        currentXp: (json['currentXp'] as num?)?.toInt() ?? 0,
        maxXp: (json['maxXp'] as num?)?.toInt() ?? 100,
        description: json['description'] as String? ?? "A core virtue.");
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'currentXp': currentXp,
      'maxXp': maxXp,
      'description': description,
    };
  }

  // Fallback direct modifier (System relies on recalculateFromTotal7DayXp primarily)
  bool addXp(int amount) {
    currentXp += amount;
    bool leveledUp = false;
    while (currentXp >= maxXp) {
      currentXp -= maxXp;
      level++;
      // Exponentially increasing requirement
      maxXp = (maxXp * 1.15).round();
      leveledUp = true;
    }
    return leveledUp;
  }
}

class ReflectionLog {
  final String id;
  final DateTime timestamp;
  String trigger;
  String emotion;
  String reason;
  String action; 
  final String aiFeedback;
  final Map<String, int> xpGained;

  ReflectionLog({
    required this.id,
    required this.timestamp,
    required this.trigger,
    required this.emotion,
    required this.reason,
    this.action = '',
    required this.aiFeedback,
    required this.xpGained,
  });

  factory ReflectionLog.fromJson(Map<String, dynamic> json) {
    return ReflectionLog(
      id: json['id'] as String? ?? 'unknown',
      timestamp: DateTime.parse(json['timestamp'] as String),
      trigger: json['trigger'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      action: json['action'] as String? ?? '', 
      aiFeedback: json['aiFeedback'] as String? ?? '',
      xpGained: Map<String, int>.from(json['xpGained'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'trigger': trigger,
      'emotion': emotion,
      'reason': reason,
      'action': action,
      'aiFeedback': aiFeedback,
      'xpGained': xpGained,
    };
  }
}