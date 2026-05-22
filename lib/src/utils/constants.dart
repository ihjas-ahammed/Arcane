// lib/src/utils/constants.dart
import 'package:missions/src/models/task_models.dart';

List<MainTaskTemplate> initialMainTaskTemplates = [
  MainTaskTemplate(
      id: "build_routine",
      name: "Routine & Reflection",
      description: "Establish routines, track progress, reflect.",
      theme: "order",
      colorHex: "FF4CAF50")
];

const int dailyTaskGoalMinutes = 15;