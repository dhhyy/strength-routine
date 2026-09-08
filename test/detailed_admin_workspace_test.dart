import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'admin_routine_test.dart' show validBlueprint;

void main() {
  late Directory temporary;
  late AdminProgramStore store;
  late RoutineBlueprint basic;
  late TrainingProgram program;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('precise-admin-store-');
    store = AdminProgramStore(File('${temporary.path}/workspace.json'));
    basic = validBlueprint();
    program = generateRoutine(basic);
  });
  tearDown(() async => temporary.delete(recursive: true));

  test('v1의 미완성 기본 초안은 그대로 읽고 v2로 저장하며 정밀 초안을 추정하지 않는다', () async {
    basic.weeks = '3.';
    basic.sessions.first.exercises.first.repetitions = '-';
    final old = jsonEncode({
      'schemaVersion': 1,
      'draft': basic.toJson(),
      'programs': [program.toJson()],
    });
    await store.file.writeAsString(old);
    final restored = (await store.load())!;
    expect(await store.file.readAsString(), old);
    expect(restored.draft.toJson(), basic.toJson());
    expect(restored.detailedDraft, isNull);
    await store.save(restored);
    final envelope = jsonDecode(await store.file.readAsString()) as Map;
    expect(envelope['schemaVersion'], 2);
    expect(envelope.containsKey('detailedDraft'), isTrue);
    final reopened = (await AdminProgramStore(store.file).load())!;
    expect(reopened.draft.toJson(), basic.toJson());
    expect(reopened.programs.single.toJson(), program.toJson());
    expect(reopened.detailedDraft, isNull);
  });

  test('서로 다른 주차의 원문과 기존 카탈로그를 새 저장소에서 독립 복원한다', () async {
    final detailed = DetailedRoutineDraft.fromProgram(program);
    detailed.version = 'next';
    detailed.weeks[1].sessions.first.exercises.first.sets[1].repetitions = '8.';
    detailed.weeks[1].sessions.first.exercises.first.sets[1].rir = '-';
    basic.title = '기본 초안 원문 ';
    final workspace = AdminWorkspace(
      draft: basic,
      programs: [program],
      detailedDraft: detailed,
    );
    await store.save(workspace);
    final reopened = (await AdminProgramStore(store.file).load())!;
    expect(reopened.toJson(), workspace.toJson());
    expect(
      reopened
          .detailedDraft!
          .weeks[0]
          .sessions
          .first
          .exercises
          .first
          .sets[1]
          .repetitions,
      '5',
    );
    expect(
      reopened
          .detailedDraft!
          .weeks[1]
          .sessions
          .first
          .exercises
          .first
          .sets[1]
          .repetitions,
      '8.',
    );
    expect(
      () => generateDetailedRoutine(reopened.detailedDraft!),
      throwsFormatException,
    );
    expect(reopened.programs.single.toJson(), program.toJson());
  });

  test('빠른 저장은 호출 당시 초안을 고정하고 가장 마지막 내용을 보존한다', () async {
    final detailed = DetailedRoutineDraft.fromProgram(program);
    final first = store.save(
      AdminWorkspace(
        draft: basic,
        programs: [program],
        detailedDraft: detailed,
      ),
    );
    detailed.weeks[1].sessions.first.exercises.first.sets[1].repetitions = '8';
    final second = store.save(
      AdminWorkspace(
        draft: basic,
        programs: [program],
        detailedDraft: detailed,
      ),
    );
    detailed.weeks[1].sessions.first.exercises.first.sets[1].repetitions = '99';
    await Future.wait([first, second]);
    final reopened = (await store.load())!;
    expect(
      reopened
          .detailedDraft!
          .weeks[1]
          .sessions
          .first
          .exercises
          .first
          .sets[1]
          .repetitions,
      '8',
    );
    expect(reopened.programs.single.toJson(), program.toJson());
  });

  test('미완성 정밀 초안은 소비자 카탈로그로 내보내지 않는다', () async {
    final detailed = DetailedRoutineDraft.fromProgram(program);
    detailed.weeks.first.sessions.first.exercises.first.sets.first.repetitions =
        'bad';
    final workspace = AdminWorkspace(
      draft: basic,
      programs: [program],
      detailedDraft: detailed,
    );
    await store.save(workspace);
    final exported = await store.export(workspace);
    final json = jsonDecode(await exported.readAsString()) as Map;
    expect(json.keys.toSet(), {'schemaVersion', 'programs'});
    expect(json['schemaVersion'], 1);
    expect((json['programs'] as List).single, program.toJson());
    expect((await store.load())!.detailedDraft!.toJson(), detailed.toJson());
  });

  test('v2 누락 필드·미지원 버전·잘못된 정밀 초안은 원본 파일을 유지하고 거부한다', () async {
    final complete = AdminWorkspace(draft: basic, programs: [program]).toJson();
    for (final invalid in [
      {...complete}..remove('detailedDraft'),
      {...complete, 'schemaVersion': 999},
      {
        ...complete,
        'detailedDraft': {'unknown': true},
      },
      {...complete, 'schemaVersion': 1},
    ]) {
      final bytes = utf8.encode(jsonEncode(invalid));
      await store.file.writeAsBytes(bytes);
      await expectLater(store.load(), throwsA(anything));
      expect(await store.file.readAsBytes(), bytes);
    }
  });

  test('정밀 초안 저장 실패 후 같은 후보를 재사용해 파일로 복원한다', () async {
    final blocked = File('${temporary.path}/blocked');
    await blocked.writeAsString('original');
    final unavailable = AdminProgramStore(
      File('${blocked.path}/workspace.json'),
    );
    final workspace = AdminWorkspace(
      draft: basic,
      programs: [program],
      detailedDraft: DetailedRoutineDraft.fromProgram(program),
    );
    final before = jsonEncode(workspace.toJson());
    await expectLater(
      unavailable.save(workspace),
      throwsA(isA<FileSystemException>()),
    );
    expect(await blocked.readAsString(), 'original');
    expect(jsonEncode(workspace.toJson()), before);
    await blocked.delete();
    await unavailable.save(workspace);
    expect(
      (await AdminProgramStore(unavailable.file).load())!.toJson(),
      workspace.toJson(),
    );
  });
}
