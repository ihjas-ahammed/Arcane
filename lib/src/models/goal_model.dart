import 'package:intl/intl.dart';

enum GoalScope { daily, weekly, monthly }
enum GoalMetricType { check, counter, timeCounter }

class GoalSubCheckItem {
  final String id;
  final String title;
  final bool isCompleted;

  GoalSubCheckItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  GoalSubCheckItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return GoalSubCheckItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory GoalSubCheckItem.fromJson(Map<String, dynamic> json) {
    return GoalSubCheckItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}

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
  final String dateKey; // Period key: yyyy-MM-dd (daily), Monday's yyyy-MM-dd (weekly), yyyy-MM (monthly)
  final bool isRecurring;
  final List<GoalSubCheckItem> subChecklist;

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
    String? dateKey,
    this.isRecurring = false,
    this.subChecklist = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        dateKey = dateKey ?? getPeriodKey(scope, startDateTime ?? DateTime.now());

  static String getPeriodKey(GoalScope scope, DateTime date) {
    switch (scope) {
      case GoalScope.daily:
        return DateFormat('yyyy-MM-dd').format(date);
      case GoalScope.weekly:
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return DateFormat('yyyy-MM-dd').format(monday);
      case GoalScope.monthly:
        return DateFormat('yyyy-MM').format(date);
    }
  }

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
    String? dateKey,
    bool? isRecurring,
    List<GoalSubCheckItem>? subChecklist,
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
      dateKey: dateKey ?? this.dateKey,
      isRecurring: isRecurring ?? this.isRecurring,
      subChecklist: subChecklist ?? this.subChecklist,
    );
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final scopeVal = GoalScope.values.firstWhere(
      (e) => e.name == (json['scope'] as String?),
      orElse: () => GoalScope.daily,
    );
    final dt = json['startDateTime'] != null
        ? DateTime.tryParse(json['startDateTime'] as String)
        : null;

    return GoalModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      scope: scopeVal,
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
      startDateTime: dt,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      xpReward: json['xpReward'] as int? ?? 50,
      dateKey: json['dateKey'] as String? ?? getPeriodKey(scopeVal, dt ?? DateTime.now()),
      isRecurring: json['isRecurring'] as bool? ?? false,
      subChecklist: (json['subChecklist'] as List<dynamic>?)
              ?.map((e) => GoalSubCheckItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
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
      'dateKey': dateKey,
      'isRecurring': isRecurring,
      'subChecklist': subChecklist.map((e) => e.toJson()).toList(),
    };
  }

  /// Calculates accurate progress ratio (0.0 to 1.0) based on count, time, subchecklists
  double getProgressRatio({double? dynamicTimeMinutes}) {
    if (isCompleted) return 1.0;

    switch (metricType) {
      case GoalMetricType.check:
        if (subChecklist.isNotEmpty) {
          final done = subChecklist.where((i) => i.isCompleted).length;
          return (done / subChecklist.length).clamp(0.0, 1.0);
        }
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
    if (isCompleted) return true;
    return getProgressRatio(dynamicTimeMinutes: dynamicTimeMinutes) >= 1.0;
  }
}
