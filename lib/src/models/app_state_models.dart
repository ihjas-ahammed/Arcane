// lib/src/models/app_state_models.dart
import 'package:flutter/material.dart'; // For TimeOfDay

class AppSettings {
  bool descriptionsVisible;
  bool dailyAutoGenerateContent;
  bool autoSaveEnabled; // New setting
  int wakeupTimeHour;
  int wakeupTimeMinute;
  String aiModelName;
  String? customApiKey; 
  String? customChatbotPrompt; 
  String? customReflectionPrompt; 
  int startOfWeek; // 1 for Monday, 7 for Sunday

  AppSettings({
    this.descriptionsVisible = true,
    this.dailyAutoGenerateContent = true,
    this.autoSaveEnabled = true, // Default to true
    this.wakeupTimeHour = 7,
    this.wakeupTimeMinute = 0,
    this.aiModelName = 'gemini-2.0-flash', 
    this.customApiKey,
    this.customChatbotPrompt,
    this.customReflectionPrompt,
    this.startOfWeek = 1, 
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      descriptionsVisible: json['descriptionsVisible'] as bool? ?? true,
      dailyAutoGenerateContent: json['dailyAutoGenerateContent'] as bool? ??
          json['autoGenerateContent'] as bool? ?? 
          true,
      autoSaveEnabled: json['autoSaveEnabled'] as bool? ?? true,
      wakeupTimeHour: json['wakeupTimeHour'] as int? ?? 7,
      wakeupTimeMinute: json['wakeupTimeMinute'] as int? ?? 0,
      aiModelName:
          json['aiModelName'] as String? ?? 'gemini-2.0-flash',
      customApiKey: json['customApiKey'] as String?,
      customChatbotPrompt: json['customChatbotPrompt'] as String?,
      customReflectionPrompt: json['customReflectionPrompt'] as String?,
      startOfWeek: json['startOfWeek'] as int? ?? 1,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'descriptionsVisible': descriptionsVisible,
      'dailyAutoGenerateContent': dailyAutoGenerateContent,
      'autoSaveEnabled': autoSaveEnabled,
      'wakeupTimeHour': wakeupTimeHour,
      'wakeupTimeMinute': wakeupTimeMinute,
      'aiModelName': aiModelName,
      'customApiKey': customApiKey,
      'customChatbotPrompt': customChatbotPrompt,
      'customReflectionPrompt': customReflectionPrompt,
      'startOfWeek': startOfWeek,
    };
  }
}

class ActiveTimerInfo {
  DateTime startTime;
  double accumulatedDisplayTime; // In seconds
  bool isRunning;
  String type;
  String mainTaskId;

  ActiveTimerInfo({
    required this.startTime,
    this.accumulatedDisplayTime = 0,
    required this.isRunning,
    required this.type,
    required this.mainTaskId,
  });

  factory ActiveTimerInfo.fromJson(Map<String, dynamic> json) {
    return ActiveTimerInfo(
      startTime: DateTime.parse(json['startTime'] as String),
      accumulatedDisplayTime:
          (json['accumulatedDisplayTime'] as num? ?? 0).toDouble(),
      isRunning: json['isRunning'] as bool? ?? false,
      type: json['type'] as String? ?? 'subtask',
      mainTaskId: json['mainTaskId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'accumulatedDisplayTime': accumulatedDisplayTime,
      'isRunning': isRunning,
      'type': type,
      'mainTaskId': mainTaskId,
    };
  }
}