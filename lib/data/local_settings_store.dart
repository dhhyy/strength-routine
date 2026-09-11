import 'dart:convert';

import 'file_text_store.dart';
import 'text_store.dart';
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
  final TextStore blobs;
  Future<void> _pending = Future.value();

  LocalSettingsStore(Object file) : blobs = FileTextStore(file);
  LocalSettingsStore.blobs(this.blobs);

  dynamic get file {
    final backend = blobs;
    if (backend is FileTextStore) return (backend as dynamic).file;
    throw UnsupportedError(
      'LocalSettingsStore.file is only available on file storage',
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<AppSettings> load() => _enqueue(() async {
    try {
      if (!await blobs.exists()) return const AppSettings();
      final envelope = jsonDecode(await blobs.read()) as Map;
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
        '저장된 설정을 읽지 못했어요. 원본을 유지하고 있어요.',
        error,
      );
    }
  });

  Future<void> save(AppSettings settings) => _enqueue(() async {
    try {
      settings.validate();
      final text = jsonEncode({'schemaVersion': 2, 'state': settings.toJson()});
      await blobs.write(text);
    } catch (error) {
      throw LocalSettingsStoreException(
        '선택한 설정이 아직 저장되지 않았어요. 다시 시도해 주세요.',
        error,
      );
    }
  });
}
