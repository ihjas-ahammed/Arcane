import 'dart:async';

/// Model parsing stays strict for imports. During recovery, the provider's zone
/// handler preserves malformed child records and lets readable siblings load.
List<T> decodeNestedRecords<T>(
    dynamic raw, T Function(Map<String, dynamic>) parse, String path) {
  if (raw == null) return [];
  if (raw is! List) throw FormatException('$path must be a list');
  final result = <T>[];
  for (var i = 0; i < raw.length; i++) {
    try {
      result.add(parse(Map<String, dynamic>.from(raw[i] as Map)));
    } catch (e) {
      final preserve = Zone.current['stateDecodeFailure'] as void Function(
          String, dynamic, Object)?;
      if (preserve == null) rethrow;
      preserve('$path/$i', raw[i], e);
    }
  }
  return result;
}
