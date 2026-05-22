import 'package:uuid/uuid.dart';

class FoodItem {
  String id;
  String name;
  int calories;
  double protein;
  double carbs;
  double fat;
  String? description;
  List<String>? benefits;
  List<String>? warnings;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.description,
    this.benefits,
    this.warnings,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Unknown Food',
      calories: (json['calories'] as num? ?? 0).toInt(),
      protein: (json['protein'] as num? ?? 0).toDouble(),
      carbs: (json['carbs'] as num? ?? 0).toDouble(),
      fat: (json['fat'] as num? ?? 0).toDouble(),
      description: json['description'] as String?,
      benefits: (json['benefits'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'description': description,
      'benefits': benefits,
      'warnings': warnings,
    };
  }
}

class MealLog {
  String id;
  String foodItemId;
  DateTime timestamp;

  MealLog({
    required this.id,
    required this.foodItemId,
    required this.timestamp,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      foodItemId: json['foodItemId'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodItemId': foodItemId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SleepLog {
  String id;
  DateTime startTime;
  DateTime endTime;

  SleepLog({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  factory SleepLog.fromJson(Map<String, dynamic> json) {
    if (json['startTime'] != null && json['endTime'] != null) {
      return SleepLog(
        id: json['id'] as String? ?? const Uuid().v4(),
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
      );
    } else {
      // Legacy migration from 'minutes' and 'timestamp'
      final end = json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now();
      final mins = (json['minutes'] as num? ?? 0).toInt();
      final start = end.subtract(Duration(minutes: mins));
      return SleepLog(
        id: json['id'] as String? ?? const Uuid().v4(),
        startTime: start,
        endTime: end,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }
}

class ActivityLog {
  String id;
  double walkDistanceKm;
  int workoutMinutes;
  DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.walkDistanceKm,
    required this.workoutMinutes,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      walkDistanceKm: (json['walkDistanceKm'] as num? ?? 0.0).toDouble(),
      workoutMinutes: (json['workoutMinutes'] as num? ?? 0).toInt(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walkDistanceKm': walkDistanceKm,
      'workoutMinutes': workoutMinutes,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class EnergyLog {
  String id;
  int level; // 1-10
  DateTime timestamp;
  String? note;

  EnergyLog({
    required this.id,
    required this.level,
    required this.timestamp,
    this.note,
  });

  factory EnergyLog.fromJson(Map<String, dynamic> json) {
    return EnergyLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      level: (json['level'] as num? ?? 5).toInt().clamp(1, 10),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'timestamp': timestamp.toIso8601String(),
      if (note != null) 'note': note,
    };
  }
}

class DailyHealthLog {
  String dateStr;
  int waterGlasses;
  List<MealLog> meals;
  List<SleepLog> sleepLogs;
  List<ActivityLog> activityLogs;
  List<EnergyLog> energyLogs;

  DailyHealthLog({
    required this.dateStr,
    this.waterGlasses = 0,
    List<MealLog>? meals,
    List<SleepLog>? sleepLogs,
    List<ActivityLog>? activityLogs,
    List<EnergyLog>? energyLogs,
  }) : meals = meals ?? [],
       sleepLogs = sleepLogs ?? [],
       activityLogs = activityLogs ?? [],
       energyLogs = energyLogs ?? [];

  factory DailyHealthLog.fromJson(Map<String, dynamic> json) {
    // Migration logic for old singular fields
    final legacySleep = (json['sleepMinutes'] as num? ?? 0).toInt();
    final legacyWalk = (json['walkDistanceKm'] as num? ?? 0.0).toDouble();
    final legacyWorkout = (json['workoutMinutes'] as num? ?? 0).toInt();

    List<SleepLog> parsedSleep = (json['sleepLogs'] as List<dynamic>?)
            ?.map((e) => SleepLog.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
    
    if (parsedSleep.isEmpty && legacySleep > 0) {
      final end = DateTime.now();
      parsedSleep.add(SleepLog(id: const Uuid().v4(), startTime: end.subtract(Duration(minutes: legacySleep)), endTime: end));
    }

    List<ActivityLog> parsedActivity = (json['activityLogs'] as List<dynamic>?)
            ?.map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
            
    if (parsedActivity.isEmpty && (legacyWalk > 0 || legacyWorkout > 0)) {
      parsedActivity.add(ActivityLog(id: const Uuid().v4(), walkDistanceKm: legacyWalk, workoutMinutes: legacyWorkout, timestamp: DateTime.now()));
    }

    return DailyHealthLog(
      dateStr: json['dateStr'] as String? ?? '',
      waterGlasses: (json['waterGlasses'] as num? ?? 0).toInt(),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => MealLog.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      sleepLogs: parsedSleep,
      activityLogs: parsedActivity,
      energyLogs: (json['energyLogs'] as List<dynamic>?)
              ?.map((e) => EnergyLog.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateStr': dateStr,
      'waterGlasses': waterGlasses,
      'meals': meals.map((m) => m.toJson()).toList(),
      'sleepLogs': sleepLogs.map((s) => s.toJson()).toList(),
      'activityLogs': activityLogs.map((a) => a.toJson()).toList(),
      'energyLogs': energyLogs.map((e) => e.toJson()).toList(),
    };
  }
}