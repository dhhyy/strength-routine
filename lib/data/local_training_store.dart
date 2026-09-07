import 'dart:convert';
import 'dart:io';

import '../domain/training_program.dart';

final class LocalTrainingStoreException implements Exception {
  final String message;
  final Object? cause;
  const LocalTrainingStoreException(this.message, [this.cause]);
  @override
  String toString() => 'LocalTrainingStoreException: $message';
}

/// 한 인스턴스의 읽기/쓰기를 직렬화한다. 앱에서 하나의 저장소를 공유한다.
final class LocalTrainingStore {
  final File file;
  Future<void> _pending = Future.value();
  static int _temporaryId = 0;
  LocalTrainingStore(this.file);

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// 파일이 없을 때만 빈 상태를 반환한다. 손상·스키마 오류는 원본을 보존한다.
  Future<TrainingAppState> load() => _enqueue(() async {
    try {
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) return TrainingAppState();
      if (type != FileSystemEntityType.file) {
        throw const FormatException('State path is not a file');
      }
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (envelope['schemaVersion'] != 1) {
        throw const FormatException('Unsupported local state schema');
      }
      return TrainingAppState.fromJson(
        Map<String, dynamic>.from(envelope['state'] as Map),
      );
    } catch (error) {
      throw LocalTrainingStoreException(
        '저장된 운동 데이터를 읽을 수 없습니다. 원본 파일은 유지했습니다.',
        error,
      );
    }
  });

  /// 같은 디렉토리에 기록을 끝낸 뒤 rename한다. 실패 시 호출자가 재시도한다.
  Future<void> save(TrainingAppState state) => _enqueue(() async {
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryId++}',
    );
    try {
      final text = jsonEncode({'schemaVersion': 1, 'state': state.toJson()});
      await file.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      throw LocalTrainingStoreException(
        '운동 데이터를 저장하지 못했습니다. 입력을 유지하고 재시도하세요.',
        error,
      );
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        /* 저장 실패 원인을 덮지 않는다. */
      }
    }
  });
}
