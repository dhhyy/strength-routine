import 'dart:convert';
import 'dart:io';

import '../domain/rest_timer.dart';

/// Timer failures do not roll back or overwrite workout records.
final class RestTimerStore {
  final File file;
  Future<void>? _pending;
  RestTimerStore(this.file);

  Future<T> _queue<T>(Future<T> Function() action) {
    // Start the first operation in its caller's zone. An eagerly created
    // Future.value() can strand the first read across widget fake/real zones.
    final previous = _pending;
    final next = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<RestTimerSnapshot?> load() => _queue(() async {
    if (await FileSystemEntity.type(file.path) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1 ||
        !json.containsKey('timer') ||
        json.length != 2) {
      throw const FormatException('Unsupported rest timer state');
    }
    return json['timer'] == null
        ? null
        : RestTimerSnapshot.fromJson(
            Map<String, dynamic>.from(json['timer'] as Map),
          );
  });

  Future<void> save(RestTimerSnapshot? timer) {
    final text = jsonEncode({'schemaVersion': 1, 'timer': timer?.toJson()});
    return _queue(() async {
      final temporary = File('${file.path}.tmp');
      try {
        await file.parent.create(recursive: true);
        await temporary.writeAsString(text, flush: true);
        await temporary.rename(file.path);
      } finally {
        try {
          if (await temporary.exists()) await temporary.delete();
        } catch (_) {
          /* Keep the original write failure. */
        }
      }
    });
  }
}
