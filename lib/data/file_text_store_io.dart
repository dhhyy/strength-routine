import 'dart:io';

import 'text_store.dart';

/// Atomic-ish file writes via temp + rename (existing native contract).
final class FileTextStore implements TextStore {
  final File file;
  static int _temporaryId = 0;

  FileTextStore(Object pathOrFile) : file = pathOrFile is File
      ? pathOrFile
      : File(pathOrFile.toString());

  @override
  String get id => file.path;

  @override
  Future<bool> exists() async {
    final type = await FileSystemEntity.type(file.path);
    return type == FileSystemEntityType.file;
  }

  @override
  Future<String> read() => file.readAsString();

  @override
  Future<void> write(String text) async {
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryId++}',
    );
    try {
      await file.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(file.path);
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        /* Keep the original write failure. */
      }
    }
  }

  @override
  Future<void> delete() async {
    if (await file.exists()) await file.delete();
  }

  @override
  TextStore sibling(String name) {
    if (name.startsWith('.')) {
      return FileTextStore(File('${file.path}$name'));
    }
    return FileTextStore(File('${file.parent.path}/$name'));
  }
}
