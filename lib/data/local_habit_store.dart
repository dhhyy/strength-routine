import 'dart:convert';
import 'dart:io';
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
  final File file;
  Future<void> _pending = Future.value();
  static int _temporaryId = 0;
  LocalHabitStore(this.file);
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<HabitState> load() => _enqueue(() async {
    try {
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) return HabitState();
      if (type != FileSystemEntityType.file) {
        throw const FormatException('Habit state path is not a file');
      }
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryId++}',
    );
    try {
      final text = jsonEncode({'schemaVersion': 1, 'state': state.toJson()});
      await file.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      throw LocalHabitStoreException('아직 기기에 저장되지 않았어요. 입력을 유지하고 있어요.', error);
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        // 정리 오류가 실제 저장 실패 원인을 덮지 않게 한다.
      }
    }
  });
}
