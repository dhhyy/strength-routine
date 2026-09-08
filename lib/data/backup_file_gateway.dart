import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'training_backup.dart';

abstract class BackupFileGateway {
  Future<String?> pick();
  Future<bool> save(String text, String filename);
}

final class NativeBackupFileGateway implements BackupFileGateway {
  @override
  Future<String?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
      withReadStream: true,
    );
    if (result == null) return null;
    final selected = result.files.single;
    if (selected.size > TrainingBackup.maxBytes) {
      throw const FormatException('백업 파일은 10MB 이하여야 해요.');
    }
    final stream =
        selected.readStream ??
        (selected.path == null ? null : File(selected.path!).openRead());
    if (stream == null) throw const FormatException('파일을 읽을 수 없어요.');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > TrainingBackup.maxBytes) {
        throw const FormatException('백업 파일은 10MB 이하여야 해요.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  @override
  Future<bool> save(String text, String filename) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '운동 기록 백업 저장',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    return result != null;
  }
}
