// lib/src/models/emotion_models.dart

// Energy Log remains
class EnergyLog {
  final DateTime timestamp;
  final int level; // 0-100

  EnergyLog({required this.timestamp, required this.level});

  factory EnergyLog.fromJson(Map<String, dynamic> json) {
    return EnergyLog(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level,
    };
  }
}