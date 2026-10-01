import 'package:intl/intl.dart';
import 'task_models.dart';

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

class GoalPlace {
  final String id;
  final String name;
  final int colorValue; // ARGB hex integer e.g. 0xFF10B981
  final String? iconName;

  const GoalPlace({
    required this.id,
    required this.name,
    required this.colorValue,
    this.iconName,
  });

  GoalPlace copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconName,
  }) {
    return GoalPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
    );
  }

  factory GoalPlace.fromJson(Map<String, dynamic> json) {
    return GoalPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF10B981,
      iconName: json['iconName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      if (iconName != null) 'iconName': iconName,
    };
  }

  static const List<GoalPlace> defaultPlaces = [
    GoalPlace(
      id: 'home',
      name: 'Home',
      colorValue: 0xFF10B981, // Emerald / Mint
      iconName: 'home',
    ),
    GoalPlace(
      id: 'work',
      name: 'Work',
      colorValue: 0xFFFFB547, // Tactical Amber
      iconName: 'briefcase',
    ),
    GoalPlace(
      id: 'college',
      name: 'College',
      colorValue: 0xFF8B5CF6, // Purple / Indigo
      iconName: 'school',
    ),
  ];
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
  final bool countAllTime; // If true, count all-time task duration; if false (default), start from goal date at 12:00 AM
  final List<String> reminderTimes; // e.g. ["09:00", "14:30"], active strictly for daily goals
  final String? placeId; // Reference to GoalPlace.id

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
    this.countAllTime = false,
    this.reminderTimes = const [],
    this.placeId,
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

  static DateTime? parseDateFromPeriodKey(String key, GoalScope scope) {
    try {
      switch (scope) {
        case GoalScope.daily:
        case GoalScope.weekly:
          return DateTime.tryParse(key);
        case GoalScope.monthly:
          return DateTime.tryParse('$key-01');
      }
    } catch (_) {
      return null;
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
    bool? countAllTime,
    List<String>? reminderTimes,
    String? placeId,
    bool clearPlaceId = false,
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
      countAllTime: countAllTime ?? this.countAllTime,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      placeId: clearPlaceId ? null : (placeId ?? this.placeId),
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
      countAllTime: json['countAllTime'] as bool? ?? false,
      reminderTimes: (json['reminderTimes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      placeId: json['placeId'] as String?,
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
      'countAllTime': countAllTime,
      'reminderTimes': reminderTimes,
      if (placeId != null) 'placeId': placeId,
    };
  }

  /// Calculates spent time in minutes for linked tasks based on session logs.
  /// By default ([countAllTime] is false), calculation starts from the day of the
  /// goal at 12:00 AM (00:00:00) and bounds within the goal's period window.
  /// If [countAllTime] is true, includes all lifetime time logged on the tasks.
  double calculateLinkedTimeMinutes(List<MainTask> mainTasks) {
    if (linkedTaskIds.isEmpty) return currentValue;

    double totalMinutes = 0.0;
    final activeMainTasks = mainTasks.where((t) => t.isActive && !t.isDeleted);

    if (countAllTime) {
      for (var mainTask in activeMainTasks) {
        final bool mainLinked = linkedTaskIds.contains(mainTask.id);

        for (var subTask in mainTask.subTasks) {
          if (subTask.isDeleted) continue;
          final subCompoundId = '${mainTask.id}|${subTask.id}';
          final bool subLinked = mainLinked ||
              linkedTaskIds.contains(subTask.id) ||
              linkedTaskIds.contains(subCompoundId);

          if (subLinked) {
            totalMinutes += subTask.currentTimeSpent > 0
                ? (subTask.currentTimeSpent / 60.0)
                : 0.0;
          }
        }
      }
      return totalMinutes;
    }

    // Default: time spent starts from the day of the goal at 12:00 AM
    final goalDate = startDateTime ??
        parseDateFromPeriodKey(dateKey, scope) ??
        createdAt;
    final startThreshold = DateTime(goalDate.year, goalDate.month, goalDate.day); // 12:00:00 AM

    DateTime endThreshold;
    switch (scope) {
      case GoalScope.daily:
        endThreshold = DateTime(goalDate.year, goalDate.month, goalDate.day + 1);
        break;
      case GoalScope.weekly:
        final monday = startThreshold.subtract(Duration(days: startThreshold.weekday - 1));
        endThreshold = monday.add(const Duration(days: 7));
        break;
      case GoalScope.monthly:
        endThreshold = DateTime(goalDate.year, goalDate.month + 1, 1);
        break;
    }

    for (var mainTask in activeMainTasks) {
      final bool mainLinked = linkedTaskIds.contains(mainTask.id);

      for (var subTask in mainTask.subTasks) {
        if (subTask.isDeleted) continue;
        final subCompoundId = '${mainTask.id}|${subTask.id}';
        final bool subLinked = mainLinked ||
            linkedTaskIds.contains(subTask.id) ||
            linkedTaskIds.contains(subCompoundId);

        if (!subLinked) continue;

        if (subTask.sessions.isNotEmpty) {
          for (var s in subTask.sessions) {
            if (s.endTime.isBefore(startThreshold) || s.startTime.isAfter(endThreshold)) {
              continue;
            }
            final winStart = s.startTime.isBefore(startThreshold) ? startThreshold : s.startTime;
            final winEnd = s.endTime.isAfter(endThreshold) ? endThreshold : s.endTime;
            if (winEnd.isAfter(winStart)) {
              totalMinutes += winEnd.difference(winStart).inSeconds / 60.0;
            }
          }
        } else if (subTask.currentTimeSpent > 0) {
          final updated = subTask.updatedAt;
          if (!updated.isBefore(startThreshold) && !updated.isAfter(endThreshold)) {
            totalMinutes += subTask.currentTimeSpent / 60.0;
          }
        }
      }
    }

    return totalMinutes;
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
