import 'package:shared_preferences/shared_preferences.dart';

import 'text_store.dart';

/// Browser-safe persistence via SharedPreferences (localStorage on web).
final class PrefsTextStore implements TextStore {
  final SharedPreferences prefs;
  final String key;

  PrefsTextStore(this.prefs, this.key);

  @override
  String get id => key;

  @override
  Future<bool> exists() async => prefs.containsKey(key);

  @override
  Future<String> read() async {
    final value = prefs.getString(key);
    if (value == null) {
      throw StateError('Missing prefs key: $key');
    }
    return value;
  }

  @override
  Future<void> write(String text) async {
    final ok = await prefs.setString(key, text);
    if (!ok) {
      throw StateError('Failed to write prefs key: $key');
    }
  }

  @override
  Future<void> delete() async {
    await prefs.remove(key);
  }

  @override
  TextStore sibling(String name) {
    if (name.startsWith('.')) {
      return PrefsTextStore(prefs, '$key$name');
    }
    final slash = key.lastIndexOf('/');
    final prefix = slash < 0 ? '' : key.substring(0, slash + 1);
    return PrefsTextStore(prefs, '$prefix$name');
  }
}
