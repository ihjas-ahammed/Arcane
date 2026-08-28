import 'package:uuid/uuid.dart';

/// Represents a single training log entry for a tracked skill.
class SkillTrainingLog {
  final String id;
  final DateTime timestamp;
  final String mode;
  final double value;
  final double? delta;
  final String resultType; // 'WIN', 'LOSS', 'DRAW', 'PASS', 'FAIL', 'COMPLETED'
  final int durationSeconds;
  final String notes;

  SkillTrainingLog({
    String? id,
    DateTime? timestamp,
    this.mode = 'STANDARD',
    required this.value,
    this.delta,
    this.resultType = 'COMPLETED',
    this.durationSeconds = 0,
    this.notes = '',
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory SkillTrainingLog.fromJson(Map<String, dynamic> json) {
    return SkillTrainingLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      mode: json['mode'] as String? ?? 'STANDARD',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      delta: (json['delta'] as num?)?.toDouble(),
      resultType: json['resultType'] as String? ?? 'COMPLETED',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'mode': mode,
      'value': value,
      'delta': delta,
      'resultType': resultType,
      'durationSeconds': durationSeconds,
      'notes': notes,
    };
  }

  SkillTrainingLog copyWith({
    String? id,
    DateTime? timestamp,
    String? mode,
    double? value,
    double? delta,
    String? resultType,
    int? durationSeconds,
    String? notes,
  }) {
    return SkillTrainingLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      mode: mode ?? this.mode,
      value: value ?? this.value,
      delta: delta ?? this.delta,
      resultType: resultType ?? this.resultType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
    );
  }
}

/// Represents a custom trackable skill in the Classified Operator Suite.
class TrackedSkill {
  final String id;
  final String name;
  final String subtitle;
  final String category; // 'MENTAL', 'PHYSICAL', 'COGNITIVE', 'ENDURANCE', 'REACTION', 'DISCIPLINE', 'GENERAL'
  final String description;
  final String unit; // e.g. '/ 3000', 'DIGITS', 'REPS', 's', 'ELO', etc.
  final double targetValue; // Benchmark / maximum target
  final double currentValue; // Latest value
  final String customTier; // e.g. 'CLUB PLAYER', 'ABOVE AVERAGE'
  final String iconName; // e.g. 'chessKnight', 'numeric', 'pushUp', 'pullUp'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SkillTrainingLog> logs;

