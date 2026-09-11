/// Platform-agnostic text blob persistence (file on native, prefs on web).
abstract class TextStore {
  /// Stable id for sibling naming / diagnostics.
  String get id;

  Future<bool> exists();
  Future<String> read();
  Future<void> write(String text);
  Future<void> delete();

  /// Another blob keyed relative to this store.
  TextStore sibling(String name);
}
