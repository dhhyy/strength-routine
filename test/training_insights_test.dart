import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'training_insights_fixtures.dart';

ExerciseTrend trend(TrainingAppState state, {DateTime? today}) =>
    buildTrainingInsights(
      state,
      planId: state.activePlan!.id,
      asOf: today ?? insightsToday,
    ).first;

void main() {
  test('계획일별 실제 중량·반복·RIR은 kg로 비교하고 0·누락·초안을 구분한다', () {
    var state = insightsState();
    final sets = state.activePlan!.sessions.first.exercises.single.sets;
    state = state.withSetActual(
      sets.first.id,
      SetActual.completed(
        weight: 100 / 0.45359237,
        unit: WeightUnit.lb,
        repetitions: 5,
        rir: 0,
      ),
    );
    state = state.withSetActual(
      sets[1].id,
      SetActual.completed(weight: 0, unit: WeightUnit.kg, repetitions: 7),
    );
    final point = trend(state).points.first;
    expect(point.plannedDate, DateTime.utc(2026, 8, 3));
    expect(point.maxWeightKg, closeTo(100, 0.000001));
    expect(point.performedSets, 2);
    expect(point.repetitions, 12);
    expect(point.averageRir, 0);
    expect(point.rirCount, 1);
    expect(point.comparableRirGap, isNull);
    state = state.withSetDraft(sets.first.id, {'weight': '42.'});
    final draft = trend(state).points.first;
    expect(draft.draftSets, 1);
    expect(draft.performedSets, 1);
    expect(draft.maxWeightKg, 0);
    expect(draft.averageRir, isNull);
  });

  test('최근 3회 평균 RIR 차이로 최대 5%만 제안하고 원본은 바꾸지 않는다', () {
    final state = insightsState();
    final before = state.toJson();
    final suggestion = trend(state).suggestion!;
    expect(suggestion.evidenceSessionIds.length, 3);
    expect(suggestion.evidenceRirGaps, [1, 1, 1]);
    expect(suggestion.beforeKg.values.toSet(), {100});
    expect(suggestion.afterKg.values.toSet(), {95});
    expect(suggestion.afterKg.length, 6);
    expect(state.toJson(), before);
    final coarse = insightsState(plan: insightsPlan(target: 27.5));
    expect(trend(coarse).suggestion, isNull); // 한 틱이면 5% 초과: 감량하지 않는다.
  });

  test('누락 RIR·제외·초안·다른 반복 수·한 번 정상 기록은 연속 신호를 끊는다', () {
    final base = insightsState();
    final set = base.activePlan!.sessions[1].exercises.single.sets.first;
    final variants = [
      base.withSetActual(
        set.id,
        SetActual.completed(weight: 100, unit: WeightUnit.kg, repetitions: 5),
      ),
      base.withSetActual(set.id, const SetActual.skipped()),
      base.withSetDraft(set.id, {'rir': '-'}),
      base.withSetActual(
        set.id,
        SetActual.completed(
          weight: 100,
          unit: WeightUnit.kg,
          repetitions: 6,
          rir: 1,
        ),
      ),
      base.withSetActual(
        set.id,
        SetActual.completed(
          weight: 100,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 3,
        ),
      ),
    ];
    for (final state in variants) {
      expect(trend(state).suggestion, isNull);
    }
    expect(trend(base, today: DateTime.utc(2026, 8, 24)).suggestion, isNull);
    expect(trend(insightsState(completedSessions: 2)).suggestion, isNull);
  });

  test('같은 이름의 이전 계획이나 다른 운동 구성을 합쳐 제안하지 않는다', () {
    final old = insightsState();
    final current = old.withActivePlan(insightsPlan(id: 'another-plan'));
    expect(trend(current).suggestion, isNull);
    final archived = buildTrainingInsights(
      current,
      planId: old.activePlan!.id,
      asOf: insightsToday,
    ).single;
    expect(archived.points.first.performedSets, 2);
    expect(archived.suggestion, isNull);
    final renamed = insightsState(plan: insightsPlan(renameThird: true));
    expect(
      buildTrainingInsights(
        renamed,
        planId: renamed.activePlan!.id,
        asOf: insightsToday,
      ).every((t) => t.suggestion == null),
      isTrue,
    );
  });

  test('적용은 미래 미기록 kg만 바꾸고 모든 상태 갱신에서 이력을 보존한다', () {
    final original = insightsState();
    final plan = original.activePlan!;
    final future = plan.sessions[3].exercises.single.sets.first;
    final manual = plan.sessions[3].exercises.single.sets.last;
    final proposal = trend(original).suggestion!;
    var applied = original.withLoadAdjustment(proposal, asOf: insightsToday);
    expect(applied.activePlan!.toJson(), plan.toJson());
    expect(applied.setActuals, original.setActuals);
    expect(future.targetKg, 100);
    expect(applied.effectiveTargetKg(future), 95);
    expect(applied.effectiveTargetKg(manual), isNull);
    expect(trend(applied).suggestion, isNull);
    expect(
      () => applied.withLoadAdjustment(proposal, asOf: insightsToday),
      throwsFormatException,
    );
    final renamedId = TargetLoadAdjustment.fromJson({
      ...proposal.toJson(),
      'id': 'different-id',
    });
    expect(
      () => applied.withLoadAdjustment(renamedId, asOf: insightsToday),
      throwsFormatException,
    );
    applied = applied
        .copyWith(onboarded: true)
        .withSetDraft(manual.id, {'weight': '42.'})
        .withSetDraft(manual.id, null)
        .withSessionNote(plan.sessions.first.id, '메모')
        .withCompletionNotified(plan.sessions.first.id)
        .withSetActual(manual.id, const SetActual.skipped())
        .withSetActual(manual.id, null);
    expect(applied.loadAdjustments.single.toJson(), proposal.toJson());
    expect(
      applied.withActivePlan(insightsPlan(id: 'next')).loadAdjustments.length,
      1,
    );
    expect(() => applied.loadAdjustments.clear(), throwsUnsupportedError);
    expect(() => proposal.afterKg.clear(), throwsUnsupportedError);
  });

  test('제안 이후 기록·대상 초안·날짜·활성 계획 변경은 오래된 적용을 차단한다', () {
    final state = insightsState();
    final proposal = trend(state).suggestion!;
    final evidence =
        state.activePlan!.sessions.first.exercises.single.sets.first;
    final future = state.activePlan!.sessions[3].exercises.single.sets.first;
    expect(
      () => state
          .withSetActual(
            evidence.id,
            SetActual.completed(
              weight: 100,
              unit: WeightUnit.kg,
              repetitions: 5,
              rir: 0,
            ),
          )
          .withLoadAdjustment(proposal, asOf: insightsToday),
      throwsFormatException,
    );
    expect(
      () => state
          .withSetDraft(future.id, {})
          .withLoadAdjustment(proposal, asOf: insightsToday),
      throwsFormatException,
    );
    expect(
      () => state.withLoadAdjustment(proposal, asOf: DateTime.utc(2026, 8, 24)),
      throwsFormatException,
    );
    expect(
      () => state
          .withActivePlan(insightsPlan(id: 'new'))
          .withLoadAdjustment(proposal, asOf: insightsToday),
      throwsFormatException,
    );
  });

  test('제안 대상은 미래의 실제값·초안·수동 중량을 건너뛴다', () {
    var state = insightsState();
    final sets = state.activePlan!.sessions[3].exercises.single.sets;
    state = state
        .withSetActual(sets.first.id, const SetActual.skipped())
        .withSetDraft(sets[1].id, {'weight': '42.'});
    final proposal = trend(state).suggestion!;
    expect(proposal.afterKg.length, 4);
    expect(proposal.afterKg.keys, isNot(contains(sets.first.id)));
    expect(proposal.afterKg.keys, isNot(contains(sets[1].id)));
    expect(proposal.afterKg.keys, isNot(contains(sets.last.id)));
  });

  test('영구 되돌리기는 원래 목표를 복원하고 같은 근거의 재적용을 막는다', () {
    final initial = insightsState();
    final proposal = trend(initial).suggestion!;
    final applied = initial.withLoadAdjustment(proposal, asOf: insightsToday);
    final undone = applied.undoLoadAdjustment(proposal.id, asOf: insightsToday);
    final restored = TrainingAppState.fromJson(
      jsonDecode(jsonEncode(undone.toJson())),
    );
    expect(restored.loadAdjustments.single.isUndone, isTrue);
    final future = restored.activePlan!.sessions[3].exercises.single.sets.first;
    expect(restored.effectiveTargetKg(future), 100);
    expect(restored.activePlan!.toJson(), initial.activePlan!.toJson());
    expect(restored.setActuals.keys, initial.setActuals.keys);
    expect(trend(restored).suggestion, isNull);
    expect(
      () => restored.undoLoadAdjustment(proposal.id, asOf: insightsToday),
      throwsFormatException,
    );
    expect(
      () => restored.withLoadAdjustment(proposal, asOf: insightsToday),
      throwsFormatException,
    );
  });

  test('조정 대상에 실제값·초안이 생기거나 오늘이 되면 전체 되돌리기를 막는다', () {
    final initial = insightsState();
    final proposal = trend(initial).suggestion!;
    final applied = initial.withLoadAdjustment(proposal, asOf: insightsToday);
    final future = applied.activePlan!.sessions[3].exercises.single.sets.first;
    for (final changed in [
      applied.withSetActual(
        future.id,
        SetActual.completed(weight: 95, unit: WeightUnit.kg, repetitions: 5),
      ),
      applied.withSetActual(future.id, const SetActual.skipped()),
      applied.withSetDraft(future.id, {'weight': '95'}),
    ]) {
      expect(
        () => changed.undoLoadAdjustment(proposal.id, asOf: insightsToday),
        throwsFormatException,
      );
    }
    expect(
      () => applied.undoLoadAdjustment(
        proposal.id,
        asOf: DateTime.utc(2026, 8, 24),
      ),
      throwsFormatException,
    );
  });

  test('기존 v1 상태를 읽고 새 이력의 중복·고아·변조 목표를 거부한다', () {
    final initial = insightsState();
    final oldJson = initial.toJson()..remove('loadAdjustments');
    expect(TrainingAppState.fromJson(oldJson).loadAdjustments, isEmpty);
    final proposal = trend(initial).suggestion!;
    final applied = initial.withLoadAdjustment(proposal, asOf: insightsToday);
    expect(
      () => TrainingAppState.fromJson({
        ...applied.toJson(),
        'loadAdjustments': [proposal.toJson(), proposal.toJson()],
      }),
      throwsFormatException,
    );
    final broken = proposal.toJson()..['planId'] = 'missing';
    expect(
      () => TrainingAppState.fromJson({
        ...applied.toJson(),
        'loadAdjustments': [broken],
      }),
      throwsFormatException,
    );
    final changed = proposal.toJson()
      ..['beforeKg'] = {for (final id in proposal.beforeKg.keys) id: 200.0};
    expect(
      () => TrainingAppState.fromJson({
        ...applied.toJson(),
        'loadAdjustments': [changed],
      }),
      throwsFormatException,
    );
  });

  test('적용과 되돌린 이력은 실제 파일의 새 저장소에서 복원된다', () async {
    final directory = await Directory.systemTemp.createTemp('insights-store-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final state = insightsState();
    final proposal = trend(state).suggestion!;
    final applied = state.withLoadAdjustment(proposal, asOf: insightsToday);
    await LocalTrainingStore(file).save(applied);
    final restored = await LocalTrainingStore(file).load();
    expect(restored.toJson(), applied.toJson());
    final undone = restored.undoLoadAdjustment(
      proposal.id,
      asOf: insightsToday,
    );
    await LocalTrainingStore(file).save(undone);
    expect((await LocalTrainingStore(file).load()).toJson(), undone.toJson());
  });
}
