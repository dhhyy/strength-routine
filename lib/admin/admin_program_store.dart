import 'dart:convert';
import 'dart:io';
import '../domain/training_program.dart';
import 'detailed_routine.dart';
import 'routine_builder.dart';

final class AdminWorkspace {
  final RoutineBlueprint draft;
  final DetailedRoutineDraft? detailedDraft;
  final List<TrainingProgram> programs;
  AdminWorkspace({
    required this.draft,
    required List<TrainingProgram> programs,
    this.detailedDraft,
  }) : programs = List.unmodifiable(programs) {
    if (programs.map((p) => p.id).toSet().length != programs.length) {
      throw const FormatException('Duplicate program ID');
    }
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'draft': draft.toJson(),
    'detailedDraft': detailedDraft?.toJson(),
    'programs': programs.map((p) => p.toJson()).toList(),
  };
  factory AdminWorkspace.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['schemaVersion'])) {
      throw const FormatException('Unsupported admin schema');
    }
    if (json['schemaVersion'] == 2 && !json.containsKey('detailedDraft')) {
      throw const FormatException('Incomplete detailed admin workspace');
    }
    if (json['schemaVersion'] == 1 && json.containsKey('detailedDraft')) {
      throw const FormatException('Unexpected detailed draft in old schema');
    }
    return AdminWorkspace(
      draft: RoutineBlueprint.fromJson(
        Map<String, dynamic>.from(json['draft'] as Map),
      ),
      detailedDraft: json['detailedDraft'] == null
          ? null
          : DetailedRoutineDraft.fromJson(
              Map<String, dynamic>.from(json['detailedDraft'] as Map),
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
