import 'package:uuid/uuid.dart';

class Project {
  String id;
  String title;
  String description;
  List<ProjectStep> steps;
  double progress;
  String? linkedMainTaskId;
  bool isActive; // New field for Active/Inactive state
  int sortOrder; // New field for global sorting

  Project({
    required this.id,
    required this.title,
    required this.description,
    List<ProjectStep>? steps,
    this.progress = 0.0,
    this.linkedMainTaskId,
    this.isActive = true,
    this.sortOrder = 0,
  }) : steps = steps ?? [];

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      progress: (json['progress'] as num? ?? 0.0).toDouble(),
      linkedMainTaskId: json['linkedMainTaskId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      steps: (json['steps'] as List<dynamic>?)
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
      'progress': calculateProgress(),
      'linkedMainTaskId': linkedMainTaskId,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }

  double calculateProgress() {
    if (steps.isEmpty) return 0.0;
    double total = 0;
    for (var step in steps) {
      total += step.calculateProgress();
    }
    progress = total / steps.length;
    return progress;
  }
  
  int get completedStepsCount {
    if (steps.isEmpty) return 0;
    // Count steps that are fully complete
    return steps.where((s) => s.calculateProgress() >= 1.0).length;
  }
}

class ProjectStep {
  String id;
  String title;
  String description;
  bool isCompleted;
  List<ProjectStep> substeps;

  ProjectStep({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    List<ProjectStep>? substeps,
  }) : substeps = substeps ?? [];

  factory ProjectStep.fromJson(Map<String, dynamic> json) {
    return ProjectStep(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Step',
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
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
      'substeps': substeps.map((e) => e.toJson()).toList(),
    };
  }

  double calculateProgress() {
    // If it has children, progress is purely based on children
    if (substeps.isNotEmpty) {
      double total = 0;
      for (var step in substeps) {
        total += step.calculateProgress();
      }
      double childProgress = total / substeps.length;
      isCompleted = childProgress >= 1.0;
      return childProgress;
    }
    // If leaf node, return 1.0 or 0.0 based on checkbox
    return isCompleted ? 1.0 : 0.0;
  }
  
  int get completedSubstepsCount {
     if (substeps.isEmpty) return isCompleted ? 1 : 0;
     return substeps.where((s) => s.calculateProgress() >= 1.0).length;
  }
}