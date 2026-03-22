import 'package:uuid/uuid.dart';

class HabitRule {
  String id;
  String appName;
  bool isGrayscale;
  int frictionDelaySeconds;
  int dailyLimitMinutes;
  int todayUsageMinutes;
  int currentStreakDays;

  HabitRule({
    required this.id,
    required this.appName,
    this.isGrayscale = false,
    this.frictionDelaySeconds = 0,
    this.dailyLimitMinutes = 0,
    this.todayUsageMinutes = 0,
    this.currentStreakDays = 0,
  });

  factory HabitRule.fromJson(Map<String, dynamic> json) {
    return HabitRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      appName: json['appName'] as String? ?? 'Unknown',
      isGrayscale: json['isGrayscale'] as bool? ?? false,
      frictionDelaySeconds: (json['frictionDelaySeconds'] as num? ?? 0).toInt(),
      dailyLimitMinutes: (json['dailyLimitMinutes'] as num? ?? 0).toInt(),
      todayUsageMinutes: (json['todayUsageMinutes'] as num? ?? 0).toInt(),
      currentStreakDays: (json['currentStreakDays'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appName': appName,
      'isGrayscale': isGrayscale,
      'frictionDelaySeconds': frictionDelaySeconds,
      'dailyLimitMinutes': dailyLimitMinutes,
      'todayUsageMinutes': todayUsageMinutes,
      'currentStreakDays': currentStreakDays,
    };
  }
}