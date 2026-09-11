import 'dart:convert';
import 'dart:io';
import '../domain/working_max.dart';

final class LocalWorkingMaxStore {
  final File file;
  Future<void> _pending = Future.value();
  LocalWorkingMaxStore(this.file);

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final result = _pending.then((_) => op());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<WorkingMaxState> load() => _enqueue(() async {
    if (!await file.exists()) return const WorkingMaxState();
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return WorkingMaxState.fromJson(json);
  });

  Future<void> save(WorkingMaxState state) => _enqueue(() async {
    await file.parent.create(recursive: true);
    final tmp = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}',
    );
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(file.path);
  });
}
