import 'package:uuid/uuid.dart';
import 'package:missions/src/models/task_models.dart';

class ProjectSnapshot {
  String id;
  DateTime timestamp;
  int totalSecondsInvested;
  double progress; // 0.0 to 1.0
  String? note;

  ProjectSnapshot({
    required this.id,
    required this.timestamp,
    required this.totalSecondsInvested,
    required this.progress,
    this.note,
  });

  factory ProjectSnapshot.fromJson(Map<String, dynamic> json) {
    return ProjectSnapshot(
      id: json['id'] as String? ?? const Uuid().v4(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      totalSecondsInvested: json['totalSecondsInvested'] as int? ?? 0,
      progress: (json['progress'] as num? ?? 0.0).toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'totalSecondsInvested': totalSecondsInvested,
      'progress': progress,
      'note': note,
    };
  }
}

class Project {
  String id;
  String title;
  String description;
  List<ProjectStep> steps;
  double progress;
  String? linkedMainTaskId;
  bool isActive;
  int sortOrder;
  DateTime createdAt;
  DateTime? completedAt;
  List<ProjectSnapshot> snapshots;

  Project({
    required this.id,
    required this.title,
    required this.description,
    List<ProjectStep>? steps,
    this.progress = 0.0,
    this.linkedMainTaskId,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    this.completedAt,
    List<ProjectSnapshot>? snapshots,
  })  : steps = steps ?? [],
        createdAt = createdAt ?? DateTime.now(),
        snapshots = snapshots ?? [];

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      progress: (json['progress'] as num? ?? 0.0).toDouble(),
      linkedMainTaskId: json['linkedMainTaskId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => ProjectStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      snapshots: (json['snapshots'] as List<dynamic>?)
              ?.map((e) => ProjectSnapshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'progress': calculateProgress(),
      'linkedMainTaskId': linkedMainTaskId,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'steps': steps.map((e) => e.toJson()).toList(),
      'snapshots': snapshots.map((e) => e.toJson()).toList(),
    };
  }

  double calculateProgress() {
    if (steps.isEmpty) {
      return completedAt != null ? 1.0 : 0.0;
    }
    double total = 0;
    for (var step in steps) {
      total += step.calculateProgress();
    }
    progress = total / steps.length;

    // Auto-update completedAt if progress reached 1.0
    if (progress >= 1.0 && completedAt == null) {
      completedAt = DateTime.now();
    } else if (progress < 1.0 && completedAt != null) {
      completedAt = null;
    }

    return progress;
  }

  int get completedStepsCount {
    if (steps.isEmpty) return 0;
    return steps.where((s) => s.calculateProgress() >= 1.0).length;
  }

  // Calculate total time spent based on linked tasks
  int calculateTotalTimeSeconds(List<MainTask> allTasks) {
    int total = 0;
    for (var step in steps) {
      total += step.calculateTotalTimeSeconds(allTasks);
    }
    return total;
  }
}

class ProjectStep {
  String id;
  String title;
  String description;
  bool isCompleted;
  List<ProjectStep> substeps;

  // Linking Info
  String? linkedTaskType; // 'subtask' or 'checkpoint' (subsubtask)
  String? linkedTaskId;   // ID of the subtask or subsubtask
  String? linkedParentTaskId; // ID of the MainTask containing the linked task

  DateTime createdAt;
  DateTime? completedAt;

  ProjectStep({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    List<ProjectStep>? substeps,
    this.linkedTaskType,
    this.linkedTaskId,
    this.linkedParentTaskId,
    DateTime? createdAt,
    this.completedAt,
  }) : substeps = substeps ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory ProjectStep.fromJson(Map<String, dynamic> json) {
    return ProjectStep(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Step',
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      linkedTaskType: json['linkedTaskType'] as String?,
      linkedTaskId: json['linkedTaskId'] as String?,
      linkedParentTaskId: json['linkedParentTaskId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      substeps: (json['substeps'] as List<dynamic>?)
              ?.map((e) => ProjectStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'linkedTaskType': linkedTaskType,
      'linkedTaskId': linkedTaskId,
      'linkedParentTaskId': linkedParentTaskId,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'substeps': substeps.map((e) => e.toJson()).toList(),
    };
  }

  double calculateProgress() {
    if (substeps.isNotEmpty) {
      double total = 0;
      for (var step in substeps) {
        total += step.calculateProgress();
      }
      double childProgress = total / substeps.length;
      bool calculatedComplete = childProgress >= 1.0;

      if (calculatedComplete != isCompleted) {
        isCompleted = calculatedComplete;
        if (isCompleted) {
          completedAt = DateTime.now();
        } else {
          completedAt = null;
        }
      }

      return childProgress;
    }
    return isCompleted ? 1.0 : 0.0;
  }

  int calculateTotalTimeSeconds(List<MainTask> allTasks) {
    int total = 0;

    // 1. Recursive calculation
    for (var sub in substeps) {
      total += sub.calculateTotalTimeSeconds(allTasks);
    }

    // 2. Direct time from linked task
    if (linkedTaskId != null && linkedTaskType == 'subtask') {
      // Find the task
      for (var main in allTasks) {
        if (linkedParentTaskId != null && main.id != linkedParentTaskId) continue;

        final sub = main.subTasks.where((s) => s.id == linkedTaskId).firstOrNull;
        if (sub != null) {
          total += sub.currentTimeSpent;
          break;
        }
      }
    }
    return total;
  }
}