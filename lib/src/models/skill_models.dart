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
    return Skill(
      id: json['id'] as String? ?? 'unknown_skill',
      name: json['name'] as String? ?? 'Unknown Virtue',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? 0,
      maxXp: json['maxXp'] as int? ?? 100,
      description: json['description'] as String? ?? "A core virtue."
    );
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

  // Returns true if leveled up
  bool addXp(int amount) {
    currentXp += amount;
    bool leveledUp = false;
    while (currentXp >= maxXp) {
      currentXp -= maxXp;
      level++;
      // Increase requirement by 20% each level
      maxXp = (maxXp * 1.2).round();
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
  final String aiFeedback;
  final Map<String, int> xpGained;

  ReflectionLog({
    required this.id,
    required this.timestamp,
    required this.trigger,
    required this.emotion,
    required this.reason,
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
      'aiFeedback': aiFeedback,
      'xpGained': xpGained,
    };
  }
}