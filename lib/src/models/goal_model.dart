import 'package:flutter/foundation.dart';

enum GoalScope { daily, weekly, monthly }
enum GoalMetricType { check, counter, timeCounter }

class GoalModel {
  final String id;
  final String title;
  final GoalScope scope;
  final GoalMetricType metricType;
  final bool isCompleted;
  final double currentValue;
  final double targetValue;
  final List<String> linkedTaskIds;
  final DateTime? startDateTime;
  final DateTime createdAt;
  final int xpReward;

  GoalModel({
    required this.id,
    required this.title,
    this.scope = GoalScope.daily,
    this.metricType = GoalMetricType.check,
    this.isCompleted = false,
    this.currentValue = 0.0,
    this.targetValue = 1.0,
    this.linkedTaskIds = const [],
    this.startDateTime,
    DateTime? createdAt,
    this.xpReward = 50,
  }) : createdAt = createdAt ?? DateTime.now();

  GoalModel copyWith({
    String? id,
    String? title,
    GoalScope? scope,
    GoalMetricType? metricType,
    bool? isCompleted,
    double? currentValue,
    double? targetValue,
    List<String>? linkedTaskIds,
    DateTime? startDateTime,
    DateTime? createdAt,
    int? xpReward,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      scope: scope ?? this.scope,
      metricType: metricType ?? this.metricType,
      isCompleted: isCompleted ?? this.isCompleted,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      startDateTime: startDateTime ?? this.startDateTime,
      createdAt: createdAt ?? this.createdAt,
      xpReward: xpReward ?? this.xpReward,
    );
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      scope: GoalScope.values.firstWhere(
        (e) => e.name == (json['scope'] as String?),
        orElse: () => GoalScope.daily,
      ),
      metricType: GoalMetricType.values.firstWhere(
        (e) => e.name == (json['metricType'] as String?),
        orElse: () => GoalMetricType.check,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 1.0,
      linkedTaskIds: (json['linkedTaskIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      startDateTime: json['startDateTime'] != null
          ? DateTime.tryParse(json['startDateTime'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      xpReward: json['xpReward'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scope': scope.name,
      'metricType': metricType.name,
      'isCompleted': isCompleted,
      'currentValue': currentValue,
      'targetValue': targetValue,
      'linkedTaskIds': linkedTaskIds,
      'startDateTime': startDateTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'xpReward': xpReward,
    };
  }

  /// Calculates progress ratio (0.0 to 1.0)
  double getProgressRatio({double? dynamicTimeMinutes}) {
    switch (metricType) {
      case GoalMetricType.check:
        return isCompleted ? 1.0 : 0.0;
      case GoalMetricType.counter:
        if (targetValue <= 0) return 0.0;
        return (currentValue / targetValue).clamp(0.0, 1.0);
      case GoalMetricType.timeCounter:
        if (targetValue <= 0) return 0.0;
        final val = dynamicTimeMinutes ?? currentValue;
        return (val / targetValue).clamp(0.0, 1.0);
    }
  }

  bool getIsEffectiveCompleted({double? dynamicTimeMinutes}) {
    switch (metricType) {
      case GoalMetricType.check:
        return isCompleted;
      case GoalMetricType.counter:
        return isCompleted || (targetValue > 0 && currentValue >= targetValue);
      case GoalMetricType.timeCounter:
        final val = dynamicTimeMinutes ?? currentValue;
        return isCompleted || (targetValue > 0 && val >= targetValue);
    }
  }
}
