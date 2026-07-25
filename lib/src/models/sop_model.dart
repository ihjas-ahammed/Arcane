class SopExecutionLog {
  final String id;
  final DateTime timestamp;
  final String notes;
  final String successStatus; // 'success', 'partial', 'failed'
  final int rating; // 1-5

  SopExecutionLog({
    required this.id,
    required this.timestamp,
    required this.notes,
    this.successStatus = 'success',
    this.rating = 5,
  });

  factory SopExecutionLog.fromJson(Map<String, dynamic> json) {
    return SopExecutionLog(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
      successStatus: json['successStatus'] as String? ?? 'success',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
        'successStatus': successStatus,
        'rating': rating,
      };
}

class SopModel {
  final String id;
  final String title;
  final String situation;
  final List<String> steps;
  final String expectedOutcomes;
  final List<SopExecutionLog> executionLogs;
  final DateTime createdAt;
  final DateTime updatedAt;

  SopModel({
    required this.id,
    required this.title,
    required this.situation,
    required this.steps,
    required this.expectedOutcomes,
    required this.executionLogs,
    required this.createdAt,
    required this.updatedAt,
  });

  SopModel copyWith({
    String? id,
    String? title,
    String? situation,
    List<String>? steps,
    String? expectedOutcomes,
    List<SopExecutionLog>? executionLogs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SopModel(
      id: id ?? this.id,
      title: title ?? this.title,
      situation: situation ?? this.situation,
      steps: steps ?? this.steps,
      expectedOutcomes: expectedOutcomes ?? this.expectedOutcomes,
      executionLogs: executionLogs ?? this.executionLogs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SopModel.fromJson(Map<String, dynamic> json) {
    return SopModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      situation: json['situation'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      expectedOutcomes: json['expectedOutcomes'] as String? ?? '',
      executionLogs: (json['executionLogs'] as List<dynamic>?)
              ?.map((e) => SopExecutionLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'situation': situation,
        'steps': steps,
        'expectedOutcomes': expectedOutcomes,
        'executionLogs': executionLogs.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