  TrackedSkill({
    String? id,
    required this.name,
    this.subtitle = '',
    this.category = 'MENTAL',
    this.description = '',
    this.unit = '',
    this.targetValue = 100.0,
    required this.currentValue,
    this.customTier = '',
    this.iconName = 'star',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SkillTrainingLog>? logs,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        logs = logs != null ? List<SkillTrainingLog>.from(logs) : [];

  double get progress {
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  String get effectiveTier {
    if (customTier.trim().isNotEmpty) return customTier.trim().toUpperCase();
    final p = progress;
    if (p < 0.25) return 'INITIATE';
    if (p < 0.50) return 'AVERAGE - DECENT';
    if (p < 0.70) return 'ABOVE AVERAGE';
    if (p < 0.85) return 'COMPETENT';
    if (p < 0.95) return 'VERY GOOD';
    return 'MASTER - ELITE';
  }

  double get bestValue {
    if (logs.isEmpty) return currentValue;
    double maxV = currentValue;
    for (final l in logs) {
      if (l.value > maxV) maxV = l.value;
    }
    return maxV;
  }

  int get totalSessions => logs.length;

  double get winRate {
    if (logs.isEmpty) return 0.0;
    int wins = 0;
    for (final l in logs) {
      if (l.resultType.toUpperCase() == 'WIN' ||
          l.resultType.toUpperCase() == 'PASS' ||
          (l.delta != null && l.delta! > 0)) {
        wins++;
      }
    }
    return (wins / logs.length) * 100.0;
  }

  int get totalTimeSpentSeconds {
    int total = 0;
    for (final l in logs) {
      total += l.durationSeconds;
    }
    return total;
  }

  DateTime get lastUpdated {
    if (logs.isNotEmpty) {
      final sorted = List<SkillTrainingLog>.from(logs)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sorted.first.timestamp;
    }
    return updatedAt;
  }

  factory TrackedSkill.fromJson(Map<String, dynamic> json) {
    return TrackedSkill(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'NEW SKILL',
      subtitle: json['subtitle'] as String? ?? '',
      category: json['category'] as String? ?? 'MENTAL',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 100.0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      customTier: json['customTier'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'star',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      logs: (json['logs'] as List? ?? [])
          .map((e) => SkillTrainingLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'category': category,
      'description': description,
      'unit': unit,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'customTier': customTier,
      'iconName': iconName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'logs': logs.map((e) => e.toJson()).toList(),
    };
  }

  TrackedSkill copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? category,
    String? description,
    String? unit,
    double? targetValue,
    double? currentValue,
    String? customTier,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SkillTrainingLog>? logs,
  }) {
    return TrackedSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      customTier: customTier ?? this.customTier,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      logs: logs ?? this.logs,
    );
  }

  /// Authentic default skills seeded to match the screenshots.
  static List<TrackedSkill> defaultSkills() {
    final now = DateTime.now();

    final chessLogs = [
      SkillTrainingLog(
        id: 'chess_log_1',
        timestamp: now.subtract(const Duration(days: 9)),
        mode: 'BLITZ 5+0',
        value: 1313,
        delta: -6,
        resultType: 'LOSS',
        durationSeconds: 1200,
        notes: 'Endgame rook blunder in time trouble.',
      ),
      SkillTrainingLog(
        id: 'chess_log_2',
        timestamp: now.subtract(const Duration(days: 7)),
        mode: 'BLITZ 5+0',
        value: 1328,
        delta: 15,
        resultType: 'WIN',
        durationSeconds: 1500,
        notes: 'Clean Italian game pin on f7.',
      ),
      SkillTrainingLog(
        id: 'chess_log_3',
        timestamp: now.subtract(const Duration(days: 5)),
        mode: 'BLITZ 5+0',
        value: 1320,
        delta: -8,
        resultType: 'LOSS',
        durationSeconds: 1800,
        notes: 'Missed tactical fork on knight.',
      ),
      SkillTrainingLog(
        id: 'chess_log_4',
        timestamp: now.subtract(const Duration(days: 3)),
        mode: 'BLITZ 5+0',
        value: 1332,
        delta: 12,
        resultType: 'WIN',
        durationSeconds: 2100,
        notes: 'Strong queenside pawn storm.',
      ),
      SkillTrainingLog(
        id: 'chess_log_5',
        timestamp: now.subtract(const Duration(days: 1)),
        mode: 'BLITZ 5+0',
        value: 1350,
        delta: 18,
        resultType: 'WIN',
        durationSeconds: 2400,
        notes: 'Dominated positional endgame conversion.',
      ),
    ];

    final digitLogs = [
      SkillTrainingLog(
        id: 'digit_log_1',
        timestamp: now.subtract(const Duration(days: 6)),
        mode: 'FORWARD RECALL',
        value: 8,
        delta: 1,
        resultType: 'WIN',
        durationSeconds: 600,
        notes: 'Chunking 3-3-2 strategy applied.',
      ),
      SkillTrainingLog(
        id: 'digit_log_2',
        timestamp: now.subtract(const Duration(days: 3)),
        mode: 'FORWARD RECALL',
        value: 9,
        delta: 1,
        resultType: 'WIN',
        durationSeconds: 900,
        notes: 'Phonological loop repetition.',
      ),
      SkillTrainingLog(
        id: 'digit_log_3',
        timestamp: now.subtract(const Duration(days: 1)),
        mode: 'FORWARD RECALL',
        value: 10,
        delta: 1,
        resultType: 'WIN',
        durationSeconds: 1200,
        notes: '10 digits achieved without error.',
      ),
    ];

    final pushUpLogs = [
      SkillTrainingLog(
        id: 'pushup_log_1',
        timestamp: now.subtract(const Duration(days: 8)),
        mode: 'UNBROKEN MAX',
        value: 42,
        delta: 2,
        resultType: 'PASS',
        durationSeconds: 300,
      ),
      SkillTrainingLog(
        id: 'pushup_log_2',
        timestamp: now.subtract(const Duration(days: 4)),
        mode: 'UNBROKEN MAX',
        value: 46,
        delta: 4,
        resultType: 'PASS',
        durationSeconds: 360,
      ),
      SkillTrainingLog(
        id: 'pushup_log_3',
        timestamp: now.subtract(const Duration(days: 1)),
        mode: 'UNBROKEN MAX',
        value: 50,
        delta: 4,
        resultType: 'PASS',
        durationSeconds: 420,
        notes: 'Hit milestone of 50 strict pushups.',
      ),
    ];

    final pullUpLogs = [
      SkillTrainingLog(
        id: 'pullup_log_1',
        timestamp: now.subtract(const Duration(days: 7)),
        mode: 'DEAD HANG & REPS',
        value: 3,
        delta: 1,
        resultType: 'PASS',
        durationSeconds: 300,
      ),
      SkillTrainingLog(
        id: 'pullup_log_2',
        timestamp: now.subtract(const Duration(days: 2)),
        mode: 'DEAD HANG & REPS',
        value: 5,
        delta: 2,
        resultType: 'PASS',
        durationSeconds: 360,
        notes: 'Strict chest-to-bar pullups.',
      ),
    ];

    return [
      TrackedSkill(
        id: 'skill_chess_rating',
        name: 'CHESS RATING',
        subtitle: 'ELO RATING (BLITZ)',
        category: 'MENTAL',
        description: 'Measures your chess skill level using ELO rating from online games.',
        unit: '/ 3000',
        targetValue: 3000,
        currentValue: 1350,
        customTier: 'CLUB PLAYER',
        iconName: 'chessKnight',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
        logs: chessLogs,
      ),
      TrackedSkill(
        id: 'skill_digit_span',
        name: 'DIGIT SPAN',
        subtitle: 'WORKING MEMORY',
        category: 'COGNITIVE',
        description: 'Measures maximum sequence of numbers recalled forwards and backwards.',
        unit: 'DIGITS',
        targetValue: 15,
        currentValue: 10,
        customTier: 'ABOVE AVERAGE',
        iconName: 'numeric',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
        logs: digitLogs,
      ),
      TrackedSkill(
        id: 'skill_push_ups',
        name: 'PUSH-UPS IN A ROW',
        subtitle: 'MAX REPS',
        category: 'PHYSICAL',
        description: 'Maximum unbroken push-ups in a single set with chest-to-deck form.',
        unit: 'REPS',
        targetValue: 75,
        currentValue: 50,
        customTier: 'VERY GOOD',
        iconName: 'pushUp',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
        logs: pushUpLogs,
      ),
      TrackedSkill(
        id: 'skill_pull_ups',
        name: 'WALL / PULL-UP HOLDS',
        subtitle: 'MAX HOLD / REPS',
        category: 'PHYSICAL',
        description: 'Isometric dead hang duration and strict bodyweight pull-up volume.',
        unit: 'REPS',
        targetValue: 20,
        currentValue: 5,
        customTier: 'AVERAGE - DECENT',
        iconName: 'pullUp',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 2)),
        logs: pullUpLogs,
      ),
    ];
  }
}
