// lib/src/models/task_models.dart
import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class TaskSession {
  String id;
  DateTime startTime;
  DateTime endTime;

  TaskSession({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  factory TaskSession.fromJson(Map<String, dynamic> json) {
    return TaskSession(
      id: json['id'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  int get durationMinutes => endTime.difference(startTime).inMinutes;
  int get durationSeconds => endTime.difference(startTime).inSeconds;
}

class MainTask {
  String id;
  String name;
  String description;
  String theme;
  String colorHex;
  int dailyTimeSpent;
  String? lastWorkedDate;
  bool isActive; 
  bool isDeleted; // Added soft delete
  Map<String, List<bool>> weeklyCompletionStatus;
  List<SubTask> subTasks;
  String? phoenixSubTaskId;

  MainTask({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    this.colorHex = "FF00F8F8",
    this.dailyTimeSpent = 0,
    this.lastWorkedDate,
    this.isActive = true,
    this.isDeleted = false,
    Map<String, List<bool>>? weeklyCompletionStatus,
    List<SubTask>? subTasks,
    this.phoenixSubTaskId,
  })  : weeklyCompletionStatus = weeklyCompletionStatus ?? {},
        subTasks = subTasks ?? [];

  MainTask copyWith({
    String? id,
    String? name,
    String? description,
    String? theme,
    String? colorHex,
    int? dailyTimeSpent,
    String? lastWorkedDate,
    bool? isActive,
    bool? isDeleted,
    Map<String, List<bool>>? weeklyCompletionStatus,
    List<SubTask>? subTasks,
    String? phoenixSubTaskId,
  }) {
    return MainTask(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      theme: theme ?? this.theme,
      colorHex: colorHex ?? this.colorHex,
      dailyTimeSpent: dailyTimeSpent ?? this.dailyTimeSpent,
      lastWorkedDate: lastWorkedDate ?? this.lastWorkedDate,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      weeklyCompletionStatus:
          weeklyCompletionStatus ?? this.weeklyCompletionStatus,
      subTasks: subTasks ?? this.subTasks,
      phoenixSubTaskId: phoenixSubTaskId ?? this.phoenixSubTaskId,
    );
  }

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
        (key, value) => MapEntry(key as String,
            (value as List<dynamic>).map((item) => item as bool).toList()));

    return MainTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      theme: json['theme'] as String,
      colorHex: json['colorHex'] as String? ?? "FF00F8F8",
      dailyTimeSpent: json['dailyTimeSpent'] as int? ?? 0,
      lastWorkedDate: json['lastWorkedDate'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
      weeklyCompletionStatus:
          weeklyStatusFromJson?.cast<String, List<bool>>() ?? {},
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map(
                  (stJson) => SubTask.fromJson(stJson as Map<String, dynamic>))
              .toList() ??
          [],
      phoenixSubTaskId: json['phoenixSubTaskId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'theme': theme,
      'colorHex': colorHex,
      'dailyTimeSpent': dailyTimeSpent,
      'lastWorkedDate': lastWorkedDate,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'weeklyCompletionStatus': weeklyCompletionStatus,
      'subTasks': subTasks.map((st) => st.toJson()).toList(),
      'phoenixSubTaskId': phoenixSubTaskId,
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

class ProgressDataPoint {
  final DateTime timestamp;
  final double progress; // 0.0 – 1.0
  final int spentSeconds; // cumulative session seconds at time of entry

  const ProgressDataPoint({
    required this.timestamp,
    required this.progress,
    this.spentSeconds = 0,
  });

  factory ProgressDataPoint.fromJson(Map<String, dynamic> json) => ProgressDataPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        progress: (json['progress'] as num).toDouble(),
        spentSeconds: json['spentSeconds'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'progress': progress,
        'spentSeconds': spentSeconds,
      };
}

class SubTaskTemplateSet {
  String id;
  String name;
  List<SubSubTask> subSubTasks;

  SubTaskTemplateSet({
    required this.id,
    required this.name,
    required this.subSubTasks,
  });

  factory SubTaskTemplateSet.fromJson(Map<String, dynamic> json) {
    return SubTaskTemplateSet(
      id: json['id'] as String,
      name: json['name'] as String,
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
      'subSubTasks': subSubTasks.map((sss) => sss.toJson()).toList(),
    };
  }

  SubTaskTemplateSet copyWith({
    String? id,
    String? name,
    List<SubSubTask>? subSubTasks,
  }) {
    return SubTaskTemplateSet(
      id: id ?? this.id,
      name: name ?? this.name,
      subSubTasks: subSubTasks ?? this.subSubTasks,
    );
  }
}

class SubTask {
  String id;
  String name;
  String description;
  bool completed;
  int currentTimeSpent;
  String? completedDate;
  bool isCountable;
  int targetCount;
  int currentCount;
  List<SubSubTask> subSubTasks;
  List<TaskSession> sessions;
  List<ProgressDataPoint> progressDataPoints;
  double manualProgress;

  String why;
  String what;
  String resources;

  /// 'auto' | 'time' | 'subtask'
  /// 'auto' = subtask mode when checkable steps exist, else time mode.
  String progressMode;

  bool isRecurring;
  DateTime? lastCompletedDate;
  DateTime createdAt;
  DateTime updatedAt;
  bool isActive;
  bool isDeleted;
  List<SubTaskTemplateSet> templateSets;
  String? activeTemplateSetId;

  SubTask({
    required this.id,
    required this.name,
    this.description = '',
    this.completed = false,
    this.currentTimeSpent = 0,
    this.completedDate,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    this.manualProgress = 0.0,
    List<SubSubTask>? subSubTasks,
    List<TaskSession>? sessions,
    List<ProgressDataPoint>? progressDataPoints,
    this.why = '',
    this.what = '',
    this.resources = '',
    this.progressMode = 'auto',
    this.isRecurring = false,
    this.lastCompletedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.isDeleted = false,
    List<SubTaskTemplateSet>? templateSets,
    this.activeTemplateSetId,
  })  : subSubTasks = subSubTasks ?? [],
        sessions = sessions ?? [],
        progressDataPoints = progressDataPoints ?? [],
        templateSets = templateSets ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SubTask copyWith({
    String? id,
    String? name,
    String? description,
    bool? completed,
    int? currentTimeSpent,
    String? completedDate,
    bool? isCountable,
    int? targetCount,
    int? currentCount,
    double? manualProgress,
    List<SubSubTask>? subSubTasks,
    List<TaskSession>? sessions,
    List<ProgressDataPoint>? progressDataPoints,
    String? why,
    String? what,
    String? resources,
    String? progressMode,
    bool? isRecurring,
    DateTime? lastCompletedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isDeleted,
    List<SubTaskTemplateSet>? templateSets,
    String? activeTemplateSetId,
  }) {
    return SubTask(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      currentTimeSpent: currentTimeSpent ?? this.currentTimeSpent,
      completedDate: completedDate ?? this.completedDate,
      isCountable: isCountable ?? this.isCountable,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      manualProgress: manualProgress ?? this.manualProgress,
      subSubTasks: subSubTasks ?? this.subSubTasks,
      sessions: sessions ?? this.sessions,
      progressDataPoints: progressDataPoints ?? this.progressDataPoints,
      why: why ?? this.why,
      what: what ?? this.what,
      resources: resources ?? this.resources,
      progressMode: progressMode ?? this.progressMode,
      isRecurring: isRecurring ?? this.isRecurring,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      templateSets: templateSets ?? this.templateSets,
      activeTemplateSetId: activeTemplateSetId ?? this.activeTemplateSetId,
    );
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      currentTimeSpent: json['currentTimeSpent'] as int? ?? 0,
      completedDate: json['completedDate'] as String?,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      manualProgress: (json['manualProgress'] as num? ?? 0.0).toDouble(),
      why: json['why'] as String? ?? '',
      what: json['what'] as String? ?? '',
      resources: json['resources'] as String? ?? '',
      progressMode: json['progressMode'] as String? ?? 'auto',
      isRecurring: json['isRecurring'] as bool? ?? false,
      lastCompletedDate: json['lastCompletedDate'] != null 
          ? DateTime.parse(json['lastCompletedDate'] as String) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
      subSubTasks: (json['subSubTasks'] as List<dynamic>?)
              ?.map((sssJson) =>
                  SubSubTask.fromJson(sssJson as Map<String, dynamic>))
              .toList() ??
          [],
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map((sJson) =>
                  TaskSession.fromJson(sJson as Map<String, dynamic>))
              .toList() ??
          [],
      progressDataPoints: (json['progressDataPoints'] as List<dynamic>?)
              ?.map((p) => ProgressDataPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      templateSets: (json['templateSets'] as List<dynamic>?)
              ?.map((tsJson) =>
                  SubTaskTemplateSet.fromJson(tsJson as Map<String, dynamic>))
              .toList() ??
          [],
      activeTemplateSetId: json['activeTemplateSetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'completed': completed,
      'currentTimeSpent': currentTimeSpent,
      'completedDate': completedDate,
      'isCountable': isCountable,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'manualProgress': manualProgress,
      'why': why,
      'what': what,
      'resources': resources,
      'progressMode': progressMode,
      'isRecurring': isRecurring,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'isDeleted': isDeleted,
      'subSubTasks': subSubTasks.map((sss) => sss.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'progressDataPoints': progressDataPoints.map((p) => p.toJson()).toList(),
      'templateSets': templateSets.map((ts) => ts.toJson()).toList(),
      'activeTemplateSetId': activeTemplateSetId,
    };
  }

  List<SubTaskTemplateSet> get safeTemplateSets {
    if (templateSets.isEmpty) {
      return [
        SubTaskTemplateSet(
          id: 'default',
          name: 'Default',
          subSubTasks: subSubTasks,
        )
      ];
    }
    return templateSets;
  }

  String get safeActiveTemplateSetId {
    if (activeTemplateSetId == null) {
      return safeTemplateSets.first.id;
    }
    if (!safeTemplateSets.any((ts) => ts.id == activeTemplateSetId)) {
      return safeTemplateSets.first.id;
    }
    return activeTemplateSetId!;
  }

  bool get hasCheckableSubsteps => subSubTasks.any((sst) => sst.type != 'info');

  double calculateProgress() {
    if (progressMode == 'manual') {
      return manualProgress.clamp(0.0, 1.0);
    }
    final checkables = subSubTasks.where((sst) => sst.type != 'info').toList();
    if (checkables.isEmpty) return completed ? 1.0 : 0.0;
    double total = 0;
    for (var sst in checkables) {
      total += sst.calculateProgress();
    }
    return total / checkables.length;
  }

  SubSubTask? findCheckpoint(String cpId) {
    SubSubTask? recurse(List<SubSubTask> list) {
      for (final item in list) {
        if (item.id == cpId) return item;
        final found = recurse(item.substeps);
        if (found != null) return found;
      }
      return null;
    }
    return recurse(subSubTasks);
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
  String type; 
  List<SubSubTask> substeps; 
  
  String why;
  String what;

  SubSubTask({
    required this.id,
    required this.name,
    this.completed = false,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    this.completionTimestamp,
    this.type = 'check',
    List<SubSubTask>? substeps,
    this.why = '',
    this.what = '',
  }) : substeps = substeps ?? [];

  SubSubTask copyWith({
    String? id,
    String? name,
    bool? completed,
    bool? isCountable,
    int? targetCount,
    int? currentCount,
    String? completionTimestamp,
    String? type,
    List<SubSubTask>? substeps,
    String? why,
    String? what,
  }) {
    return SubSubTask(
      id: id ?? this.id,
      name: name ?? this.name,
      completed: completed ?? this.completed,
      isCountable: isCountable ?? this.isCountable,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      completionTimestamp: completionTimestamp ?? this.completionTimestamp,
      type: type ?? this.type,
      substeps: substeps ?? this.substeps,
      why: why ?? this.why,
      what: what ?? this.what,
    );
  }

  factory SubSubTask.fromJson(Map<String, dynamic> json) {
    return SubSubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      completionTimestamp: json['completionTimestamp'] as String?,
      type: json['type'] as String? ?? 'check',
      why: json['why'] as String? ?? '',
      what: json['what'] as String? ?? '',
      substeps: (json['substeps'] as List<dynamic>?)
              ?.map((e) => SubSubTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'type': type,
      'why': why,
      'what': what,
      'substeps': substeps.map((e) => e.toJson()).toList(),
    };
  }
  
  bool get hasCheckableSubsteps => substeps.any((s) => s.type != 'info');

  double calculateProgress() {
    final checkables = substeps.where((sst) => sst.type != 'info').toList();
    if (checkables.isEmpty) return completed ? 1.0 : 0.0;
    double total = 0;
    for (var sst in checkables) {
      total += sst.calculateProgress();
    }
    double prog = total / checkables.length;
    completed = prog >= 1.0; 
    return prog;
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

extension TaskCopyExtension on MainTask {
  String toCopyStructure() {
    final buffer = StringBuffer();
    buffer.writeln(name);
    // MainTask has no why field.
    if (description.trim().isNotEmpty) {
      buffer.writeln("What: ${description.trim()}");
    }
    if (subTasks.isNotEmpty) {
      buffer.writeln("    How:");
      for (final sub in subTasks) {
        buffer.write(sub.toCopyStructure(1));
      }
    }
    return buffer.toString().trimRight();
  }
}

extension SubTaskCopyExtension on SubTask {
  String toCopyStructure([int depth = 0]) {
    final buffer = StringBuffer();
    if (depth == 0) {
      buffer.writeln(name);
      if (why.trim().isNotEmpty) {
        buffer.writeln("Why: ${why.trim()}");
      }
      if (what.trim().isNotEmpty) {
        buffer.writeln("What: ${what.trim()}");
      }
      if (subSubTasks.isNotEmpty) {
        buffer.writeln("    How:");
        for (final sst in subSubTasks) {
          buffer.write(sst.toCopyStructure(1));
        }
      }
    } else {
      final indentBullet = ' ' * (4 * depth + 4);
      final indentProps = ' ' * (4 * depth + 6);
      buffer.writeln('$indentBullet* $name');
      if (why.trim().isNotEmpty) {
        buffer.writeln('${indentProps}Why: ${why.trim()}');
      }
      if (what.trim().isNotEmpty) {
        buffer.writeln('${indentProps}What: ${what.trim()}');
      }
      if (subSubTasks.isNotEmpty) {
        buffer.writeln('${indentProps}How:');
        for (final sst in subSubTasks) {
          buffer.write(sst.toCopyStructure(depth + 1));
        }
      }
    }
    return buffer.toString();
  }
}

extension SubSubTaskCopyExtension on SubSubTask {
  String toCopyStructure([int depth = 0]) {
    final buffer = StringBuffer();
    if (depth == 0) {
      buffer.writeln(name);
      if (why.trim().isNotEmpty) {
        buffer.writeln("Why: ${why.trim()}");
      }
      if (what.trim().isNotEmpty) {
        buffer.writeln("What: ${what.trim()}");
      }
      if (substeps.isNotEmpty) {
        buffer.writeln("    How:");
        for (final sub in substeps) {
          buffer.write(sub.toCopyStructure(1));
        }
      }
    } else {
      final indentBullet = ' ' * (4 * depth + 4);
      final indentProps = ' ' * (4 * depth + 6);
      buffer.writeln('$indentBullet* $name');
      if (why.trim().isNotEmpty) {
        buffer.writeln('${indentProps}Why: ${why.trim()}');
      }
      if (what.trim().isNotEmpty) {
        buffer.writeln('${indentProps}What: ${what.trim()}');
      }
      if (substeps.isNotEmpty) {
        buffer.writeln('${indentProps}How:');
        for (final sub in substeps) {
          buffer.write(sub.toCopyStructure(depth + 1));
        }
      }
    }
    return buffer.toString();
  }
}