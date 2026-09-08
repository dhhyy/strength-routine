import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

ProgramSet advancedSet(
  String id, {
  int? restSeconds,
  String? tempo,
  bool isAmrap = false,
}) => ProgramSet(
  id: id,
  repetitions: 8,
  rir: 2,
  load: LoadPrescription.fixedKg(50),
  restSeconds: restSeconds,
  tempo: tempo,
  isAmrap: isAmrap,
);

ProgramExercise advancedExercise(String id, {String? group, int sets = 1}) =>
    ProgramExercise(
      id: id,
      name: id,
      supersetGroup: group,
      sets: [
        for (var i = 0; i < sets; i++)
          advancedSet(
            's${i + 1}',
            restSeconds: i == 0 ? 0 : 90,
            tempo: '3-1-X-0',
            isAmrap: i == sets - 1,
          ),
      ],
    );

TrainingProgram advancedProgram() => TrainingProgram(
  id: 'advanced-fixture',
  version: '1',
  title: '고급 처방 검증',
  trainerName: '테스트',
  description: '사용자 처방이 아닌 합성 데이터',
  weeks: 2,
  sessions: [
    for (var w = 1; w <= 2; w++)
      ProgramSession(
        id: 'week-$w',
        week: w,
        dayOrder: 1,
        title: '$w주차',
        exercises: [
          advancedExercise('before'),
          advancedExercise('a', group: 'A', sets: 2),
          advancedExercise('b', group: 'A', sets: 3),
          advancedExercise('after'),
        ],
      ),
  ],
);

ActiveTrainingPlan advancedPlan({String id = 'advanced-plan'}) =>
    createActivePlan(
      id: id,
      program: advancedProgram(),
      startDate: DateTime.utc(2026, 9, 7),
      weekdays: [1],
      incrementKg: 2.5,
    );

