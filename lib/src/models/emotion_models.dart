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