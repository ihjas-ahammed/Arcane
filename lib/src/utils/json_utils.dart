import 'dart:convert';

class JsonUtils {
  /// Cleans raw string from AI models to extract valid JSON.
  /// Handles markdown code blocks, conversational text wrapping, and common trailing comma errors.
  static String cleanJsonString(String raw) {
    String jsonString = raw.trim();
    
    // Remove markdown code blocks
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = codeBlockRegex.firstMatch(jsonString);
    if (match != null) {
      jsonString = match.group(1)!.trim();
    }

    // Try to find the outer brackets if there's conversational text (and no code block matched)
    if (!jsonString.startsWith('{') && !jsonString.startsWith('[')) {
      int jsonStart = jsonString.indexOf('{');
      int jsonArrayStart = jsonString.indexOf('[');
      
      int start = -1;
      // Determine which comes first to decide if object or array
      if (jsonStart != -1 && jsonArrayStart != -1) {
        start = jsonStart < jsonArrayStart ? jsonStart : jsonArrayStart;
      } else if (jsonStart != -1) {
        start = jsonStart;
      } else if (jsonArrayStart != -1) {
        start = jsonArrayStart;
      }

      if (start != -1) {
        int end = jsonString.lastIndexOf(jsonString[start] == '{' ? '}' : ']');
        if (end != -1 && end > start) {
          jsonString = jsonString.substring(start, end + 1);
        }
      }
    }

    // Attempt to fix trailing commas (simple regex approach)
    // Replaces ,} with } and ,] with ] ignoring whitespace
    // Note: This is aggressive and might affect string content if it matches, 
    // but in JSON structure context usually safe for LLM output.
    jsonString = jsonString.replaceAll(RegExp(r',\s*}'), '}');
    jsonString = jsonString.replaceAll(RegExp(r',\s*]'), ']');

    return jsonString;
  }

  /// Tries to decode JSON, throwing a descriptive error with raw content if it fails.
  static dynamic tryDecode(String raw) {
    String cleaned = "";
    try {
      cleaned = cleanJsonString(raw);
      return jsonDecode(cleaned);
    } catch (e) {
      // Re-throw with raw content for debugging
      throw FormatException("JSON Decode Failed: $e\n\n--- CLEANED INPUT ---\n$cleaned\n\n--- RAW OUTPUT ---\n$raw");
    }
  }
}