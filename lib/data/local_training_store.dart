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
  Future<void>? _pending;
  String restorationGeneration = '';
  static int _temporaryId = 0;
  LocalTrainingStore(this.file);

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final previous = _pending;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// 파일이 없을 때만 빈 상태를 반환한다. 손상·스키마 오류는 원본을 보존한다.
  Future<TrainingAppState> load() => _enqueue(() async {
    try {
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) {
        restorationGeneration = '';
        return TrainingAppState();
      }
      if (type != FileSystemEntityType.file) {
        throw const FormatException('State path is not a file');
      }
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final state = decodeEnvelope(envelope);
      restorationGeneration =
          envelope['restorationGeneration'] as String? ?? '';
      return state;
    } catch (error) {
      throw LocalTrainingStoreException(
        '저장된 운동 데이터를 읽을 수 없습니다. 원본 파일은 유지했습니다.',
        error,
      );
    }
  });

  /// 같은 디렉토리에 기록을 끝낸 뒤 rename한다. 실패 시 호출자가 재시도한다.
  static TrainingAppState decodeEnvelope(Map<String, dynamic> envelope) {
    final version = envelope['schemaVersion'];
    if (![1, 2, 3, 4, 5, 6].contains(version)) {
      throw const FormatException('Unsupported local state schema');
    }
    if (envelope.keys.any(
      (key) => !const {
        'schemaVersion',
        'state',
        'restorationGeneration',
      }.contains(key),
    )) {
      throw const FormatException('Unknown state envelope field');
    }
    if (version == 6) {
      final generation = envelope['restorationGeneration'];
      if (generation is! String ||
          generation.isEmpty ||
          generation.length > 100) {
        throw const FormatException('Missing restoration generation');
      }
    } else if (envelope.containsKey('restorationGeneration')) {
      throw const FormatException('Restoration generation requires schema 6');
    }
    final json = Map<String, dynamic>.from(envelope['state'] as Map);
    if ([3, 4, 5, 6].contains(version) &&
        (!json.containsKey('sessionEvents') ||
            !json.containsKey('legacySessionIds'))) {
      throw const FormatException('Incomplete session lifecycle state');
    }
    if (![4, 5, 6].contains(version) &&
        containsAdvancedPrescriptionFields(json)) {
      throw const FormatException(
        'Advanced prescriptions require state schema 4',
      );
    }
    if (![5, 6].contains(version) && containsExtendedPrescriptionFields(json)) {
      throw const FormatException(
        'Extended prescriptions require state schema 5',
      );
    }
    return TrainingAppState.fromJson(json);
  }

  static Map<String, Object?> encodeEnvelope(
    TrainingAppState state, {
    String restorationGeneration = '',
  }) => {
    'schemaVersion': restorationGeneration.isNotEmpty
        ? 6
        : state.hasExtendedPrescriptions
        ? 5
        : state.hasAdvancedPrescriptions
        ? 4
        : 3,
    if (restorationGeneration.isNotEmpty)
      'restorationGeneration': restorationGeneration,
    'state': state.toJson(),
  };

  Future<void> save(
    TrainingAppState state, {
    String? restoredGeneration,
  }) => _enqueue(() async {
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryId++}',
    );
    try {
      final generation = restoredGeneration ?? restorationGeneration;
      final text = jsonEncode(
        encodeEnvelope(state, restorationGeneration: generation),
      );
      await file.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(file.path);
      restorationGeneration = generation;
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
