import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../app/training_controller.dart';
import '../domain/training_program.dart';
import 'local_training_store.dart';

/// A workout-only transfer file. The checksum detects damage, not authorship.
final class TrainingBackup {
  static const maxBytes = 10 * 1024 * 1024;
  final TrainingAppState state;
  final DateTime createdAt;
  TrainingBackup({required this.state, required DateTime createdAt})
    : createdAt = createdAt.toUtc();

  String encode() {
    final data = LocalTrainingStore.encodeEnvelope(state);
    return const JsonEncoder.withIndent('  ').convert({
      'kind': 'strength-workout-backup',
      'backupVersion': 1,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
      'checksum': checksum(data),
    });
  }

  factory TrainingBackup.parse(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('백업 파일은 10MB 이하여야 해요.');
    }
    // Limit nesting before jsonDecode to avoid recursive-parser exhaustion.
    var depth = 0, nodes = 0;
    var inString = false, escaped = false;
    for (final rune in text.runes) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (rune == 92) {
          escaped = true;
        } else if (rune == 34) {
          inString = false;
        }
      } else if (rune == 34) {
        inString = true;
      } else if (rune == 123 || rune == 91) {
        if (++depth > 64 || ++nodes > 250000) {
          throw const FormatException('백업 데이터 구조가 너무 커요.');
        }
      } else if (rune == 125 || rune == 93) {
        depth--;
      }
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    const keys = {'kind', 'backupVersion', 'createdAt', 'data', 'checksum'};
    if (json.length != keys.length ||
        !json.keys.every(keys.contains) ||
        json['kind'] != 'strength-workout-backup' ||
        json['backupVersion'] != 1) {
      throw const FormatException('지원하는 운동 백업 파일이 아니에요.');
    }
    final data = Map<String, dynamic>.from(json['data'] as Map);
    if (json['checksum'] != checksum(data)) {
      throw const FormatException('파일 내용이 손상되었거나 변경되었어요.');
    }
    final rawDate = json['createdAt'] as String;
    final date = DateTime.parse(rawDate);
    if (!date.isUtc || rawDate != date.toIso8601String()) {
      throw const FormatException('백업 생성 시각이 올바르지 않아요.');
    }
    return TrainingBackup(
      state: LocalTrainingStore.decodeEnvelope(data),
      createdAt: date,
    );
  }

  static String checksum(Object? data) {
    Object? canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(jsonEncode(canonical(data)))) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return 'fnv1a32:${hash.toRadixString(16).padLeft(8, '0')}';
  }
}

final class TrainingBackupService {
  final TrainingController controller;
  TrainingBackupService(this.controller);
  File get recoveryFile =>
      File('${controller.store.file.path}.before-restore.json');
  File get unreadableRecoveryFile =>
      File('${controller.store.file.path}.unreadable-before-restore.json');
  bool get canRestore =>
      !controller.loading &&
      !controller.saving &&
      controller.saveError == null &&
      !controller.sessionActionPending;
  bool get ready =>
      !controller.loading &&
      !controller.saving &&
      controller.loadError == null &&
      controller.saveError == null &&
      !controller.sessionActionPending;

  String export() {
    if (!ready) throw const FormatException('기록 저장을 마친 뒤 내보내 주세요.');
    return TrainingBackup(
      state: controller.state,
      createdAt: controller.now(),
    ).encode();
  }

  Future<bool> restore(TrainingBackup backup, {required int expectedRevision}) {
    final unreadable = controller.loadError != null;
    final generation =
        '${controller.now().toUtc().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 32)}';
    return controller.commitReviewedState(
      backup.state,
      expectedRevision: expectedRevision,
      restoredGeneration: generation,
      allowUnreadableRecovery: unreadable,
      beforeSave: (previous) async {
        if (unreadable) {
          // Never fabricate an empty recovery backup for an unreadable file.
          final temporary = File('${unreadableRecoveryFile.path}.tmp');
          try {
            await controller.store.file.copy(temporary.path);
            await temporary.rename(unreadableRecoveryFile.path);
          } finally {
            if (await temporary.exists()) await temporary.delete();
          }
          return;
        }
        final text = TrainingBackup(
          state: previous,
          createdAt: controller.now(),
        ).encode();
        final temporary = File('${recoveryFile.path}.tmp');
        try {
          await temporary.parent.create(recursive: true);
          await temporary.writeAsString(text, flush: true);
          // Verify the complete recovery copy before replacing the main file.
          TrainingBackup.parse(await temporary.readAsString());
          await temporary.rename(recoveryFile.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      },
    );
  }
}
