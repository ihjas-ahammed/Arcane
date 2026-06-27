import 'package:uuid/uuid.dart';

class Project {
  String id;
  String name;
  String description;
  List<String> linkedTaskKeys; // List of 'mainTaskId|subTaskId'
  List<ProjectRelease> releases;
  List<ProjectNote> notes;
  List<ProjectFile> files;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? linkedTaskKeys,
    List<ProjectRelease>? releases,
    List<ProjectNote>? notes,
    List<ProjectFile>? files,
  })  : linkedTaskKeys = linkedTaskKeys ?? [],
        releases = releases ?? [],
        notes = notes ?? [],
        files = files ?? [];

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      linkedTaskKeys: (json['linkedTaskKeys'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      releases: (json['releases'] as List<dynamic>?)?.map((e) => ProjectRelease.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      notes: (json['notes'] as List<dynamic>?)?.map((e) => ProjectNote.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      files: (json['files'] as List<dynamic>?)?.map((e) => ProjectFile.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'linkedTaskKeys': linkedTaskKeys,
      'releases': releases.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'files': files.map((e) => e.toJson()).toList(),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? linkedTaskKeys,
    List<ProjectRelease>? releases,
    List<ProjectNote>? notes,
    List<ProjectFile>? files,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      linkedTaskKeys: linkedTaskKeys ?? this.linkedTaskKeys,
      releases: releases ?? this.releases,
      notes: notes ?? this.notes,
      files: files ?? this.files,
    );
  }
}

class ProjectRelease {
  String id;
  String version;
  String title;
  DateTime? date;
  bool isReleased;

  ProjectRelease({
    required this.id,
    required this.version,
    required this.title,
    this.date,
    this.isReleased = false,
  });

  factory ProjectRelease.fromJson(Map<String, dynamic> json) {
    return ProjectRelease(
      id: json['id'] as String? ?? const Uuid().v4(),
      version: json['version'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      isReleased: json['isReleased'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'title': title,
      'date': date?.toIso8601String(),
      'isReleased': isReleased,
    };
  }
}

class ProjectNote {
  String id;
  String title;
  String content;
  DateTime createdAt;

  ProjectNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory ProjectNote.fromJson(Map<String, dynamic> json) {
    return ProjectNote(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ProjectFile {
  String id;
  String name;
  String content;
  DateTime createdAt;

  ProjectFile({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
