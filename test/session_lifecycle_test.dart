import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_insights_fixtures.dart';
import 'training_program_fixtures.dart';

final instant = DateTime.utc(2026, 9, 10, 10);

TrainingAppState resolvedState() {
  final plan = fixturePlan();
  final sets = plan.sessions.first.exercises.single.sets;
  return TrainingAppState()
      .withActivePlan(plan)
      .withSetActual(
        sets[0].id,
        SetActual.completed(
          weight: 0,
          unit: WeightUnit.kg,
          repetitions: 5,
          performedDate: DateTime(2026, 9, 10, 22),
          recordedAt: instant,
        ),
      )
      .withSetActual(sets[1].id, const SetActual.skipped(note: '직접 제외'));
}

Map<String, dynamic> roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  test('수행 달력날짜와 사건 UTC시각을 따로 보존하고 legacy fingerprint는 바꾸지 않는다', () {
    final old = SetActual.completed(
      weight: 20,
      unit: WeightUnit.lb,
      repetitions: 5,
      rir: 0,
      note: '기존',
    );
    expect(
      jsonEncode(old.toJson()),
      '{"status":"completed","weight":20.0,"unit":"lb","repetitions":5,"rir":0.0,"note":"기존"}',
    );
    final restored = SetActual.fromJson(roundTrip(old.toJson()));
    expect(restored.performedDate, isNull);
    expect(restored.recordedAt, isNull);
    expect(restored.updatedAt, isNull);
    final actual = SetActual.completed(
      weight: 20,
      unit: WeightUnit.kg,
      repetitions: 5,
      performedDate: DateTime(2026, 9, 9, 23, 59),
      recordedAt: DateTime.parse('2026-09-10T01:00:00+09:00'),
      updatedAt: instant,
    );
    final decoded = SetActual.fromJson(roundTrip(actual.toJson()));
    expect(decoded.performedDate, DateTime.utc(2026, 9, 9));
    expect(decoded.recordedAt, DateTime.utc(2026, 9, 9, 16));
    expect(decoded.updatedAt, instant);
    expect(
      () => SetActual.completed(
        weight: 20,
        unit: WeightUnit.kg,
        repetitions: 5,
        recordedAt: instant,
        updatedAt: instant.subtract(const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
  });

  test('제외 세트의 날짜와 잘못된 달력일·UTC시각을 거부한다', () {
    for (final field in ['performedDate', 'recordedAt', 'updatedAt']) {
      expect(
        () => SetActual.fromJson({
          ...const SetActual.skipped().toJson(),
          field: null,
        }),
        throwsFormatException,
      );
    }
    final actual = SetActual.completed(
      weight: 10,
      unit: WeightUnit.kg,
      repetitions: 1,
    ).toJson();
    for (final patch in [
      {'performedDate': '2026-02-30'},
      {'recordedAt': '2026-09-10'},
      {'recordedAt': '2026-09-10T12:00:00'},
      {'updatedAt': '2026-09-10T24:00:00Z'},
    ]) {
      expect(
        () => SetActual.fromJson({...actual, ...patch}),
        throwsFormatException,
      );
    }
  });

  test('요약은 확정 수행·0kg·제외·미기록·중첩 초안·미상 날짜를 구분한다', () {
    var state = resolvedState();
    final session = state.activePlan!.sessions.first;
    final sets = session.exercises.single.sets;
    state = state
        .withSetActual(
          sets[2].id,
          SetActual.completed(weight: 30, unit: WeightUnit.lb, repetitions: 8),
        )
        .withSetDraft(sets[0].id, {
          'weight': '42.',
          'performedDate': '2026-09-',
        });
    final summary = state.sessionSummary(session.id);
    expect(summary.toJson(), {
      'totalSets': 3,
      'requiredSets': 2,
      'performedSets': 2,
      'skippedSets': 1,
      'unrecordedSets': 0,
      'draftSets': 1,
      'unknownDateSets': 1,
      'requiredUnrecordedSets': 0,
      'performedDates': ['2026-09-10'],
    });
    expect(summary.canClose, isFalse);
    expect(
      () => state.closeSession(session.id, eventId: 'close', at: instant),
      throwsFormatException,
    );
  });

  test('필수 미기록은 마감할 수 없고 선택 미기록은 그대로 마감한다', () {
    final base = TrainingAppState().withActivePlan(fixturePlan());
    final session = base.activePlan!.sessions.first;
    expect(base.sessionSummary(session.id).requiredUnrecordedSets, 2);
    expect(
      () => base.closeSession(session.id, eventId: 'close', at: instant),
      throwsFormatException,
    );
    final state = resolvedState();
    final closed = state.closeSession(
      session.id,
      eventId: 'close',
      at: instant,
    );
    expect(closed.isSessionClosed(session.id), isTrue);
    expect(closed.sessionSummary(session.id).unrecordedSets, 1);
    expect(closed.setActuals, state.setActuals);
    expect(closed.setDrafts, state.setDrafts);
    expect(closed.activePlan!.toJson(), state.activePlan!.toJson());
    expect(
      closed.sessionEvents.single.summary.toJson(),
      state.sessionSummary(session.id).toJson(),
    );
  });

  test('선택 세트만 있는 세션과 전부 제외한 세션은 수행 0 그대로 명시 마감한다', () {
    final p = fixtureProgram().toJson();
    for (final session in (p['sessions'] as List)) {
      for (final exercise in session['exercises']) {
        for (final set in exercise['sets']) {
          set['isRequired'] = false;
        }
      }
    }
    final source = fixturePlan();
    final plan = createActivePlan(
      id: 'optional',
      program: TrainingProgram.fromJson(roundTrip(p)),
      startDate: source.startDate,
      weekdays: source.weekdays,
      incrementKg: source.incrementKg,
      baselines: source.baselines,
    );
    final blank = TrainingAppState().withActivePlan(plan);
    final session = plan.sessions.first;
    expect(blank.isSessionComplete(session.id), isFalse);
    final closed = blank.closeSession(
      session.id,
      eventId: 'optional-close',
      at: instant,
    );
    expect(closed.sessionEvents.single.summary.performedSets, 0);
    expect(closed.sessionEvents.single.summary.unrecordedSets, 3);
    var skipped = TrainingAppState().withActivePlan(fixturePlan());
    final sid = skipped.activePlan!.sessions.first.id;
    for (final set
        in skipped.activePlan!.sessions.first.exercises.single.sets) {
      skipped = skipped.withSetActual(set.id, const SetActual.skipped());
    }
    final finished = skipped.closeSession(
      sid,
      eventId: 'skipped-close',
      at: instant,
    );
    expect(finished.sessionEvents.single.summary.performedSets, 0);
    expect(finished.sessionEvents.single.summary.skippedSets, 3);
  });

  test('마감하면 기록·초안·메모 수정을 막고 재개 후 수정해도 마감 스냅샷은 보존한다', () {
    final base = resolvedState();
    final session = base.activePlan!.sessions.first;
    final setId = session.exercises.single.sets.first.id;
    final closed = base.closeSession(session.id, eventId: 'close', at: instant);
    expect(() => closed.withSetActual(setId, null), throwsFormatException);
    expect(() => closed.withSetDraft(setId, {}), throwsFormatException);
    expect(() => closed.withSetDraft(setId, null), throwsFormatException);
    expect(
      () => closed.withSessionNote(session.id, '수정'),
      throwsFormatException,
    );
    final opened = closed.reopenSession(
      session.id,
      eventId: 'open',
      at: instant,
    );
    final edited = opened
        .withSetActual(setId, null)
        .withSessionNote(session.id, '재개 후 수정');
    expect(edited.isSessionClosed(session.id), isFalse);
    expect(edited.sessionSummary(session.id).performedSets, 0);
    expect(edited.sessionEvents.first.summary.performedSets, 1);
    expect(
      opened.sessionEvents[1].summary.toJson(),
      closed.sessionEvents.first.summary.toJson(),
    );
    expect(
      TrainingAppState.fromJson(roundTrip(edited.toJson())).toJson(),
      edited.toJson(),
    );
  });

  test('같은 명령 ID 재시도는 중복되지 않고 충돌·순서 역행을 거부한다', () {
    final base = resolvedState();
    final sid = base.activePlan!.sessions.first.id;
    final closed = base.closeSession(sid, eventId: 'one', at: instant);
    expect(
      identical(closed.closeSession(sid, eventId: 'one', at: instant), closed),
      isTrue,
    );
    expect(
      () => closed.closeSession(sid, eventId: 'two', at: instant),
      throwsFormatException,
    );
    expect(
      () => closed.reopenSession(sid, eventId: 'one', at: instant),
      throwsFormatException,
    );
    expect(
      () => closed.closeSession(
        sid,
        eventId: 'one',
        at: instant.add(const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
    expect(
      () => closed.reopenSession(
        sid,
        eventId: 'two',
        at: instant.subtract(const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
    expect(
      () => base.reopenSession(sid, eventId: 'two', at: instant),
      throwsFormatException,
    );
    final reopened = closed.reopenSession(sid, eventId: 'two', at: instant);
    expect(
      identical(
        reopened.closeSession(sid, eventId: 'one', at: instant),
        reopened,
      ),
      isTrue,
    );
    expect(reopened.sessionEvents, hasLength(2));
  });

  test('이벤트·legacy 상태를 모든 일반 복사·계획 교체 경로에서 보존한다', () {
    final base = resolvedState();
    final sid = base.activePlan!.sessions.first.id;
    final legacy = TrainingAppState.fromJson(
      roundTrip(base.toJson())
        ..remove('sessionEvents')
        ..remove('legacySessionIds'),
    );
    var state = legacy
        .closeSession(sid, eventId: 'close', at: instant)
        .reopenSession(sid, eventId: 'open', at: instant);
    final events = state.sessionEvents.map((e) => e.toJson()).toList();
    final setId =
        state.activePlan!.sessions.first.exercises.single.sets.last.id;
    state = state
        .copyWith(onboarded: true)
        .withSetDraft(setId, {'weight': '.'})
        .withSetActual(setId, const SetActual.skipped())
        .withSessionNote(sid, '메모')
        .withCompletionNotified(sid)
        .withActivePlan(fixturePlan(id: 'next'));
    expect(state.sessionEvents.map((e) => e.toJson()).toList(), events);
    expect(state.legacySessionIds, {sid});
    expect(
      () => state.closeSession(sid, eventId: 'archive', at: instant),
      throwsFormatException,
    );
  });

  test('손상된 이벤트 순서·고아·중복·요약 개수·마감 후 초안을 복원하지 않는다', () {
    final base = resolvedState();
    final sid = base.activePlan!.sessions.first.id;
    final closed = base.closeSession(sid, eventId: 'close', at: instant);
    final valid = roundTrip(closed.toJson());
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['sessionEvents'][0]['sessionId'] = 'missing',
      (j) => j['sessionEvents'].add(j['sessionEvents'][0]),
      (j) => j['sessionEvents'][0]['kind'] = 'reopened',
      (j) => j['sessionEvents'][0]['kind'] = 'unknown',
      (j) => j['sessionEvents'][0]['summary']['performedSets'] = -1,
      (j) => j['sessionEvents'][0]['summary']['totalSets'] = 4,
      (j) => j['sessionEvents'][0]['summary']['performedDates'] = [
        '2026-09-10',
        '2026-09-10',
      ],
      (j) => j['legacySessionIds'] = ['missing'],
      (j) =>
          j['setDrafts'][base
                  .activePlan!
                  .sessions
                  .first
                  .exercises
                  .single
                  .sets
                  .last
                  .id] =
              {},
      (j) => j.remove('sessionEvents'),
    ]) {
      final corrupt = roundTrip(valid);
      mutate(corrupt);
      expect(() => TrainingAppState.fromJson(corrupt), throwsFormatException);
    }
  });

  test('기존 v1/v2는 기록 있는 세션만 미상 이행하고 v3 파일로 날짜·마감을 왕복한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'strength-lifecycle-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final plan = fixturePlan();
    final sessions = plan.sessions;
    final original = TrainingAppState()
        .withActivePlan(plan)
        .withSetActual(
          sessions[0].exercises.single.sets.first.id,
          SetActual.completed(weight: 20, unit: WeightUnit.kg, repetitions: 5),
        )
        .withSetDraft(sessions[1].exercises.single.sets.first.id, {
          'weight': '42.',
        })
        .withSessionNote(sessions[2].id, '기존 메모');
    for (final version in [1, 2]) {
      final json = original.toJson()
        ..remove('sessionEvents')
        ..remove('legacySessionIds');
      if (version == 1) json.remove('loadAdjustments');
      await file.writeAsString(
        jsonEncode({'schemaVersion': version, 'state': json}),
      );
      final state = await LocalTrainingStore(file).load();
      expect(state.legacySessionIds, sessions.take(3).map((s) => s.id).toSet());
      expect(state.sessionEvents, isEmpty);
      expect(state.setActuals.values.single.performedDate, isNull);
      expect(state.setActuals.values.single.recordedAt, isNull);
      expect(state.activePlan!.toJson(), original.activePlan!.toJson());
      await LocalTrainingStore(file).save(state);
      expect(
        (jsonDecode(await file.readAsString()) as Map)['schemaVersion'],
        3,
      );
      expect((await LocalTrainingStore(file).load()).toJson(), state.toJson());
    }
    final resolved = resolvedState();
    final closed = resolved.closeSession(
      resolved.activePlan!.sessions.first.id,
      eventId: 'close',
      at: instant,
    );
    await LocalTrainingStore(file).save(closed);
    expect((await LocalTrainingStore(file).load()).toJson(), closed.toJson());
  });

  test('v3 신규 필드 누락과 미래 스키마는 원본을 유지하고 거부한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'strength-lifecycle-corrupt-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    for (final fields in [
      [],
      ['sessionEvents'],
      ['legacySessionIds'],
      ['sessionEvents', 'legacySessionIds'],
    ]) {
      final json = TrainingAppState().toJson();
      for (final field in fields) {
        json.remove(field);
      }
      final text = jsonEncode({
        'schemaVersion': fields.isEmpty ? 7 : 3,
        'state': json,
      });
      await file.writeAsString(text);
      await expectLater(
        LocalTrainingStore(file).load(),
        throwsA(isA<LocalTrainingStoreException>()),
      );
      expect(await file.readAsString(), text);
    }
  });

  test('기존 D5 근거 fingerprint와 적용·되돌리기는 마감 이행 뒤에도 보존한다', () {
    final base = insightsState();
    final suggestion = buildTrainingInsights(
      base,
      planId: base.activePlan!.id,
      asOf: insightsToday,
    ).first.suggestion!;
    final json = base.toJson()
      ..remove('sessionEvents')
      ..remove('legacySessionIds');
    final migrated = TrainingAppState.fromJson(roundTrip(json));
    final sid = migrated.activePlan!.sessions.first.id;
    final closed = migrated.closeSession(
      sid,
      eventId: 'close',
      at: DateTime.utc(2026, 8, 10),
    );
    final adjustment = suggestion;
    final adjusted = closed.withLoadAdjustment(adjustment, asOf: insightsToday);
    expect(
      adjusted.setActuals.map((id, a) => MapEntry(id, jsonEncode(a.toJson()))),
      base.setActuals.map((id, a) => MapEntry(id, jsonEncode(a.toJson()))),
    );
    expect(
      adjusted.sessionEvents.map((e) => e.toJson()),
      closed.sessionEvents.map((e) => e.toJson()),
    );
    expect(adjusted.legacySessionIds, migrated.legacySessionIds);
    final undone = adjusted.undoLoadAdjustment(
      adjustment.id,
      asOf: insightsToday,
    );
    expect(
      undone.sessionEvents.map((e) => e.toJson()),
      closed.sessionEvents.map((e) => e.toJson()),
    );
    expect(undone.legacySessionIds, migrated.legacySessionIds);
    expect(undone.activePlan!.toJson(), base.activePlan!.toJson());
  });

  test('재개 후 수행일을 수정하고 재마감해도 이전 요약과 세 사건을 파일에서 복원한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'strength-reclose-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final original = resolvedState();
    final session = original.activePlan!.sessions.first;
    final setId = session.exercises.single.sets.first.id;
    final first = original.closeSession(
      session.id,
      eventId: 'first-close',
      at: instant,
    );
    final firstSnapshot = first.sessionEvents.single.summary.toJson();
    final reopened = first.reopenSession(
      session.id,
      eventId: 'reopen',
      at: instant.add(const Duration(minutes: 1)),
    );
    final edited = reopened
        .withSetActual(
          setId,
          SetActual.completed(
            weight: 25,
            unit: WeightUnit.kg,
            repetitions: 5,
            performedDate: DateTime.utc(2026, 9, 9),
            recordedAt: original.setActuals[setId]!.recordedAt,
            updatedAt: instant.add(const Duration(minutes: 2)),
          ),
        )
        .withSessionNote(session.id, '실제 수행 날짜를 정정한 뒤 재마감');
    final finalState = edited.closeSession(
      session.id,
      eventId: 'second-close',
      at: instant.add(const Duration(minutes: 3)),
    );
    expect(finalState.sessionEvents.map((event) => event.kind), [
      SessionLifecycleKind.closed,
      SessionLifecycleKind.reopened,
      SessionLifecycleKind.closed,
    ]);
    expect(finalState.sessionEvents[0].summary.toJson(), firstSnapshot);
    expect(finalState.sessionEvents[1].summary.toJson(), firstSnapshot);
    expect(finalState.sessionEvents[0].summary.performedDates, [
      DateTime.utc(2026, 9, 10),
    ]);
    expect(finalState.sessionEvents[2].summary.performedDates, [
      DateTime.utc(2026, 9, 9),
    ]);
    expect(
      finalState.sessionEvents[2].summary.toJson(),
      edited.sessionSummary(session.id).toJson(),
    );
    expect(finalState.activePlan!.toJson(), original.activePlan!.toJson());
    expect(finalState.isSessionClosed(session.id), isTrue);
    await LocalTrainingStore(file).save(finalState);
    final restored = await LocalTrainingStore(file).load();
    expect(restored.toJson(), finalState.toJson());
    expect(restored.setActuals[setId]!.weight, 25);
    expect(restored.sessionEvents.first.summary.toJson(), firstSnapshot);
    expect(() => restored.withSetDraft(setId, {}), throwsFormatException);
  });

  test('수행 메타데이터만 변경해도 과거 미적용 D5 근거를 재사용하지 않는다', () {
    final state = insightsState();
    final proposal = buildTrainingInsights(
      state,
      planId: state.activePlan!.id,
      asOf: insightsToday,
    ).first.suggestion!;
    final setId =
        state.activePlan!.sessions.first.exercises.single.sets.first.id;
    final previous = state.setActuals[setId]!;
    final original = state.toJson();
    for (final field in ['performedDate', 'recordedAt', 'updatedAt']) {
      final edited = SetActual.completed(
        weight: previous.weight!,
        unit: previous.unit!,
        repetitions: previous.repetitions!,
        rir: previous.rir,
        note: previous.note,
        performedDate: field == 'performedDate'
            ? DateTime.utc(2026, 8, 4)
            : null,
        recordedAt: field == 'recordedAt' ? DateTime.utc(2026, 8, 4, 12) : null,
        updatedAt: field == 'updatedAt' ? DateTime.utc(2026, 8, 4, 13) : null,
      );
      final withoutMetadata = edited.toJson()..remove(field);
      expect(withoutMetadata, previous.toJson());
      final changed = state.withSetActual(setId, edited);
      expect(
        () => changed.withLoadAdjustment(proposal, asOf: insightsToday),
        throwsFormatException,
        reason: '$field 변경 후 옛 근거 적용 차단',
      );
      expect(changed.loadAdjustments, isEmpty);
      expect(changed.activePlan!.toJson(), state.activePlan!.toJson());
    }
    expect(state.toJson(), original);
  });

  test('적용 및 되돌린 D5 이력이 있는 v2 파일을 v3로 이행해 원본 목표와 근거를 보존한다', () async {
    final directory = await Directory.systemTemp.createTemp('strength-v2-d5-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final base = insightsState();
    final proposal = buildTrainingInsights(
      base,
      planId: base.activePlan!.id,
      asOf: insightsToday,
    ).first.suggestion!;
    final applied = base.withLoadAdjustment(proposal, asOf: insightsToday);
    final undone = applied.undoLoadAdjustment(proposal.id, asOf: insightsToday);
    for (final original in [applied, undone]) {
      final oldJson = original.toJson()
        ..remove('sessionEvents')
        ..remove('legacySessionIds');
      final oldBytes = jsonEncode({'schemaVersion': 2, 'state': oldJson});
      await file.writeAsString(oldBytes);
      final restored = await LocalTrainingStore(file).load();
      expect(await file.readAsString(), oldBytes);
      final comparable = restored.toJson()
        ..remove('sessionEvents')
        ..remove('legacySessionIds');
      expect(comparable, oldJson);
      expect(
        restored.loadAdjustments.single.toJson(),
        original.loadAdjustments.single.toJson(),
      );
      expect(restored.sessionEvents, isEmpty);
      expect(
        restored.legacySessionIds,
        base.activePlan!.sessions.take(3).map((s) => s.id).toSet(),
      );
      expect(
        restored.setActuals.values.every(
          (a) =>
              a.performedDate == null &&
              a.recordedAt == null &&
              a.updatedAt == null,
        ),
        isTrue,
      );
      for (final set
          in restored.activePlan!.sessions
              .expand((s) => s.exercises)
              .expand((e) => e.sets)) {
        expect(
          restored.effectiveTargetKg(set),
          original.effectiveTargetKg(set),
        );
      }
      await LocalTrainingStore(file).save(restored);
      expect(
        (jsonDecode(await file.readAsString()) as Map)['schemaVersion'],
        3,
      );
      final reloaded = await LocalTrainingStore(file).load();
      expect(reloaded.toJson(), restored.toJson());
      if (!original.loadAdjustments.single.isUndone) {
        expect(
          reloaded
              .undoLoadAdjustment(proposal.id, asOf: insightsToday)
              .loadAdjustments
              .single
              .toJson(),
          undone.loadAdjustments.single.toJson(),
        );
      } else {
        expect(
          () => reloaded.undoLoadAdjustment(proposal.id, asOf: insightsToday),
          throwsFormatException,
        );
      }
    }
  });
}