Map<String, dynamic> deepJson(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  test('기존 다섯 프로그램은 고급 키 없이 정확하게 JSON 왕복한다', () {
    final catalog =
        jsonDecode(File('assets/programs.json').readAsStringSync()) as Map;
    expect(catalog['schemaVersion'], 1);
    final programs = catalog['programs'] as List;
    expect(programs, hasLength(5));
    for (final original in programs) {
      final program = TrainingProgram.fromJson(
        Map<String, dynamic>.from(original as Map),
      );
      expect(program.hasAdvancedPrescriptions, isFalse);
      expect(program.toJson(), original);
      final draft = DetailedRoutineDraft.fromProgram(program);
      expect(draft.hasAdvancedPrescriptions, isFalse);
      expect(generateDetailedRoutine(draft.copy()).toJson(), original);
    }
  });

  test('세트의 누락 기본값과 nullable 값은 기존 JSON을 유지한다', () {
    final original = advancedSet('old').toJson();
    expect(original.keys, isNot(contains('restSeconds')));
    expect(original.keys, isNot(contains('tempo')));
    expect(original.keys, isNot(contains('isAmrap')));
    for (final json in [
      original,
      {...original, 'restSeconds': null, 'tempo': null, 'isAmrap': false},
    ]) {
      final set = ProgramSet.fromJson(json);
      expect(set.restSeconds, isNull);
      expect(set.tempo, isNull);
      expect(set.isAmrap, isFalse);
      expect(set.toJson(), original);
    }
  });

  test('휴식 0은 미지정과 구별되고 3600 경계까지 저장한다', () {
    for (final value in [0, 1, 90, 3600]) {
      final original = advancedSet('set', restSeconds: value);
      expect(original.hasAdvancedPrescriptions, isTrue);
      expect(ProgramSet.fromJson(original.toJson()).restSeconds, value);
    }
    for (final value in [-1, 3601]) {
      expect(
        () => advancedSet('set', restSeconds: value),
        throwsFormatException,
      );
    }
    for (final value in ['60', 1.5, 60.0, true, []]) {
      expect(
        () => ProgramSet.fromJson({
          ...advancedSet('set').toJson(),
          'restSeconds': value,
        }),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('템포는 네 구간만 허용하고 세 번째 구간에서만 X를 허용한다', () {
    for (final value in ['0-0-0-0', '3-1-X-0', '9-9-9-9']) {
      final set = advancedSet('set', tempo: value);
      expect(ProgramSet.fromJson(set.toJson()).tempo, value);
    }
    for (final value in [
      '',
      '3100',
      '3-1-x-0',
      'X-1-1-0',
      '3-X-1-0',
      '3-1-1-X',
      '10-1-1-0',
      '3-1-X-0 ',
      '3-1-X-0\n',
    ]) {
      expect(
        () => advancedSet('set', tempo: value),
        throwsFormatException,
        reason: value,
      );
    }
    for (final value in [1, false, []]) {
      expect(
        () => ProgramSet.fromJson({
          ...advancedSet('set').toJson(),
          'tempo': value,
        }),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('AMRAP은 strict boolean이고 실제 반복을 기준 반복에 묶지 않는다', () {
    expect(
      ProgramSet.fromJson(advancedSet('set', isAmrap: true).toJson()).isAmrap,
      isTrue,
    );
    for (final value in ['true', 1, null, []]) {
      expect(
        () => ProgramSet.fromJson({
          ...advancedSet('set').toJson(),
          'isAmrap': value,
        }),
        throwsA(isA<TypeError>()),
      );
    }
    final plan = advancedPlan();
    final set = plan.sessions.first.executionSets.last.set;
    expect(set.isAmrap, isTrue);
    for (final repetitions in [2, 14]) {
      final state = TrainingAppState(activePlan: plan).withSetActual(
        set.id,
        SetActual.completed(
          weight: 50,
          unit: WeightUnit.kg,
          repetitions: repetitions,
        ),
      );
      expect(state.setActuals[set.id]!.repetitions, repetitions);
      expect(
        state.activePlan!.sessions.first.executionSets.last.set.repetitions,
        8,
      );
    }
  });

  test('슈퍼세트 그룹은 trim된 비어있지 않은 40자 이하 문자열이다', () {
    for (final group in ['', ' ', ' A', 'A ', List.filled(41, 'a').join()]) {
      expect(() => advancedExercise('e', group: group), throwsFormatException);
    }
    expect(
      advancedExercise(
        'e',
        group: List.filled(40, 'a').join(),
      ).supersetGroup!.length,
      40,
    );
    for (final value in [1, true, []]) {
      expect(
        () => ProgramExercise.fromJson({
          ...advancedExercise('e').toJson(),
          'supersetGroup': value,
        }),
        throwsA(isA<TypeError>()),
      );
    }
    final original = ProgramExercise(
      id: 'e',
      name: 'e',
      sets: [advancedSet('s')],
    );
    expect(
      ProgramExercise.fromJson({
        ...original.toJson(),
        'supersetGroup': null,
      }).toJson(),
      original.toJson(),
    );
  });

  test('같은 세션에서 그룹 하나에 연속된 운동 2개 이상이 필요하다', () {
    ProgramSession session(List<String?> groups) => ProgramSession(
      id: 's',
      week: 1,
      dayOrder: 1,
      title: 's',
      exercises: [
        for (var i = 0; i < groups.length; i++)
          advancedExercise('e$i', group: groups[i]),
      ],
    );
    for (final groups in <List<String?>>[
      ['A'],
      ['A', null, 'A'],
      ['A', 'A', null, 'A', 'A'],
      ['A', 'A', 'B'],
    ]) {
      expect(() => session(groups), throwsFormatException);
    }
    expect(session(['A', 'A', 'B', 'B', 'B']).exercises, hasLength(5));
    expect(session([null]).exercises, hasLength(1));
  });

  test('슈퍼세트 실행 순서는 서로 다른 세트 수를 round robin으로 펼친다', () {
    final session = advancedPlan().sessions.first;
    expect(
      session.executionSets.map(
        (entry) => '${entry.exercise.name}:${entry.number}',
      ),
      ['before:1', 'a:1', 'b:1', 'a:2', 'b:2', 'b:3', 'after:1'],
    );
    expect(
      session.executionSets.map((e) => e.set.id).toSet(),
      session.exercises.expand((e) => e.sets).map((s) => s.id).toSet(),
    );
    expect(() => session.executionSets.clear(), throwsUnsupportedError);
  });

  test('미그룹 운동 순서와 세트별 계획 처방은 복원 뒤에도 동일하다', () {
    final plan = advancedPlan();
    final restored = ActiveTrainingPlan.fromJson(deepJson(plan.toJson()));
    expect(restored.toJson(), plan.toJson());
    expect(restored.sessions.first.exercises[1].supersetGroup, 'A');
    final first = restored.sessions.first.executionSets.first.set;
    expect(first.restSeconds, 0);
    expect(first.tempo, '3-1-X-0');
    expect(first.isAmrap, isTrue);
    final plain = advancedProgram().toJson();
    for (final session in plain['sessions'] as List) {
      for (final exercise in session['exercises'] as List) {
        exercise.remove('supersetGroup');
      }
    }
    final ungrouped = createActivePlan(
      id: 'plain',
      program: TrainingProgram.fromJson(plain),
      startDate: plan.startDate,
      weekdays: [1],
      incrementKg: 2.5,
    ).sessions.first;
    expect(
      ungrouped.executionSets.map((entry) => entry.set.id),
      ungrouped.exercises
          .expand((exercise) => exercise.sets)
          .map((set) => set.id),
    );
  });

  test('고급 초안은 import·copy·주차 복사·재생성에서 처방을 유지한다', () {
    final program = advancedProgram();
    final draft = DetailedRoutineDraft.fromProgram(program);
    expect(draft.hasAdvancedPrescriptions, isTrue);
    expect(generateDetailedRoutine(draft.copy()).toJson(), program.toJson());
    final source = draft.weeks.first.toJson();
    final added = draft.appendWeekCopy(0);
    final copySet = draft.weeks[added].sessions.first.exercises[1].sets.first;
    expect(copySet.restSeconds, '0');
    expect(copySet.tempo, '3-1-X-0');
    copySet.restSeconds = '120';
    expect(draft.weeks.first.toJson(), source);
    draft.copyWeekOnto(added, 1);
    expect(
      draft.weeks[1].sessions.first.exercises[1].sets.first.restSeconds,
      '120',
    );
    expect(draft.weeks[1].sessions.first.exercises[1].supersetGroup, 'A');
    expect(generateDetailedRoutine(draft).weeks, 3);
  });

  test('잘못된 고급 원문은 저장·복사에 남지만 생성은 문맥을 포함해 거절한다', () {
    final draft = DetailedRoutineDraft.fromProgram(advancedProgram());
    final set = draft.weeks.first.sessions.first.exercises.first.sets.first;
    for (final invalid in ['90.', '-1', '3601', 'NaN']) {
      set.restSeconds = invalid;
      final copy = draft.copy();
      expect(
        copy.weeks.first.sessions.first.exercises.first.sets.first.restSeconds,
        invalid,
      );
      expect(
        () => generateDetailedRoutine(copy),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'context',
            contains('1주차 · 1번 세션 · 1번 운동 · 1번 세트 휴식'),
          ),
        ),
      );
    }
    set.restSeconds = '90';
    set.tempo = '3-1-';
    expect(
      draft.copy().weeks.first.sessions.first.exercises.first.sets.first.tempo,
      '3-1-',
    );
    expect(() => generateDetailedRoutine(draft), throwsFormatException);
  });

  test('고급 초안 신규 키는 선택적이지만 잘못된 타입은 거절한다', () {
    final set = DetailedSetDraft(id: 's').toJson();
    expect(DetailedSetDraft.fromJson(set).restSeconds, '');
    expect(DetailedSetDraft.fromJson(set).tempo, '');
    expect(DetailedSetDraft.fromJson(set).isAmrap, isFalse);
    for (final field in ['restSeconds', 'tempo']) {
      for (final value in [null, 0, false, []]) {
        expect(
          () => DetailedSetDraft.fromJson({...set, field: value}),
          throwsFormatException,
        );
      }
    }
    for (final value in [null, 0, 'true']) {
      expect(
        () => DetailedSetDraft.fromJson({...set, 'isAmrap': value}),
        throwsFormatException,
      );
    }
    final exercise = DetailedExerciseDraft().toJson();
    expect(DetailedExerciseDraft.fromJson(exercise).supersetGroup, '');
    for (final value in [null, 1, true, []]) {
      expect(
        () => DetailedExerciseDraft.fromJson({
          ...exercise,
          'supersetGroup': value,
        }),
        throwsFormatException,
      );
    }
  });

  test('그룹 편집·이동으로 깨진 초안은 원문을 보존하고 생성 시 차단한다', () {
    final draft = DetailedRoutineDraft.fromProgram(advancedProgram());
    final exercises = draft.weeks.first.sessions.first.exercises;
    moveDetailedItem(exercises, 2, 3);
    final copy = draft.copy();
    expect(
      copy.weeks.first.sessions.first.exercises.map((e) => e.supersetGroup),
      ['', 'A', '', 'A'],
    );
    expect(
      () => generateDetailedRoutine(copy),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'context',
          contains('1주차 · 1번 세션 슈퍼세트 A'),
        ),
      ),
    );
    moveDetailedItem(exercises, 3, 2);
    exercises[1].supersetGroup = ' A ';
    expect(
      draft.copy().weeks.first.sessions.first.exercises[1].supersetGroup,
      ' A ',
    );
    expect(() => generateDetailedRoutine(draft), throwsFormatException);
  });

  test('빈 휴식 초안은 미지정으로 생성하고 0은 명시적 처방으로 남긴다', () {
    final draft = DetailedRoutineDraft.fromProgram(advancedProgram());
    final set = draft.weeks.first.sessions.first.exercises.first.sets.first;
    set.restSeconds = '';
    set.tempo = '';
    set.isAmrap = false;
    final generated = generateDetailedRoutine(
      draft,
    ).sessions.first.exercises.first.sets.first;
    expect(generated.hasAdvancedPrescriptions, isFalse);
    set.restSeconds = '0';
    expect(
      generateDetailedRoutine(
        draft,
      ).sessions.first.exercises.first.sets.first.restSeconds,
      0,
    );
  });

  test('고급 키 탐색은 JSON 구조의 키만 검사한다', () {
    expect(
      containsAdvancedPrescriptionFields({
        'title': 'restSeconds tempo isAmrap supersetGroup',
        'description': '{"tempo":"3-1-X-0"}',
      }),
      isFalse,
    );
    expect(
      containsAdvancedPrescriptionFields({
        'sessions': [
          {
            'exercises': [
              {
                'sets': [
                  {'isAmrap': false},
                ],
              },
            ],
          },
        ],
      }),
      isTrue,
    );
    expect(containsAdvancedPrescriptionFields({'supersetGroup': null}), isTrue);
  });
}
