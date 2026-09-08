import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_program_fixtures.dart';

DetailedRoutineDraft fixtureDraft() =>
    DetailedRoutineDraft.fromProgram(fixtureProgram());

Map<String, dynamic> jsonCopy(Map<String, Object?> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

DetailedSetDraft firstSet(DetailedRoutineDraft draft) =>
    draft.weeks.first.sessions.first.exercises.first.sets.first;

void main() {
  test('번들 프로그램 5개는 작성자·모든 ID·선택 세트·중량 처방까지 그대로 왕복한다', () {
    final catalog =
        jsonDecode(File('assets/programs.json').readAsStringSync())
            as Map<String, dynamic>;
    final programs = (catalog['programs'] as List)
        .map(
          (value) =>
              TrainingProgram.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    expect(programs, hasLength(5));
    for (final original in programs) {
      final draft = DetailedRoutineDraft.fromProgram(original);
      final restored = DetailedRoutineDraft.fromJson(jsonCopy(draft.toJson()));
      expect(
        generateDetailedRoutine(restored).toJson(),
        original.toJson(),
        reason: original.id,
      );
    }
  });

  test('원본 JSON 세션 배열의 순서와 라벨 공백도 그대로 유지한다', () {
    final json = jsonCopy(fixtureProgram().toJson());
    json['sessions'] = (json['sessions'] as List).reversed.toList();
    json['trainerName'] = '  단일 작성자  ';
    json['title'] = ' 이름 원문 ';
    final original = TrainingProgram.fromJson(json);
    final draft = DetailedRoutineDraft.fromProgram(original);
    expect(draft.weeks.first.sessions.first.id, 'w1d1');
    expect(generateDetailedRoutine(draft.copy()).toJson(), original.toJson());
  });

  test('미완성 원문과 빈 구조는 저장·복사 후 그대로이고 생성 실패로 변하지 않는다', () {
    final draft = fixtureDraft();
    draft.title = '  작업 중  ';
    final set = firstSet(draft);
    set.repetitions = '5.';
    set.rir = '  NaN ';
    set.loadValue = '1e';
    draft.weeks.last.sessions.first.exercises.clear();
    final before = jsonCopy(draft.toJson());
    final restored = DetailedRoutineDraft.fromJson(before);
    expect(restored.copy().toJson(), before);
    expect(() => generateDetailedRoutine(restored), throwsFormatException);
    expect(restored.toJson(), before);
    expect(
      DetailedRoutineDraft.fromJson(
        jsonCopy(DetailedRoutineDraft(weeks: []).toJson()),
      ).weeks,
      isEmpty,
    );
  });

  test('알 수 없는 필드·누락 필드·잘못된 타입·알 수 없는 enum은 유실 없이 거절한다', () {
    final unknown = jsonCopy(fixtureDraft().toJson())..['futureField'] = 'keep';
    expect(() => DetailedRoutineDraft.fromJson(unknown), throwsFormatException);
    final missing = jsonCopy(fixtureDraft().toJson())..remove('trainerName');
    expect(() => DetailedRoutineDraft.fromJson(missing), throwsFormatException);
    final draft = fixtureDraft();
    final invalid = firstSet(draft).toJson()..['repetitions'] = 5;
    expect(() => DetailedSetDraft.fromJson(invalid), throwsFormatException);
    final unknownKind = firstSet(draft).toJson()..['loadKind'] = 'automatic';
    expect(() => DetailedSetDraft.fromJson(unknownKind), throwsFormatException);
    final unknownLift = firstSet(draft).toJson()..['loadLift'] = 'mystery';
    expect(() => DetailedSetDraft.fromJson(unknownLift), throwsFormatException);
    final newSetField = firstSet(draft).toJson()..['futureSetField'] = '90';
    expect(() => DetailedSetDraft.fromJson(newSetField), throwsFormatException);
  });

  test('주차별 운동 구성과 세트별 반복·RIR·중량·필수 여부는 독립적이다', () {
    final draft = fixtureDraft();
    final week2 = draft.weeks[1].sessions.first.exercises.first;
    week2.sets[0].repetitions = '2';
    week2.sets[0].rir = '0.5';
    week2.sets[0].loadValue = '110';
    week2.sets[1].loadValue = '65';
    week2.sets[2].isRequired = true;
    draft.weeks[1].sessions.last.exercises.add(
      DetailedExerciseDraft(
        id: 'row',
        name: '로우',
        sets: [
          DetailedSetDraft(id: 'one', repetitions: '12', isRequired: false),
        ],
      ),
    );
    final program = generateDetailedRoutine(draft);
    final first = program.orderedSessions.first.exercises.first.sets;
    final changed = program.orderedSessions[2].exercises.first.sets;
    expect(first.map((set) => set.repetitions), [5, 3, 8]);
    expect(first.map((set) => set.isRequired), [true, true, false]);
    expect(changed.map((set) => set.repetitions), [2, 3, 8]);
    expect(changed.map((set) => set.rir), [0.5, null, null]);
    expect(changed.map((set) => set.load.value), [110, 65, null]);
    expect(changed.map((set) => set.isRequired), [true, true, true]);
    expect(program.orderedSessions.last.exercises, hasLength(2));
    expect(program.orderedSessions[1].exercises, hasLength(1));
  });

  test('운동 메인 리프트와 각 세트 기준 중량 리프트를 별개로 유지한다', () {
    final draft = fixtureDraft();
    final set = draft.weeks.first.sessions.first.exercises.first.sets[1];
    set.loadLift = MainLift.benchPress;
    final program = generateDetailedRoutine(draft);
    expect(program.sessions.first.exercises.first.mainLift, MainLift.squat);
    expect(
      program.sessions.first.exercises.first.sets[1].load.lift,
      MainLift.benchPress,
    );
    expect(
      generateDetailedRoutine(
        DetailedRoutineDraft.fromProgram(program),
      ).toJson(),
      program.toJson(),
    );
    final plan = createActivePlan(
      id: 'different-baseline',
      program: program,
      startDate: DateTime(2026, 9, 8),
      weekdays: [2, 5],
      incrementKg: 1,
      baselines: {
        MainLift.squat: LiftBaseline(
          lift: MainLift.squat,
          kilograms: 120,
          source: BaselineSource.userEntered,
        ),
        MainLift.benchPress: LiftBaseline(
          lift: MainLift.benchPress,
          kilograms: 100,
          source: BaselineSource.userEntered,
        ),
      },
    );
    expect(plan.sessions.first.exercises.first.sets[1].targetKg, 77);
    set.loadLift = null;
    expect(() => generateDetailedRoutine(draft), throwsFormatException);
  });

  test('직접 입력 모드로 전환해도 비활성 중량 원문은 초안에 남는다', () {
    final draft = fixtureDraft();
    final set = firstSet(draft);
    set.loadKind = LoadKind.manual;
    set.loadValue = '  입력 중  ';
    set.loadLift = MainLift.deadlift;
    final generated = generateDetailedRoutine(draft);
    expect(
      generated.sessions.first.exercises.first.sets.first.load.toJson(),
      const LoadPrescription.manual().toJson(),
    );
    final restored = draft.copy();
    expect(firstSet(restored).loadValue, '  입력 중  ');
    expect(firstSet(restored).loadLift, MainLift.deadlift);
  });

  test('주차 추가 복사는 세션 ID만 새로 만들고 이후 편집이 원본으로 전파되지 않는다', () {
    final draft = fixtureDraft();
    final source = draft.weeks.first.toJson();
    final originalIds = draft.weeks
        .expand((week) => week.sessions)
        .map((session) => session.id)
        .toSet();
    expect(draft.appendWeekCopy(0), 2);
    final copy = draft.weeks.last;
    expect(
      copy.sessions.every((session) => !originalIds.contains(session.id)),
      isTrue,
    );
    expect(copy.sessions.map((session) => session.id).toSet(), hasLength(2));
    expect(
      copy.sessions.first.exercises.first.id,
      draft.weeks.first.sessions.first.exercises.first.id,
    );
    copy.sessions.first.exercises.first.sets.first.repetitions = '2.';
    expect(draft.weeks.first.toJson(), source);
    expect(draft.nextSessionId(), 'session-3');
  });

  test('선택한 주차 덮어쓰기 복사는 대상 세션 ID를 순번별로 유지한다', () {
    final draft = fixtureDraft();
    firstSet(draft).repetitions = '12';
    final targetIds = draft.weeks[1].sessions
        .map((session) => session.id)
        .toList();
    final source = draft.weeks.first.toJson();
    draft.copyWeekOnto(0, 1);
    expect(draft.weeks[1].sessions.map((session) => session.id), targetIds);
    expect(
      draft.weeks[1].sessions.first.exercises.first.sets.first.repetitions,
      '12',
    );
    draft.weeks[1].sessions.first.exercises.first.sets.first.repetitions = '7';
    expect(draft.weeks.first.toJson(), source);
    final before = jsonCopy(draft.toJson());
    draft.copyWeekOnto(0, 0);
    expect(draft.toJson(), before);
  });

  test('세션 수가 다른 미완성 대상 주차에도 복사 후 전체 세션 ID는 중복되지 않는다', () {
    final draft = fixtureDraft();
    draft.weeks.last.sessions.removeLast();
    final preserved = draft.weeks.last.sessions.first.id;
    draft.copyWeekOnto(0, 1);
    expect(draft.weeks.last.sessions.first.id, preserved);
    expect(draft.weeks.last.sessions.last.id, 'session-1');
    final program = generateDetailedRoutine(draft);
    expect(program.sessions.map((session) => session.id).toSet(), hasLength(4));
  });

  test('주차·세션·운동·세트 순서를 바꿔도 ID와 원문은 보존된다', () {
    final draft = fixtureDraft();
    final session = draft.weeks.first.sessions.first;
    final originalSetIds = session.exercises.first.sets
        .map((set) => set.id)
        .toList();
    moveDetailedItem(session.exercises.first.sets, 0, 2);
    expect(session.exercises.first.sets.map((set) => set.id), [
      originalSetIds[1],
      originalSetIds[2],
      originalSetIds[0],
    ]);
    session.exercises.add(
      DetailedExerciseDraft(
        id: 'row',
        name: '로우',
        sets: [DetailedSetDraft(id: 'row-set', repetitions: '12')],
      ),
    );
    moveDetailedItem(session.exercises, 0, 1);
    moveDetailedItem(draft.weeks.first.sessions, 0, 1);
    moveDetailedItem(draft.weeks, 0, 1);
    final generated = generateDetailedRoutine(draft);
    expect(generated.orderedSessions.map((session) => session.id), [
      'w2d1',
      'w2d2',
      'w1d2',
      'w1d1',
    ]);
    expect(
      generated.orderedSessions.last.exercises.map((exercise) => exercise.id),
      ['row', 'exercise'],
    );
    expect(generated.orderedSessions.last.exercises.last.sets.last.id, 'fixed');
    expect(() => moveDetailedItem(draft.weeks, 0, 2), throwsRangeError);
  });

  test('숫자 범위와 무한값을 거절하고 오류에 주차·세션·운동·세트 위치를 표시한다', () {
    final mutations = <void Function(DetailedSetDraft)>[
      (set) => set.repetitions = '0',
      (set) => set.repetitions = '101',
      (set) => set.repetitions = '1.5',
      (set) => set.rir = '-1',
      (set) => set.rir = '11',
      (set) => set.rir = 'NaN',
      (set) => set.loadValue = '0',
      (set) => set.loadValue = '-0.5',
      (set) => set.loadValue = 'Infinity',
    ];
    for (final mutate in mutations) {
      final draft = fixtureDraft();
      mutate(firstSet(draft));
      final before = jsonCopy(draft.toJson());
      expect(
        () => generateDetailedRoutine(draft),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'context',
            contains('1주차 · 1번 세션 · 1번 운동 · 1번 세트'),
          ),
        ),
      );
      expect(draft.toJson(), before);
    }
  });

  test('주차/세션/운동/세트 구조의 상한과 하한을 검증한다', () {
    final mutations = <void Function(DetailedRoutineDraft)>[
      (draft) => draft.weeks.clear(),
      (draft) => draft.weeks.addAll(
        List.generate(51, (_) => draft.weeks.first.copy()),
      ),
      (draft) => draft.weeks.first.sessions.clear(),
      (draft) => draft.weeks.first.sessions.addAll(
        List.generate(6, (_) => draft.weeks.first.sessions.first.copy()),
      ),
      (draft) => draft.weeks.last.sessions.removeLast(),
      (draft) => draft.weeks.first.sessions.first.exercises.clear(),
      (draft) => draft.weeks.first.sessions.first.exercises.addAll(
        List.generate(
          20,
          (_) => draft.weeks.first.sessions.first.exercises.first.copy(),
        ),
      ),
      (draft) => draft.weeks.first.sessions.first.exercises.first.sets.clear(),
      (draft) => draft.weeks.first.sessions.first.exercises.first.sets.addAll(
        List.generate(8, (_) => firstSet(draft).copy()),
      ),
    ];
    for (final mutate in mutations) {
      final draft = fixtureDraft();
      mutate(draft);
      expect(() => generateDetailedRoutine(draft), throwsFormatException);
    }
  });

  test('ID 중복과 같은 운동 ID의 이름·메인 리프트 불일치를 검증한다', () {
    final mutations = <void Function(DetailedRoutineDraft)>[
      (draft) => draft.weeks.last.sessions.last.id =
          draft.weeks.first.sessions.first.id,
      (draft) => draft.weeks.first.sessions.first.exercises.add(
        draft.weeks.first.sessions.first.exercises.first.copy(),
      ),
      (draft) => draft.weeks.first.sessions.first.exercises.first.sets[1].id =
          firstSet(draft).id,
      (draft) => draft.weeks.last.sessions.last.exercises.first.name = '다른 운동',
      (draft) => draft.weeks.last.sessions.last.exercises.first.mainLift = null,
    ];
    for (final mutate in mutations) {
      final draft = fixtureDraft();
      mutate(draft);
      expect(() => generateDetailedRoutine(draft), throwsFormatException);
    }
  });

  test('새 프로그램을 소비자 계획으로 시작·복원해도 기존 계획과 수행 기록은 바뀌지 않는다', () {
    final original = fixturePlan();
    final firstId = original.sessions.first.exercises.first.sets.first.id;
    final originalState = TrainingAppState(activePlan: original).withSetActual(
      firstId,
      SetActual.completed(
        weight: 100,
        unit: WeightUnit.kg,
        repetitions: 5,
        performedDate: DateTime(2026, 9, 9),
      ),
    );
    final originalJson = jsonCopy(originalState.toJson());
    final draft = DetailedRoutineDraft.fromProgram(original.program);
    draft.version = 'test-v2';
    firstSet(draft).loadValue = '80';
    firstSet(draft).repetitions = '10';
    final candidate = generateDetailedRoutine(draft);
    final updatedPlan = createActivePlan(
      id: 'plan-v2',
      program: candidate,
      startDate: DateTime(2026, 9, 21),
      weekdays: [1, 3],
      incrementKg: 2.5,
      baselines: original.baselines,
    );
    final restored = TrainingAppState.fromJson(
      jsonCopy(originalState.withActivePlan(updatedPlan).toJson()),
    );
    expect(restored.activePlan!.program.toJson(), candidate.toJson());
    expect(
      restored.activePlan!.sessions.first.exercises.first.sets.first.targetKg,
      80,
    );
    expect(restored.planHistory.single.toJson(), original.toJson());
    expect(
      restored.setActuals[firstId]!.toJson(),
      originalState.setActuals[firstId]!.toJson(),
    );
    expect(originalState.toJson(), originalJson);
  });
}
