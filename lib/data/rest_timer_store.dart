import 'dart:convert';

import 'file_text_store.dart';
import 'text_store.dart';
import '../domain/rest_timer.dart';

/// Timer failures do not roll back or overwrite workout records.
final class RestTimerStore {
  final TextStore blobs;
  Future<void>? _pending;

  RestTimerStore(Object file) : blobs = FileTextStore(file);
  RestTimerStore.blobs(this.blobs);

  dynamic get file {
    final backend = blobs;
    if (backend is FileTextStore) return (backend as dynamic).file;
    throw UnsupportedError(
      'RestTimerStore.file is only available on file storage',
    );
  }

  Future<T> _queue<T>(Future<T> Function() action) {
    final previous = _pending;
    final next = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<RestTimerSnapshot?> load() => _queue(() async {
    if (!await blobs.exists()) {
      return null;
    }
    final json = jsonDecode(await blobs.read()) as Map<String, dynamic>;
    if (![1, 2].contains(json['schemaVersion']) ||
        !json.containsKey('timer') ||
        json.length != 2) {
      throw const FormatException('Unsupported rest timer state');
    }
    if (json['schemaVersion'] == 1 &&
        json['timer'] is Map &&
        (json['timer'] as Map).containsKey('durationSource')) {
      throw const FormatException('Duration source requires timer schema 2');
    }
    return json['timer'] == null
        ? null
        : RestTimerSnapshot.fromJson(
            Map<String, dynamic>.from(json['timer'] as Map),
          );
  });

  Future<void> save(RestTimerSnapshot? timer) {
    final text = jsonEncode({
      'schemaVersion': timer?.durationSource == RestDurationSource.userDefault
          ? 2
          : 1,
      'timer': timer?.toJson(),
    });
    return _queue(() async {
      await blobs.write(text);
    });
  }
}
