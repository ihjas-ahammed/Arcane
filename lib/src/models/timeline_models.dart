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
}