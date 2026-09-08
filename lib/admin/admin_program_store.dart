import 'dart:convert';
import 'dart:io';
import '../domain/training_program.dart';
import 'routine_builder.dart';

final class AdminWorkspace {
  final RoutineBlueprint draft;
  final List<TrainingProgram> programs;
  AdminWorkspace({required this.draft, required List<TrainingProgram> programs})
    : programs = List.unmodifiable(programs) {
    if (programs.map((p) => p.id).toSet().length != programs.length) {
      throw const FormatException('Duplicate program ID');
    }
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'draft': draft.toJson(),
    'programs': programs.map((p) => p.toJson()).toList(),
  };
  factory AdminWorkspace.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported admin schema');
    }
    return AdminWorkspace(
      draft: RoutineBlueprint.fromJson(
        Map<String, dynamic>.from(json['draft'] as Map),
      ),
      programs: (json['programs'] as List)
          .map(
            (p) =>
                TrainingProgram.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList(),
    );
  }
  String exportCatalog() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'programs': programs.map((p) => p.toJson()).toList(),
  });
}

/// Private authoring workspace, never read by the consumer entrypoint.
final class AdminProgramStore {
  final File file;
  Future<void> _pending = Future.value();
  AdminProgramStore(this.file);
  Future<T> _queue<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<AdminWorkspace?> load() => _queue(() async {
    if (await FileSystemEntity.type(file.path) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    return AdminWorkspace.fromJson(
      Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
    );
  });
  Future<void> save(AdminWorkspace workspace) {
    final text = jsonEncode(workspace.toJson());
    return _queue(() => _atomicWrite(file, text));
  }

  Future<File> export(AdminWorkspace workspace) {
    final text = workspace.exportCatalog();
    final target = File('${file.parent.path}/admin-export/programs.json');
    return _queue(() async {
      await _atomicWrite(target, text);
      return target;
    });
  }

  Future<void> _atomicWrite(File target, String text) async {
    final temporary = File('${target.path}.tmp');
    try {
      await target.parent.create(recursive: true);
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(target.path);
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        /* Keep original failure. */
      }
    }
  }
}
