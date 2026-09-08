import 'dart:convert';
import 'dart:io';
import '../domain/app_settings.dart';

final class LocalSettingsStoreException implements Exception {
  final String message;
  final Object? cause;
  const LocalSettingsStoreException(this.message, [this.cause]);
  @override
  String toString() => message;
}

/// 호출 순서대로 읽고 쓰며, 손상된 설정을 기본값으로 덮어쓰지 않는다.
final class LocalSettingsStore {
  final File file;
  Future<void> _pending = Future.value();
  static int _temporaryId = 0;
  LocalSettingsStore(this.file);

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<AppSettings> load() => _enqueue(() async {
    try {
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) return const AppSettings();
      if (type != FileSystemEntityType.file) {
        throw const FormatException('Settings path is not a file');
      }
      final envelope = jsonDecode(await file.readAsString()) as Map;
      if (![1, 2].contains(envelope['schemaVersion'])) {
        throw const FormatException('Unsupported settings schema');
      }
      final state = Map<String, dynamic>.from(envelope['state'] as Map);
      final restKeys = {'defaultRestSeconds', 'autoStartRestTimer'};
      if ((envelope['schemaVersion'] == 1 &&
              state.keys.any(restKeys.contains)) ||
          (envelope['schemaVersion'] == 2 &&
              !restKeys.every(state.containsKey))) {
        throw const FormatException('Rest settings require schema 2');
      }
      return AppSettings.fromJson(state);
    } catch (error) {
      throw LocalSettingsStoreException(
        '저장된 설정을 읽지 못했어요. 원본 파일은 유지했어요.',
        error,
      );
    }
  });

  Future<void> save(AppSettings settings) => _enqueue(() async {
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryId++}',
    );
    try {
      settings.validate();
      final text = jsonEncode({'schemaVersion': 2, 'state': settings.toJson()});
      await file.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      throw LocalSettingsStoreException(
        '선택한 설정이 아직 저장되지 않았어요. 다시 시도해 주세요.',
        error,
      );
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        // 정리 오류가 실제 저장 실패를 덮지 않게 한다.
      }
    }
  });
}
