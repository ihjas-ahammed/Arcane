import 'package:flutter/material.dart';

class TimelineEntry {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String? subtitle;
  final Color color;
  final bool isEditable;
  final bool isPredicted; // New field
  final dynamic originalObject; // To pass back for editing actions

  TimelineEntry({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.subtitle,
    required this.color,
    this.isEditable = false,
    this.isPredicted = false,
    this.originalObject,
  });

  int get durationSeconds => endTime.difference(startTime).inSeconds;

  TimelineEntry copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    String? title,
    String? subtitle,
    Color? color,
    bool? isEditable,
    bool? isPredicted,
    dynamic originalObject,
  }) {
    return TimelineEntry(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      isEditable: isEditable ?? this.isEditable,
      isPredicted: isPredicted ?? this.isPredicted,
      originalObject: originalObject ?? this.originalObject,
    );
  }
}