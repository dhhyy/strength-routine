import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/detailed_bulk_edit.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/prescription_widgets.dart';

import 'detailed_routine_test.dart' show fixtureDraft, firstSet, jsonCopy;
import 'training_program_fixtures.dart';
import 'training_insights_fixtures.dart';

ProgramSet _set({
  int? max,
  ProgramSetKind kind = ProgramSetKind.work,
  bool amrap = false,
}) => ProgramSet(
  id: 'set',
  repetitions: 8,
  repetitionsMax: max,
  kind: kind,
  isAmrap: amrap,
  load: const LoadPrescription.manual(),
);
DetailedBulkPreview _bulk(
  DetailedRoutineDraft draft,
  DetailedBulkScope scope,
  DetailedBulkField field,
  String value, {
  ProgramSetKind kind = ProgramSetKind.work,
}) => previewDetailedBulkEdit(
  source: draft,
  weekIndex: 0,
  sessionIndex: 0,
  exerciseIndex: 0,
  scope: scope,
  field: field,
  value: value,
  kind: kind,
);
TrainingProgram _version(String version, {String title = 'Test fixture'}) {
  final json = jsonCopy(fixtureProgram(version: version).toJson())
    ..['title'] = title;
  return TrainingProgram.fromJson(json);
}

void main() {
  test('기본 세트는 기존 JSON 모양을 유지하며 새 범위·종류를 왕복한다', () {
    expect(_set().toJson().containsKey('repetitionsMax'), isFalse);
    expect(_set().toJson().containsKey('setKind'), isFalse);
    for (final kind in ProgramSetKind.values) {
      final set = _set(max: 12, kind: kind);
      final restored = ProgramSet.fromJson(jsonCopy(set.toJson()));
      expect(restored.repetitionsMax, 12);
      expect(restored.kind, kind);
      expect(restored.toJson(), set.toJson());
      expect(repetitionLabel(restored), '8–12회');
    }
  });
  test('상한 순서·최대값·AMRAP 충돌·유형 오류는 거부한다', () {
    for (final value in [-1, 0, 7, 101]) {
      expect(() => _set(max: value), throwsFormatException);
    }
    expect(() => _set(max: 12, amrap: true), throwsFormatException);
    expect(
      () => ProgramSet.fromJson(
        jsonCopy(_set().toJson())..['repetitionsMax'] = '12',
      ),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ProgramSet.fromJson(
        jsonCopy(_set().toJson())..['setKind'] = 'circuit',
      ),
      throwsArgumentError,
    );
    expect(_set(max: 8).repetitionsMax, 8);
  });
  test('반복 상한 원문과 종류는 잘못된 초안·복사·생성 실패 후 보존된다', () {
    final draft = fixtureDraft();
    firstSet(draft)
      ..repetitionsMax = ' 8.'
      ..kind = ProgramSetKind.drop;
    final before = jsonCopy(draft.toJson());
    final restored = DetailedRoutineDraft.fromJson(before);
    expect(restored.copy().toJson(), before);
    expect(restored.hasExtendedPrescriptions, isTrue);
    expect(() => generateDetailedRoutine(restored), throwsFormatException);
    expect(restored.toJson(), before);
    firstSet(restored).repetitionsMax = '8';
    final generated = generateDetailedRoutine(restored);
    expect(generated.hasExtendedPrescriptions, isTrue);
    expect(
      DetailedRoutineDraft.fromProgram(generated).toJson(),
      restored.toJson(),
    );
  });
  test('구버전 envelope 감지는 기본값도 구조적으로 감지한다', () {
    expect(
      containsExtendedPrescriptionFields({
        'nested': [
          {'setKind': 'work'},
        ],
      }),
      isTrue,
    );
    expect(
      containsExtendedPrescriptionFields({'repetitionsMax': null}),
      isTrue,
    );
    expect(
      containsExtendedPrescriptionFields({
        'description': 'setKind repetitionsMax',
      }),
      isFalse,
    );
  });
  for (final scope in DetailedBulkScope.values) {
    test('일괄 ${scope.name}는 지정 범위만 수정하고 원본과 나머지 필드를 보존한다', () {
      final draft = fixtureDraft();
      final before = jsonCopy(draft.toJson());
      final preview = _bulk(draft, scope, DetailedBulkField.restSeconds, '45');
      expect(preview.targetCount, switch (scope) {
        DetailedBulkScope.exercise || DetailedBulkScope.session => 3,
        DetailedBulkScope.week => 6,
        DetailedBulkScope.program => 12,
      });
      expect(preview.changes.length, preview.targetCount);
      expect(preview.matches(draft), isTrue);
      expect(draft.toJson(), before);
      final candidate = preview.candidate;
      for (var wi = 0; wi < candidate.weeks.length; wi++) {
        for (var si = 0; si < candidate.weeks[wi].sessions.length; si++) {
          final selected =
              scope == DetailedBulkScope.program ||
              wi == 0 && (scope == DetailedBulkScope.week || si == 0);
          final sets = candidate.weeks[wi].sessions[si].exercises.first.sets;
          for (var ti = 0; ti < sets.length; ti++) {
            final old = draft.weeks[wi].sessions[si].exercises.first.sets[ti]
                .toJson();
            final expected = {...old, if (selected) 'restSeconds': '45'};
            expect(sets[ti].toJson(), expected);
          }
        }
      }
      draft.title = 'changed';
      expect(preview.matches(draft), isFalse);
    });
  }
  test('일괄 상한/종류/RIR 해제는 개별 필드만 바꾸고 중량 변환은 명시적이다', () {
    final draft = fixtureDraft();
    final upper = _bulk(
      draft,
      DetailedBulkScope.program,
      DetailedBulkField.repetitionsMax,
      '12',
    ).candidate;
    expect(firstSet(upper).repetitionsMax, '12');
    final cleared = _bulk(
      upper,
      DetailedBulkScope.program,
      DetailedBulkField.repetitionsMax,
      '',
    ).candidate;
    expect(cleared.toJson(), draft.toJson());
    final kind = _bulk(
      draft,
      DetailedBulkScope.exercise,
      DetailedBulkField.kind,
      '',
      kind: ProgramSetKind.warmup,
    ).candidate;
    expect(firstSet(kind).kind, ProgramSetKind.warmup);
    expect(firstSet(kind).loadKind, firstSet(draft).loadKind);
    final rir = _bulk(
      draft,
      DetailedBulkScope.exercise,
      DetailedBulkField.rir,
      '',
    ).candidate;
    expect(firstSet(rir).rir, '');
    final load = _bulk(
      draft,
      DetailedBulkScope.exercise,
      DetailedBulkField.fixedKg,
      '20',
    ).candidate;
    final converted = load.weeks.first.sessions.first.exercises.first.sets;
    expect(
      converted.every(
        (s) =>
            s.loadKind == LoadKind.fixedKg &&
            s.loadLift == null &&
            s.loadValue == '20',
      ),
      isTrue,
    );
    expect(converted.map((s) => s.isRequired), [true, true, false]);
  });
  test('일괄 유효성 실패/AMRAP 충돌/범위 오류는 원문을 변경하지 않는다', () {
    final draft = fixtureDraft();
    for (final entry in [
      (DetailedBulkField.repetitions, '101'),
      (DetailedBulkField.repetitionsMax, '2'),
      (DetailedBulkField.rir, 'NaN'),
      (DetailedBulkField.restSeconds, '-1'),
      (DetailedBulkField.fixedKg, '0'),
    ]) {
      final before = jsonCopy(draft.toJson());
      expect(
        () => _bulk(draft, DetailedBulkScope.program, entry.$1, entry.$2),
        throwsFormatException,
      );
      expect(draft.toJson(), before);
    }
    firstSet(draft).isAmrap = true;
    expect(
      () => _bulk(
        draft,
        DetailedBulkScope.exercise,
        DetailedBulkField.repetitionsMax,
        '12',
      ),
      throwsFormatException,
    );
  });
  test('같은 값 일괄 검토는 대상 수와 실제 변경 수를 구별한다', () {
    final draft = fixtureDraft();
    final preview = _bulk(
      draft,
      DetailedBulkScope.exercise,
      DetailedBulkField.kind,
      '',
    );
    expect(preview.targetCount, 3);
    expect(preview.changes, isEmpty);
    expect(preview.candidate.toJson(), draft.toJson());
  });
  test('카탈로그 보관/복원은 export만 바꾸고 스냅샷과 이력을 보존한다', () {
    final workspace = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [_version('1')],
    );
    final archived = workspace.withArchived('fixture', true);
    expect(archived.toJson()['schemaVersion'], 4);
    expect(jsonDecode(archived.exportCatalog())['programs'], isEmpty);
    expect(workspace.archivedProgramIds, isEmpty);
    final restored = AdminWorkspace.fromJson(
      jsonCopy(archived.toJson()),
    ).withArchived('fixture', false);
    expect(
      restored.programs.single.toJson(),
      workspace.programs.single.toJson(),
    );
    expect(jsonDecode(restored.exportCatalog())['programs'], hasLength(1));
    expect(() => archived.archivedProgramIds.clear(), throwsUnsupportedError);
  });
  test('과거 버전은 불변이며 복구를 새 버전으로 저장한다', () {
    final initial = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [_version('1')],
    );
    final second = initial.withProgram(_version('2', title: 'Changed'), null);
    final draft = DetailedRoutineDraft.fromProgram(
      second.versionsFor('fixture').first,
    )..version = second.nextVersionFor('fixture');
    expect(draft.version, '3');
    final third = second.withProgram(generateDetailedRoutine(draft), draft);
    expect(third.versionsFor('fixture').map((p) => p.version), ['1', '2', '3']);
    expect(third.programs.single.title, 'Test fixture');
    expect(second.programs.single.title, 'Changed');
    expect(
      third.versionsFor('fixture').first.toJson(),
      initial.programs.single.toJson(),
    );
    expect(
      () => third.withProgram(_version('1', title: 'Overwrite'), null),
      throwsFormatException,
    );
    expect(() => third.versionHistory.clear(), throwsUnsupportedError);
    expect(jsonDecode(third.exportCatalog()).keys.toSet(), {
      'schemaVersion',
      'programs',
    });
  });
  test('중복/고아/충돌 이력과 알 수 없는 보관 ID는 거부한다', () {
    final p = _version('1');
    expect(
      () => AdminWorkspace(
        draft: RoutineBlueprint(),
        programs: [p],
        archivedProgramIds: {'unknown'},
      ),
      throwsFormatException,
    );
    expect(
      () => AdminWorkspace(
        draft: RoutineBlueprint(),
        programs: [p],
        versionHistory: [p, p],
      ),
      throwsFormatException,
    );
    expect(
      () => AdminWorkspace(
        draft: RoutineBlueprint(),
        programs: [p],
        versionHistory: [_version('1', title: 'Changed')],
      ),
      throwsFormatException,
    );
    expect(
      () => AdminWorkspace(
        draft: RoutineBlueprint(),
        programs: [],
        versionHistory: [p],
      ),
      throwsFormatException,
    );
  });
  test('관리자 새 필드는 v4, 공개 확장 처방은 v3이고 구버전 위장 필드를 거부한다', () {
    final draft = fixtureDraft();
    firstSet(draft)
      ..repetitionsMax = '8'
      ..kind = ProgramSetKind.drop;
    final workspace = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [generateDetailedRoutine(draft)],
      detailedDraft: draft,
    );
    expect(workspace.toJson()['schemaVersion'], 4);
    expect(jsonDecode(workspace.exportCatalog())['schemaVersion'], 3);
    for (final schema in [1, 2, 3]) {
      final json = jsonCopy(workspace.toJson())..['schemaVersion'] = schema;
      if (schema == 1) json.remove('detailedDraft');
      expect(() => AdminWorkspace.fromJson(json), throwsFormatException);
    }
    for (final field in ['archivedProgramIds', 'versionHistory']) {
      final json = jsonCopy(
        AdminWorkspace(
          draft: RoutineBlueprint(),
          programs: [_version('1')],
        ).toJson(),
      )..[field] = [];
      expect(() => AdminWorkspace.fromJson(json), throwsFormatException);
    }
  });
  test('원문 새 필드만 있으면 관리자 v4지만 공개 프로그램은 기존 v1이다', () {
    final draft = fixtureDraft();
    firstSet(draft).repetitionsMax = '8.';
    final workspace = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [fixtureProgram()],
      detailedDraft: draft,
    );
    expect(workspace.toJson()['schemaVersion'], 4);
    expect(jsonDecode(workspace.exportCatalog())['schemaVersion'], 1);
    expect(
      AdminWorkspace.fromJson(
        jsonCopy(workspace.toJson()),
      ).detailedDraft!.toJson(),
      draft.toJson(),
    );
  });
  test('실제 파일은 보관/버전/초안/확장 처방을 재로딩하고 export 제외를 유지한다', () async {
    final dir = await Directory.systemTemp.createTemp('lc04-store-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/workspace.json');
    final draft = fixtureDraft()..version = '2';
    firstSet(draft)
      ..kind = ProgramSetKind.warmup
      ..repetitionsMax = '8';
    final workspace =
        AdminWorkspace(draft: RoutineBlueprint(), programs: [_version('1')])
            .withProgram(generateDetailedRoutine(draft), draft)
            .withArchived('fixture', true);
    await AdminProgramStore(file).save(workspace);
    final loaded = (await AdminProgramStore(file).load())!;
    expect(loaded.toJson(), workspace.toJson());
    expect(loaded.versionsFor('fixture'), hasLength(2));
    final export = await AdminProgramStore(file).export(loaded);
    expect(jsonDecode(await export.readAsString())['programs'], isEmpty);
  });
  test('범위 밖 실제 반복은 실패로 단정하지 않고 D5 비교에서 제외한다', () {
    final json = jsonCopy(insightsPlan().program.toJson());
    for (final session in json['sessions']) {
      session['exercises'][0]['sets'][0]['repetitionsMax'] = 8;
    }
    final plan = createActivePlan(
      id: 'range-boundary',
      program: TrainingProgram.fromJson(json),
      startDate: DateTime.utc(2026, 8, 3),
      weekdays: [1],
      incrementKg: 2.5,
    );
    for (final repetitions in [4, 9]) {
      var state = insightsState(plan: plan);
      final set = plan.sessions[1].exercises.single.sets.first;
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: 100,
          unit: WeightUnit.kg,
          repetitions: repetitions,
          rir: 0,
          performedDate: plan.sessions[1].date,
        ),
      );
      final trend = buildTrainingInsights(
        state,
        planId: plan.id,
        asOf: insightsToday,
      ).single;
      expect(trend.points[1].comparableRirGap, isNull);
      expect(trend.points[1].performedSets, 2);
      expect(trend.points[1].repetitions, repetitions + 5);
      expect(trend.suggestion, isNull);
    }
  });
  for (final kind in [ProgramSetKind.warmup, ProgramSetKind.drop]) {
    test('D5 ${kind.name}은 비교/감량 대상에서 제외하지만 실제 통계와 필수 조건은 유지한다', () {
      final json = jsonCopy(insightsPlan().program.toJson());
      for (final session in json['sessions']) {
        session['exercises'][0]['sets'][0]['repetitionsMax'] = 8;
        session['exercises'][0]['sets'][1]['setKind'] = kind.name;
      }
      final plan = createActivePlan(
        id: 'extended-d5',
        program: TrainingProgram.fromJson(json),
        startDate: DateTime.utc(2026, 8, 3),
        weekdays: [1],
        incrementKg: 2.5,
      );
      var state = insightsState(plan: plan);
      for (final session in plan.sessions.take(3)) {
        final set = session.exercises.single.sets.first;
        state = state.withSetActual(
          set.id,
          SetActual.completed(
            weight: 100,
            unit: WeightUnit.kg,
            repetitions: 8,
            rir: 1,
            performedDate: session.date,
          ),
        );
        state = state.withSetActual(
          session.exercises.single.sets[1].id,
          SetActual.completed(
            weight: 30,
            unit: WeightUnit.kg,
            repetitions: 11,
            rir: null,
            performedDate: session.date,
          ),
        );
      }
      final trend = buildTrainingInsights(
        state,
        planId: plan.id,
        asOf: insightsToday,
      ).single;
      expect(
        trend.points.every(
          (p) =>
              p.performedSets == 2 &&
              p.repetitions == 19 &&
              p.comparableRirGap == 1,
        ),
        isTrue,
      );
      final futureSpecial = plan.sessions
          .skip(3)
          .expand((s) => s.exercises.single.sets)
          .where((s) => s.kind != ProgramSetKind.work)
          .map((s) => s.id)
          .toSet();
      expect(
        trend.suggestion!.afterKg.keys.any(futureSpecial.contains),
        isFalse,
      );
      final missing = state.withSetActual(
        plan.sessions[1].exercises.single.sets[1].id,
        null,
      );
      expect(
        buildTrainingInsights(
          missing,
          planId: plan.id,
          asOf: insightsToday,
        ).single.suggestion,
        isNull,
      );
    });
  }
}
