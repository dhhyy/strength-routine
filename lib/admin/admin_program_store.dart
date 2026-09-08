import 'dart:convert';
import 'dart:io';
import '../domain/training_program.dart';
import 'detailed_routine.dart';
import 'routine_builder.dart';

final class AdminWorkspace {
  final RoutineBlueprint draft;
  final DetailedRoutineDraft? detailedDraft;
  final List<TrainingProgram> programs;
  final Set<String> archivedProgramIds;
  final List<TrainingProgram> versionHistory;
  AdminWorkspace({
    required this.draft,
    required List<TrainingProgram> programs,
    this.detailedDraft,
    Set<String> archivedProgramIds = const {},
    List<TrainingProgram> versionHistory = const [],
  }) : programs = List.unmodifiable(programs),
       archivedProgramIds = Set.unmodifiable(archivedProgramIds),
       versionHistory = List.unmodifiable(versionHistory) {
    final ids = programs.map((p) => p.id).toSet();
    if (ids.length != programs.length || !ids.containsAll(archivedProgramIds)) {
      throw const FormatException('Duplicate or unknown program ID');
    }
    final snapshots = <String, String>{};
    final historyKeys = <String>{};
    for (final program in versionHistory) {
      if (!ids.contains(program.id) ||
          !historyKeys.add(jsonEncode([program.id, program.version]))) {
        throw const FormatException('Duplicate or orphan version history');
      }
    }
    for (final program in [...versionHistory, ...programs]) {
      final key = jsonEncode([program.id, program.version]);
      final content = jsonEncode(program.toJson());
      if (snapshots.containsKey(key) && snapshots[key] != content) {
        throw const FormatException(
          'A program version cannot have different content',
        );
      }
      snapshots[key] = content;
    }
  }
  List<TrainingProgram> get publishedPrograms => programs
      .where((p) => !archivedProgramIds.contains(p.id))
      .toList(growable: false);
  List<TrainingProgram> versionsFor(String id) {
    final versions = <String, TrainingProgram>{};
    for (final program in [...versionHistory, ...programs]) {
      if (program.id == id) versions[program.version] = program;
    }
    return List.unmodifiable(versions.values);
  }

  bool isVersionUsed(String id, String version) =>
      versionsFor(id).any((p) => p.version == version);
  String nextVersionFor(String id) {
    var value =
        versionsFor(id)
            .map((p) => int.tryParse(p.version) ?? 0)
            .fold(0, (a, b) => a > b ? a : b) +
        1;
    while (isVersionUsed(id, '$value')) {
      value++;
    }
    return '$value';
  }

  AdminWorkspace withProgram(
    TrainingProgram program,
    DetailedRoutineDraft? detailed,
  ) {
    if (isVersionUsed(program.id, program.version)) {
      throw const FormatException('이미 사용한 버전입니다. 새 버전을 입력해 주세요.');
    }
    final history = <String, TrainingProgram>{};
    for (final item in [...versionHistory, ...programs, program]) {
      history[jsonEncode([item.id, item.version])] = item;
    }
    return AdminWorkspace(
      draft: draft,
      detailedDraft: detailed?.copy(),
      programs: [...programs.where((p) => p.id != program.id), program],
      archivedProgramIds: archivedProgramIds,
      versionHistory: history.values.toList(),
    );
  }

  AdminWorkspace withArchived(String id, bool archived) {
    if (!programs.any((p) => p.id == id)) {
      throw const FormatException('Unknown program ID');
    }
    final ids = Set<String>.of(archivedProgramIds);
    if (archived) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    return AdminWorkspace(
      draft: draft,
      detailedDraft: detailedDraft?.copy(),
      programs: programs,
      archivedProgramIds: ids,
      versionHistory: versionHistory,
    );
  }

  bool get hasAdvancedPrescriptions =>
      (detailedDraft?.hasAdvancedPrescriptions ?? false) ||
      [
        ...programs,
        ...versionHistory,
      ].any((program) => program.hasAdvancedPrescriptions);
  bool get hasExtendedPrescriptions =>
      (detailedDraft?.hasExtendedPrescriptions ?? false) ||
      [
        ...programs,
        ...versionHistory,
      ].any((program) => program.hasExtendedPrescriptions);

  Map<String, Object?> toJson() => {
    'schemaVersion':
        hasExtendedPrescriptions ||
            archivedProgramIds.isNotEmpty ||
            versionHistory.isNotEmpty
        ? 4
        : hasAdvancedPrescriptions
        ? 3
        : 2,
    'draft': draft.toJson(),
    'detailedDraft': detailedDraft?.toJson(),
    'programs': programs.map((p) => p.toJson()).toList(),
    if (archivedProgramIds.isNotEmpty)
      'archivedProgramIds': archivedProgramIds.toList(),
    if (versionHistory.isNotEmpty)
      'versionHistory': versionHistory.map((p) => p.toJson()).toList(),
  };
  factory AdminWorkspace.fromJson(Map<String, dynamic> json) {
    final schema = json['schemaVersion'];
    if (![1, 2, 3, 4].contains(schema)) {
      throw const FormatException('Unsupported admin schema');
    }
    if ([2, 3, 4].contains(schema) && !json.containsKey('detailedDraft')) {
      throw const FormatException('Incomplete detailed admin workspace');
    }
    if (schema == 1 && json.containsKey('detailedDraft')) {
      throw const FormatException('Unexpected detailed draft in old schema');
    }
    if (![3, 4].contains(schema) && containsAdvancedPrescriptionFields(json)) {
      throw const FormatException(
        'Advanced prescriptions require admin schema 3',
      );
    }
    if (schema != 4 &&
        (containsExtendedPrescriptionFields(json) ||
            json.containsKey('archivedProgramIds') ||
            json.containsKey('versionHistory'))) {
      throw const FormatException(
        'Extended catalog editing requires admin schema 4',
      );
    }
    final rawArchived = json.containsKey('archivedProgramIds')
        ? json['archivedProgramIds'] as List
        : <String>[];
    final archived = rawArchived.cast<String>().toSet();
    if (archived.length != rawArchived.length) {
      throw const FormatException('Duplicate archived program ID');
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
      archivedProgramIds: archived,
      versionHistory:
          (json.containsKey('versionHistory')
                  ? json['versionHistory'] as List
                  : [])
              .map(
                (p) => TrainingProgram.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList(),
    );
  }
  String exportCatalog() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion':
        publishedPrograms.any((program) => program.hasExtendedPrescriptions)
        ? 3
        : publishedPrograms.any((program) => program.hasAdvancedPrescriptions)
        ? 2
        : 1,
    'programs': publishedPrograms.map((p) => p.toJson()).toList(),
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
