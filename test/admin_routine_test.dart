import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

RoutineBlueprint validBlueprint() => RoutineBlueprint(
  id: 'admin-test',
  title: '관리자 검증',
  description: '자동 검증용 합성 구성',
  weeks: '3',
  sessions: [
    SessionBlueprint(
      title: '첫 번째 운동',
      exercises: [
        ExerciseBlueprint(
          id: 'squat',
          name: '스쿼트',
          mainLift: MainLift.squat,
          setCount: '2',
          repetitions: '5',
          rir: '3',
          loadKind: LoadKind.percentOfBaseline,
          loadValue: '100',
        ),
      ],
    ),
    SessionBlueprint(
      title: '두 번째 운동',
      exercises: [
        ExerciseBlueprint(
          id: 'row',
          name: '덤벨 로우',
          setCount: '2',
          repetitions: '8',
          rir: '3',
        ),
      ],
    ),
  ],
);

void main() {
  test('관리자 입력으로 3주 주2회 생성하고 기준중량으로 계획 시작', () {
    final draft = validBlueprint();
    final program = generateRoutine(draft);
    expect(program.sessions.length, 6);
    expect(program.orderedSessions.map((s) => '${s.week}-${s.dayOrder}'), [
      '1-1',
      '1-2',
      '2-1',
      '2-2',
      '3-1',
      '3-2',
    ]);
    final plan = createActivePlan(
      id: 'admin-start',
      program: program,
      startDate: DateTime(2026, 9, 8),
      weekdays: [2, 5],
      incrementKg: 2.5,
      baselines: {
        MainLift.squat: LiftBaseline(
          lift: MainLift.squat,
          kilograms: 60,
          source: BaselineSource.userEntered,
        ),
      },
    );
    expect(plan.sessions.first.exercises.first.sets.first.targetKg, 60);
    expect(plan.sessions[1].exercises.first.sets.first.targetKg, isNull);
    expect(plan.targetKgBySetId.keys.toSet().length, 12);
    expect(
      TrainingProgram.fromJson(
        jsonDecode(jsonEncode(program.toJson())),
      ).toJson(),
      program.toJson(),
    );
  });
  test('미완성 입력은 원문 복원되며 생성은 거절', () {
    final raw = RoutineBlueprint(title: '작업 중 ', weeks: '3.');
    final restored = RoutineBlueprint.fromJson(
      jsonDecode(jsonEncode(raw.toJson())),
    );
    expect(restored.weeks, '3.');
    expect(restored.title, '작업 중 ');
    expect(() => generateRoutine(restored), throwsFormatException);
  });
  test('다른 수치·동일ID 다른운동·중복ID를 거절', () {
    var draft = validBlueprint();
    draft.sessions.first.exercises.first.repetitions = '1.5';
    expect(() => generateRoutine(draft), throwsFormatException);
    draft = validBlueprint();
    draft.sessions.first.exercises.first.rir = '11';
    expect(() => generateRoutine(draft), throwsFormatException);
    draft = validBlueprint();
    draft.sessions.last.exercises.first.id = 'squat';
    expect(() => generateRoutine(draft), throwsFormatException);
    draft = validBlueprint();
    draft.sessions.first.exercises.add(
      ExerciseBlueprint(
        id: 'squat',
        name: '스쿼트',
        setCount: '2',
        repetitions: '5',
      ),
    );
    expect(() => generateRoutine(draft), throwsFormatException);
  });
  test('기준중량 비율에는 명시적 리프트가 필요하다', () {
    final draft = validBlueprint();
    draft.sessions.first.exercises.first.mainLift = null;
    expect(() => generateRoutine(draft), throwsFormatException);
    draft.sessions.first.exercises.first.loadKind = LoadKind.fixedKg;
    expect(
      generateRoutine(
        draft,
      ).sessions.first.exercises.first.sets.first.load.value,
      100,
    );
  });
  test('소비자 진입점의 import graph에 관리자 코드가 없다', () {
    final seen = <String>{};
    void visit(File source) {
      final file = source.absolute;
      if (!seen.add(file.path)) return;
      for (final match in RegExp(
        r"(?:import|export)\s+'([^']+)'",
      ).allMatches(file.readAsStringSync())) {
        final value = match.group(1)!;
        if (value.contains(':')) continue;
        final next = File('${file.parent.path}/$value');
        expect(
          next.path.contains('/admin/') ||
              next.path.endsWith('/main_admin.dart'),
          isFalse,
          reason: '${file.path} imports $value',
        );
        visit(next);
      }
    }

    visit(File('lib/main.dart'));
  });
  group('관리자 영구 작업·내보내기', () {
    late Directory dir;
    late AdminProgramStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('strength-admin-test-');
      store = AdminProgramStore(File('${dir.path}/workspace.json'));
    });
    tearDown(() async => dir.delete(recursive: true));
    test('원문·프로그램 저장 후 새 저장소로 복원하고 정식카탈로그형식 내보내기', () async {
      final draft = validBlueprint();
      final program = generateRoutine(draft);
      draft.weeks = '3.';
      final workspace = AdminWorkspace(draft: draft, programs: [program]);
      await store.save(workspace);
      final restored = await AdminProgramStore(store.file).load();
      expect(restored!.draft.weeks, '3.');
      expect(restored.programs.single.toJson(), program.toJson());
      final file = await store.export(restored);
      final json = jsonDecode(await file.readAsString()) as Map;
      expect(json['schemaVersion'], 1);
      expect(
        TrainingProgram.fromJson(
          Map<String, dynamic>.from((json['programs'] as List).single),
        ).title,
        program.title,
      );
    });
    test('빠른 연속저장도 마지막 초안을 보존', () async {
      final draft = validBlueprint();
      final first = store.save(AdminWorkspace(draft: draft, programs: []));
      draft.title = '최종 제목';
      final second = store.save(AdminWorkspace(draft: draft, programs: []));
      await Future.wait([first, second]);
      expect((await store.load())!.draft.title, '최종 제목');
    });
    test('손상 파일은 보존하고 읽기를 거절', () async {
      await store.file.writeAsString('{broken');
      await expectLater(store.load(), throwsFormatException);
      expect(await store.file.readAsString(), '{broken');
    });
    test('쓰기 실패 후 입력을 재사용해 재시도', () async {
      final blocked = File('${dir.path}/blocked');
      await blocked.writeAsString('keep');
      final badStore = AdminProgramStore(
        File('${blocked.path}/workspace.json'),
      );
      final workspace = AdminWorkspace(draft: validBlueprint(), programs: []);
      await expectLater(
        badStore.save(workspace),
        throwsA(isA<FileSystemException>()),
      );
      expect(await blocked.readAsString(), 'keep');
      await blocked.delete();
      await badStore.save(workspace);
      expect((await badStore.load())!.draft.title, '관리자 검증');
    });
  });
}
