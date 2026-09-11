import 'dart:convert';

import 'file_text_store.dart';
import 'text_store.dart';
import '../domain/working_max.dart';

final class LocalWorkingMaxStore {
  final TextStore blobs;
  Future<void> _pending = Future.value();

  LocalWorkingMaxStore(Object file) : blobs = FileTextStore(file);
  LocalWorkingMaxStore.blobs(this.blobs);

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final result = _pending.then((_) => op());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<WorkingMaxState> load() => _enqueue(() async {
    if (!await blobs.exists()) return const WorkingMaxState();
    final json = jsonDecode(await blobs.read()) as Map<String, dynamic>;
    return WorkingMaxState.fromJson(json);
  });

  Future<void> save(WorkingMaxState state) => _enqueue(() async {
    await blobs.write(jsonEncode(state.toJson()));
  });
}
