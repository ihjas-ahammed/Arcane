// lib/src/models/skill_models.dart
import 'package:missions/src/theme/wellbeing_theme.dart';


class Skill {
  final String id;
  final String name;
  final String description;

  Skill({
    required this.id,
    required this.name,
    required this.description,
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
        description: json['description'] as String? ?? "A core virtue.");
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
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
  /// How much of this reflection touched each well-being area (0-100). Only ever shown as a
  /// share of one day's reflections; never summed over time.
  final Map<String, int> needs;

  ReflectionLog({
    required this.id,
    required this.timestamp,
    required this.trigger,
    required this.emotion,
    required this.reason,
    this.action = '',
    required this.aiFeedback,
    required this.needs,
  });

  factory ReflectionLog.fromJson(Map<String, dynamic> json) {
    final rawNeeds = Map<String, dynamic>.from((json['needs'] ?? json['xpGained']) as Map? ?? {});
    final needs = <String, int>{};
    rawNeeds.forEach((k, v) {
      final val = (v as num?)?.toInt() ?? 0;
      final normalized = WellbeingTheme.normalizeSkillName(k);
      if (normalized != null) {
        needs[normalized] = (needs[normalized] ?? 0) + val;
      }
    });

    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      parsedTimestamp = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    } else if (json['id'] != null) {
      parsedTimestamp = DateTime.tryParse(json['id'].toString()) ?? DateTime.now();
    }

    return ReflectionLog(
      id: json['id'] as String? ?? 'unknown',
      timestamp: parsedTimestamp,
      trigger: json['trigger'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      action: json['action'] as String? ?? '', 
      aiFeedback: json['aiFeedback'] as String? ?? '',
      needs: needs,
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
      'needs': needs,
    };
  }
}