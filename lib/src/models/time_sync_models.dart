import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum TimeSyncBlockType {
  focus,    // Work, Study, Deep focus
  routine,  // Meals, Commute, Chores
  rest,     // Sleep, Naps, Breaks
  leisure,  // Gaming, Reading, Social
  other     // Unspecified
}

class TimeSyncBlock {
  String id;
  DateTime startTime;
  DateTime endTime;
  String title;
  String description;
  TimeSyncBlockType type;

  TimeSyncBlock({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description = '',
    this.type = TimeSyncBlockType.other,
  });

  factory TimeSyncBlock.fromJson(Map<String, dynamic> json) {
    return TimeSyncBlock(
      id: json['id'] as String? ?? const Uuid().v4(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: TimeSyncBlockType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => TimeSyncBlockType.other,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'title': title,
      'description': description,
      'type': type.toString(),
    };
  }

  Color get color {
    switch (type) {
      case TimeSyncBlockType.focus:
        return const Color(0xFFFF4655); // Valorant Red
      case TimeSyncBlockType.routine:
        return const Color(0xFF00F59B); // Valorant Teal
      case TimeSyncBlockType.rest:
        return const Color(0xFF536DFE); // Indigo/Blue
      case TimeSyncBlockType.leisure:
        return const Color(0xFFF1C40F); // Gold
      default:
        return const Color(0xFF768079); // Muted
    }
  }

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}