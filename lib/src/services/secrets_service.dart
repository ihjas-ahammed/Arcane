import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Runtime fetcher for the app's shared AI credentials. These live in the
/// Firestore document `secrets/apikeys` instead of being compiled into the
/// binary (git history is forever, and a leaked bundle hands them to anyone).
/// Firestore rules should restrict the document to read-only for authenticated
/// users.
///
/// Document shape (all values may be a `List` or a comma-separated `String`):
///   GENAI      -> shared Gemini keys
///   GROQ       -> shared Groq keys
///   CEREBRAS   -> shared Cerebras keys
///   OPENROUTER -> shared OpenRouter keys
///
/// Values are cached in memory only and dropped on sign-out via [clear].
/// When the document is unreachable (signed out, offline, rules denied, or the
/// Linux dev backend), the per-provider getters return empty — callers then
/// treat that as "the user must supply their own key in Settings".
class SecretsService {
  SecretsService._();
  static final SecretsService instance = SecretsService._();


  // Shared provider credentials are administrator-only. They must never be
  // distributed to clients; user-supplied keys remain supported below.
  Future<Map<String, dynamic>?> _load() async => null;

  List<String> _parseKeys(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Reads user-supplied keys from SharedPreferences first (new list key, then
  /// the legacy comma-string key), then falls back to the shared keys in the
  /// `[field]` field of the secrets document. Returns empty when neither is set.
  Future<List<String>> _keysFor(String prefsListKey, String field) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> keys = prefs.getStringList(prefsListKey) ?? [];
    if (keys.isEmpty) {
      final legacy = prefs.getString(prefsListKey.replaceAll('_list', '')) ?? '';
      keys = legacy
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (keys.isNotEmpty) return keys;

    final data = await _load();
    return _parseKeys(data?[field]);
  }

  /// Shared Gemini keys (`GENAI` field). Unlike the other providers, Gemini's
  /// user keys are managed through [AppProvider] custom keys, so this only
  /// returns the shared fallback set.
  Future<List<String>> geminiKeys() async {
    final data = await _load();
    return _parseKeys(data?['GENAI']);
  }

  Future<List<String>> groqKeys() =>
      _keysFor('groq_api_keys_list', 'GROQ');

  Future<List<String>> cerebrasKeys() =>
      _keysFor('cerebras_api_keys_list', 'CEREBRAS');

  Future<List<String>> openrouterKeys() =>
      _keysFor('openrouter_api_keys_list', 'OPENROUTER');

  /// Drops cached secrets (call on sign-out) and allows a fresh fetch on the
  /// next request (e.g. after signing back in).
  void clear() {

  }
}
