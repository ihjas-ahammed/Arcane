import 'package:arcane/src/models/value_models.dart';

class AiContextHelper {
  /// Serializes LifeValues into a simplified map structure for AI context.
  /// Includes current answers so the AI can decide whether to append or refine.
  static List<Map<String, dynamic>> serializeValues(List<LifeValue> values) {
    return values.map((v) => {
      'id': v.id,
      'title': v.title,
      'description': v.description,
      'questions': v.questions.map((q) => {
        'id': q.id,
        'question': q.question,
        'current_answer': q.answer
      }).toList()
    }).toList();
  }
}