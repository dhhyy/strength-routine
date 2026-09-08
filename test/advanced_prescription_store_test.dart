import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'admin_routine_test.dart' show validBlueprint;
import 'advanced_prescription_test.dart'
    show advancedProgram, advancedPlan, deepJson;
import 'training_insights_fixtures.dart';
import 'training_program_fixtures.dart';

void main() {
  late Directory directory;
  late File adminFile, stateFile;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('advanced-prescription-');
    adminFile = File('${directory.path}/admin.json');
    stateFile = File('${directory.path}/state.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test('고급 값 없는 기존 관리자 작업은 v2와 카탈로그 v1을 유지한다', () async {
    final basic = validBlueprint();
    final program = generateRoutine(basic);
    final workspace = AdminWorkspace(
      draft: basic,
      programs: [program],
      detailedDraft: DetailedRoutineDraft.fromProgram(program),
    );
    expect(workspace.hasAdvancedPrescriptions, isFalse);
    expect(workspace.toJson()['schemaVersion'], 2);
    expect((jsonDecode(workspace.exportCatalog()) as Map)['schemaVersion'], 1);
    final store = AdminProgramStore(adminFile);
    await store.save(workspace);
    expect(
      (await AdminProgramStore(adminFile).load())!.toJson(),
      workspace.toJson(),
    );
  });

  test('완성 카탈로그는 v2, 관리자 고급 편집 저장은 v3로 복원한다', () async {
    final program = advancedProgram();
    final workspace = AdminWorkspace(
      draft: validBlueprint(),
      programs: [program],
      detailedDraft: DetailedRoutineDraft.fromProgram(program),
    );
    expect(workspace.toJson()['schemaVersion'], 3);
    final store = AdminProgramStore(adminFile);
    await store.save(workspace);
    final restored = (await AdminProgramStore(adminFile).load())!;
    expect(restored.toJson(), workspace.toJson());
    final catalog =
        jsonDecode(await (await store.export(restored)).readAsString()) as Map;
    expect(catalog['schemaVersion'], 2);
    expect(catalog.keys.toSet(), {'schemaVersion', 'programs'});
    expect(
      TrainingProgram.fromJson(
        Map<String, dynamic>.from((catalog['programs'] as List).single as Map),
      ).toJson(),
      program.toJson(),
    );
  });

  test('미완성 원문만 고급 값이면 관리자 v3이고 내보낸 카탈로그는 v1이다', () async {
    final basic = validBlueprint();
    final program = generateRoutine(basic);
    final draft = DetailedRoutineDraft.fromProgram(program);
    final set = draft.weeks.first.sessions.first.exercises.first.sets.first;
    set.restSeconds = '90.';
    set.tempo = '3-1-';
    draft.weeks.first.sessions.first.exercises.first.supersetGroup = ' A ';
    final workspace = AdminWorkspace(
      draft: basic,
      programs: [program],
      detailedDraft: draft,
    );
    expect(workspace.toJson()['schemaVersion'], 3);
    expect((jsonDecode(workspace.exportCatalog()) as Map)['schemaVersion'], 1);
    await AdminProgramStore(adminFile).save(workspace);
    final restored = (await AdminProgramStore(adminFile).load())!;
    expect(restored.detailedDraft!.toJson(), draft.toJson());
    expect(
      () => generateDetailedRoutine(restored.detailedDraft!),
      throwsFormatException,
    );
    expect(restored.programs.single.toJson(), program.toJson());
  });

  test('관리자 v1·v2의 고급 필드 키는 기본값이어도 거부하고 원본을 보존한다', () async {
    final basic = validBlueprint();
    final program = generateRoutine(basic);
    for (final version in [1, 2]) {
      for (final field in ['restSeconds', 'tempo', 'isAmrap']) {
        final json = deepJson(
          AdminWorkspace(draft: basic, programs: [program]).toJson(),
        );
        json['schemaVersion'] = version;
        if (version == 1) json.remove('detailedDraft');
        final set =
            json['programs'][0]['sessions'][0]['exercises'][0]['sets'][0]
                as Map;
        set[field] = field == 'isAmrap' ? false : null;
        final bytes = jsonEncode(json);
        await adminFile.writeAsString(bytes);
        await expectLater(
          AdminProgramStore(adminFile).load(),
          throwsFormatException,
        );
        expect(await adminFile.readAsString(), bytes);
      }
    }
    final json = deepJson(
      AdminWorkspace(
        draft: basic,
        programs: [program],
        detailedDraft: DetailedRoutineDraft.fromProgram(program),
      ).toJson(),
    );
    json['detailedDraft']['weeks'][0]['sessions'][0]['exercises'][0]['supersetGroup'] =
        '';
    expect(() => AdminWorkspace.fromJson(json), throwsFormatException);
  });

  test('관리자 v3도 필수 상세 초안 키·필드 타입·미래 버전을 검사한다', () async {
    final original = AdminWorkspace(
      draft: validBlueprint(),
      programs: [advancedProgram()],
      detailedDraft: DetailedRoutineDraft.fromProgram(advancedProgram()),
    ).toJson();
    for (final invalid in [
      deepJson(original)..remove('detailedDraft'),
      deepJson(original)..['schemaVersion'] = 4,
    ]) {
      expect(() => AdminWorkspace.fromJson(invalid), throwsFormatException);
    }
    final invalidType = deepJson(original);
    invalidType['programs'][0]['sessions'][0]['exercises'][0]['sets'][0]['restSeconds'] =
        '90';
    final bytes = jsonEncode(invalidType);
    await adminFile.writeAsString(bytes);
    await expectLater(
      AdminProgramStore(adminFile).load(),
      throwsA(isA<TypeError>()),
    );
    expect(await adminFile.readAsString(), bytes);
  });

  test('고급 초안 큐는 저장 호출 당시 원문을 독립 스냅샷으로 보존한다', () async {
    final draft = DetailedRoutineDraft.fromProgram(advancedProgram());
    final workspace = AdminWorkspace(
      draft: validBlueprint(),
      programs: [],
      detailedDraft: draft,
    );
    final expected = deepJson(workspace.toJson());
    final save = AdminProgramStore(adminFile).save(workspace);
    draft.weeks.first.sessions.first.exercises.first.sets.first.restSeconds =
        '999.';
    await save;
    expect((await AdminProgramStore(adminFile).load())!.toJson(), expected);
  });

  test('운동 v4는 실제값·원문 초안·고급 처방과 D5 적용 및 되돌리기를 복원한다', () async {
    final programJson = deepJson(insightsPlan().program.toJson());
    for (final session in programJson['sessions'] as List) {
      final exercises = session['exercises'] as List;
      final first = exercises.first as Map;
      first['supersetGroup'] = 'A';
      for (final set in first['sets'] as List) {
        set['restSeconds'] = 90;
        set['tempo'] = '3-1-X-0';
      }
      (first['sets'] as List).last['isAmrap'] = true;
      exercises.add({
        'id': 'support',
        'name': '보조',
        'mainLift': null,
        'supersetGroup': 'A',
        'sets': [
          {
            'id': 'set',
            'repetitions': 8,
            'rir': 2,
            'load': {'kind': 'manual', 'value': null, 'lift': null},
            'isRequired': false,
            'restSeconds': 0,
          },
        ],
      });
    }
    final plan = createActivePlan(
      id: 'advanced-insights',
      program: TrainingProgram.fromJson(programJson),
      startDate: DateTime.utc(2026, 8, 3),
      weekdays: [1],
      incrementKg: 2.5,
    );
    var state = TrainingAppState(activePlan: plan, onboarded: true);
    for (final session in plan.sessions.take(3)) {
      for (final set in session.exercises.first.sets.where(
        (set) => set.isRequired,
      )) {
        state = state.withSetActual(
          set.id,
          SetActual.completed(
            weight: 100,
            unit: WeightUnit.kg,
            repetitions: 5,
            rir: 1,
            performedDate: session.date,
          ),
        );
      }
    }
    final draftId = plan.sessions[3].exercises.first.sets.last.id;
    state = state.withSetDraft(draftId, {'weight': '42.', 'repetitions': '12'});
    final proposal = buildTrainingInsights(
      state,
      planId: plan.id,
      asOf: insightsToday,
    ).firstWhere((trend) => trend.suggestion != null).suggestion!;
    state = state.withLoadAdjustment(proposal, asOf: insightsToday);
    final store = LocalTrainingStore(stateFile);
    await store.save(state);
    expect(
      (jsonDecode(await stateFile.readAsString()) as Map)['schemaVersion'],
      4,
    );
    final restored = await LocalTrainingStore(stateFile).load();
    expect(restored.toJson(), state.toJson());
    expect(restored.setDrafts[draftId]!['weight'], '42.');
    final target = restored.activePlan!.sessions[3].exercises.first.sets.first;
    expect(restored.effectiveTargetKg(target), 95);
    expect(target.restSeconds, 90);
    expect(target.tempo, '3-1-X-0');
    expect(
      restored.activePlan!.sessions[3].exercises.first.sets.last.isAmrap,
      isTrue,
    );
    expect(restored.activePlan!.sessions[3].exercises.first.supersetGroup, 'A');
    final undone = restored.undoLoadAdjustment(
      proposal.id,
      asOf: insightsToday,
    );
    await store.save(undone);
    final reopened = await LocalTrainingStore(stateFile).load();
    expect(reopened.loadAdjustments.single.isUndone, isTrue);
    expect(
      reopened.effectiveTargetKg(
        reopened.activePlan!.sessions[3].exercises.first.sets.first,
      ),
      100,
    );
    expect(reopened.activePlan!.program.toJson(), plan.program.toJson());
    expect(
      reopened.setActuals.map((key, value) => MapEntry(key, value.toJson())),
      state.setActuals.map((key, value) => MapEntry(key, value.toJson())),
    );
  });

  test('고급 활성 계획이 없어도 보관 이력에 있으면 운동 v4를 유지한다', () async {
    final original = TrainingAppState(
      activePlan: advancedPlan(),
    ).withActivePlan(fixturePlan());
    expect(original.activePlan!.program.hasAdvancedPrescriptions, isFalse);
    expect(original.hasAdvancedPrescriptions, isTrue);
    await LocalTrainingStore(stateFile).save(original);
    expect(
      (jsonDecode(await stateFile.readAsString()) as Map)['schemaVersion'],
      4,
    );
    expect(
      (await LocalTrainingStore(
        stateFile,
      ).load()).planHistory.single.program.toJson(),
      advancedProgram().toJson(),
    );
  });

  test('기존 운동 계획의 저장 형식은 v3를 유지한다', () async {
    final state = TrainingAppState(activePlan: fixturePlan());
    expect(state.hasAdvancedPrescriptions, isFalse);
    await LocalTrainingStore(stateFile).save(state);
    expect(
      (jsonDecode(await stateFile.readAsString()) as Map)['schemaVersion'],
      3,
    );
    expect(
      (await LocalTrainingStore(stateFile).load()).toJson(),
      state.toJson(),
    );
  });

  test('운동 v1~v3 고급 키와 v4 lifecycle 누락·미래버전은 파일을 보존하며 거부한다', () async {
    for (final version in [1, 2, 3]) {
      final json = deepJson(
        TrainingAppState(activePlan: fixturePlan()).toJson(),
      );
      json['activePlan']['program']['sessions'][0]['exercises'][0]['sets'][0]['isAmrap'] =
          false;
      final bytes = jsonEncode({'schemaVersion': version, 'state': json});
      await stateFile.writeAsString(bytes);
      await expectLater(
        LocalTrainingStore(stateFile).load(),
        throwsA(isA<LocalTrainingStoreException>()),
      );
      expect(await stateFile.readAsString(), bytes);
    }
    for (final field in ['sessionEvents', 'legacySessionIds']) {
      final json = TrainingAppState(activePlan: advancedPlan()).toJson()
        ..remove(field);
      final bytes = jsonEncode({'schemaVersion': 4, 'state': json});
      await stateFile.writeAsString(bytes);
      await expectLater(
        LocalTrainingStore(stateFile).load(),
        throwsA(isA<LocalTrainingStoreException>()),
      );
      expect(await stateFile.readAsString(), bytes);
    }
    final future = jsonEncode({
      'schemaVersion': 5,
      'state': TrainingAppState().toJson(),
    });
    await stateFile.writeAsString(future);
    await expectLater(
      LocalTrainingStore(stateFile).load(),
      throwsA(isA<LocalTrainingStoreException>()),
    );
    expect(await stateFile.readAsString(), future);
  });
}
