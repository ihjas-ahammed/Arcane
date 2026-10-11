class WebStateStore {
  static Future<String?> read(String key) => throw UnsupportedError('IndexedDB requires a browser');
  static Future<void> write(String key, String value) => throw UnsupportedError('IndexedDB requires a browser');
  static Future<void> remove(String key) => throw UnsupportedError('IndexedDB requires a browser');
}
