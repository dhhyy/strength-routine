import 'dart:convert';

import 'file_text_store.dart';
import 'text_store.dart';
import '../domain/habit_record.dart';

final class LocalHabitStoreException implements Exception {
  final String message;
  final Object? cause;
  const LocalHabitStoreException(this.message, [this.cause]);
  @override
  String toString() => message;
}

/// 한 화면이 공유하는 저장소의 읽기/쓰기를 호출 순서대로 처리한다.
final class LocalHabitStore {
  final TextStore blobs;
  Future<void> _pending = Future.value();

  LocalHabitStore(Object file) : blobs = FileTextStore(file);
  LocalHabitStore.blobs(this.blobs);

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<HabitState> load() => _enqueue(() async {
    try {
      if (!await blobs.exists()) return HabitState();
      final envelope =
          jsonDecode(await blobs.read()) as Map<String, dynamic>;
      if (envelope['schemaVersion'] != 1) {
        throw const FormatException('Unsupported habit state schema');
      }
      return HabitState.fromJson(
        Map<String, dynamic>.from(envelope['state'] as Map),
      );
    } catch (error) {
      throw LocalHabitStoreException('저장된 습관을 읽지 못했어요. 원본 파일은 유지했어요.', error);
    }
  });

  Future<void> save(HabitState state) => _enqueue(() async {
    try {
      final text = jsonEncode({'schemaVersion': 1, 'state': state.toJson()});
      await blobs.write(text);
    } catch (error) {
      throw LocalHabitStoreException('아직 기기에 저장되지 않았어요. 입력을 유지하고 있어요.', error);
    }
  });
}
