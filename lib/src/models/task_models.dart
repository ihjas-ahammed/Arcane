// lib/src/models/task_models.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class MainTask {
  String id;
  String name;
  String description;
  String theme;
  String colorHex;
  int streak;
  int weeklyStreak;
  int dailyTimeSpent;
  String? lastWorkedDate;
  Map<String, List<bool>> weeklyCompletionStatus;
  List<SubTask> subTasks;

  MainTask({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    this.colorHex = "FF00F8F8",
    this.streak = 0,
    this.weeklyStreak = 0,
    this.dailyTimeSpent = 0,
    this.lastWorkedDate,
    Map<String, List<bool>>? weeklyCompletionStatus,
    List<SubTask>? subTasks,
  })  : weeklyCompletionStatus = weeklyCompletionStatus ?? {},
        subTasks = subTasks ?? [];

  factory MainTask.fromTemplate(MainTaskTemplate template) {
    return MainTask(
      id: template.id,
      name: template.name,
      description: template.description,
      theme: template.theme,
      colorHex: template.colorHex,
    );
  }

  factory MainTask.fromJson(Map<String, dynamic> json) {
    var weeklyStatusFromJson = (json['weeklyCompletionStatus'] as Map?)?.map(
        (key, value) => MapEntry(
            key as String,
            (value as List<dynamic>)
                .map((item) => item as bool)
                .toList()));

    return MainTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      theme: json['theme'] as String,
      colorHex: json['colorHex'] as String? ?? "FF00F8F8",
      streak: json['streak'] as int? ?? 0,
      weeklyStreak: json['weeklyStreak'] as int? ?? 0,
      dailyTimeSpent: json['dailyTimeSpent'] as int? ?? 0,
      lastWorkedDate: json['lastWorkedDate'] as String?,
      weeklyCompletionStatus:
          weeklyStatusFromJson?.cast<String, List<bool>>() ?? {},
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map(
                  (stJson) => SubTask.fromJson(stJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'theme': theme,
      'colorHex': colorHex,
      'streak': streak,
      'weeklyStreak': weeklyStreak,
      'dailyTimeSpent': dailyTimeSpent,
      'lastWorkedDate': lastWorkedDate,
      'weeklyCompletionStatus': weeklyCompletionStatus,
      'subTasks': subTasks.map((st) => st.toJson()).toList(),
    };
  }

  Color get taskColor {
    try {
      return Color(int.parse("0x$colorHex"));
    } catch (e) {
      return AppTheme.fhAccentTealFixed;
    }
  }
}

class SubTask {
  String id;
  String name;
  bool completed;
  int currentTimeSpent;
  String? completedDate;
  bool isCountable;
  int targetCount;
  int currentCount;
  List<SubSubTask> subSubTasks;
  // Priority removed

  SubTask({
    required this.id,
    required this.name,
    this.completed = false,
    this.currentTimeSpent = 0,
    this.completedDate,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    List<SubSubTask>? subSubTasks,
  }) : subSubTasks = subSubTasks ?? [];

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      currentTimeSpent: json['currentTimeSpent'] as int? ?? 0,
      completedDate: json['completedDate'] as String?,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      subSubTasks: (json['subSubTasks'] as List<dynamic>?)
              ?.map((sssJson) =>
                  SubSubTask.fromJson(sssJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed': completed,
      'currentTimeSpent': currentTimeSpent,
      'completedDate': completedDate,
      'isCountable': isCountable,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'subSubTasks': subSubTasks.map((sss) => sss.toJson()).toList(),
    };
  }
}

class SubSubTask {
  String id;
  String name;
  bool completed;
  bool isCountable;
  int targetCount;
  int currentCount;
  String? completionTimestamp;

  SubSubTask({
    required this.id,
    required this.name,
    this.completed = false,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    this.completionTimestamp,
  });

  factory SubSubTask.fromJson(Map<String, dynamic> json) {
    return SubSubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      completionTimestamp: json['completionTimestamp'] as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed': completed,
      'isCountable': isCountable,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'completionTimestamp': completionTimestamp,
    };
  }
}

class MainTaskTemplate {
  final String id;
  final String name;
  final String description;
  final String theme;
  final String colorHex;

  MainTaskTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    this.colorHex = "FF00F8F8",
  });
}