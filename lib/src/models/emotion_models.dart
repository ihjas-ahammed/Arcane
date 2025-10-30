// lib/src/models/emotion_models.dart

class EmotionLog {
  final DateTime timestamp;
  final int rating; // 1-5

  EmotionLog({required this.timestamp, required this.rating});

  factory EmotionLog.fromJson(Map<String, dynamic> json) {
    return EmotionLog(
      timestamp: DateTime.parse(json['timestamp'] as String),
      rating: json['rating'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'rating': rating,
    };
  }
}

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