import 'package:missions/src/models/sop_model.dart';

class SopProgressPoint {
  final double elapsedMinutes;
  final double completionPercentage;

  const SopProgressPoint({
    required this.elapsedMinutes,
    required this.completionPercentage,
  });

  Map<String, dynamic> toJson() => {
        'elapsedMinutes': elapsedMinutes,
        'completionPercentage': completionPercentage,
      };

  factory SopProgressPoint.fromJson(Map<String, dynamic> json) => SopProgressPoint(
        elapsedMinutes: (json['elapsedMinutes'] as num).toDouble(),
        completionPercentage: (json['completionPercentage'] as num).toDouble(),
      );
}

class SopSessionState {
  final SopModel sop;
  final String? mainTaskId;
  final String? subTaskId;
  final String? taskTitle;
  final DateTime startTime;
  final int? targetDurationSeconds;
  final Set<int> completedStepIndices;
  final List<SopProgressPoint> progressPoints;
  final bool isPaused;
  final int accumulatedPausedSeconds;
  final DateTime? pauseStartTime;

  SopSessionState({
    required this.sop,
    this.mainTaskId,
    this.subTaskId,
    this.taskTitle,
    required this.startTime,
    this.targetDurationSeconds,
    Set<int>? completedStepIndices,
    List<SopProgressPoint>? progressPoints,
    this.isPaused = false,
    this.accumulatedPausedSeconds = 0,
    this.pauseStartTime,
  })  : completedStepIndices = completedStepIndices ?? {},
        progressPoints = progressPoints ??
            [
              const SopProgressPoint(elapsedMinutes: 0, completionPercentage: 0),
            ];

  int get elapsedSeconds {
    final now = DateTime.now();
    int currentPause = 0;
    if (isPaused && pauseStartTime != null) {
      currentPause = now.difference(pauseStartTime!).inSeconds;
    }
    final totalDiff = now.difference(startTime).inSeconds;
    final net = totalDiff - accumulatedPausedSeconds - currentPause;
    return net < 0 ? 0 : net;
  }

  double get completionPercentage {
    if (sop.steps.isEmpty) return 100.0;
    return (completedStepIndices.length / sop.steps.length) * 100.0;
  }

  bool get isFinished => sop.steps.isNotEmpty && completedStepIndices.length == sop.steps.length;

  SopSessionState copyWith({
    SopModel? sop,
    String? mainTaskId,
    String? subTaskId,
    String? taskTitle,
    DateTime? startTime,
    int? targetDurationSeconds,
    Set<int>? completedStepIndices,
    List<SopProgressPoint>? progressPoints,
    bool? isPaused,
    int? accumulatedPausedSeconds,
    DateTime? pauseStartTime,
  }) {
    return SopSessionState(
      sop: sop ?? this.sop,
      mainTaskId: mainTaskId ?? this.mainTaskId,
      subTaskId: subTaskId ?? this.subTaskId,
      taskTitle: taskTitle ?? this.taskTitle,
      startTime: startTime ?? this.startTime,
      targetDurationSeconds: targetDurationSeconds ?? this.targetDurationSeconds,
      completedStepIndices: completedStepIndices ?? this.completedStepIndices,
      progressPoints: progressPoints ?? this.progressPoints,
      isPaused: isPaused ?? this.isPaused,
      accumulatedPausedSeconds: accumulatedPausedSeconds ?? this.accumulatedPausedSeconds,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
    );
  }
}
