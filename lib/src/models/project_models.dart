import 'package:uuid/uuid.dart';

class Project {
  String id;
  String title;
  String description;
  List<ProjectStep> steps;
  double progress;

  Project({
    required this.id,
    required this.title,
    required this.description,
    List<ProjectStep>? steps,
    this.progress = 0.0,
  }) : steps = steps ?? [];

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      progress: (json['progress'] as num? ?? 0.0).toDouble(),
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
      'progress': calculateProgress(), // Always recalc on save
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
    if (substeps.isEmpty) {
      return isCompleted ? 1.0 : 0.0;
    }
    double total = 0;
    for (var step in substeps) {
      total += step.calculateProgress();
    }
    // If it has children, completion is derived from children
    // However, if the user explicitly checks the parent, it counts as 100% override?
    // For this implementation, parent status is derived if children exist.
    double childProgress = total / substeps.length;
    
    // Auto-update isCompleted flag based on children for UI convenience
    if (substeps.isNotEmpty) {
      isCompleted = childProgress >= 1.0;
    }
    
    return childProgress;
  }
}