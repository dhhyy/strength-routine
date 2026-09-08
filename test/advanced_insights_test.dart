import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'advanced_prescription_test.dart' show deepJson;
import 'training_insights_fixtures.dart';

ActiveTrainingPlan _plan({
  bool allAmrap = false,
  bool futureOnlyAmrap = false,
}) {
  final json = deepJson(insightsPlan().program.toJson());
  for (var index = 0; index < (json['sessions'] as List).length; index++) {
    final sets = json['sessions'][index]['exercises'][0]['sets'] as List;
    sets[0]['isAmrap'] = allAmrap || futureOnlyAmrap && index >= 3;
    sets[1]['isAmrap'] = true;
    for (final set in sets) {
      set['restSeconds'] = 90;
      set['tempo'] = '3-1-X-0';
    }
  }
  return createActivePlan(
    id: 'advanced-d5',
    program: TrainingProgram.fromJson(json),
    startDate: DateTime.utc(2026, 8, 3),
    weekdays: [1],
    incrementKg: 2.5,
  );
}

TrainingAppState _recorded({
  ActiveTrainingPlan? plan,
  int amrapRepetitions = 11,
  double? amrapRir = 0,
  double fixedRir = 1,
}) {
  final active = plan ?? _plan();
  var state = TrainingAppState(activePlan: active);
  for (final session in active.sessions.take(3)) {
    for (final set in session.exercises.single.sets.where(
      (set) => set.isRequired,
    )) {
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: set.isAmrap ? 120 : 100,
          unit: WeightUnit.kg,
          repetitions: set.isAmrap ? amrapRepetitions : 5,
          rir: set.isAmrap ? amrapRir : fixedRir,
          performedDate: session.date,
        ),
      );
    }
  }
  return state;
}

ExerciseTrend _trend(TrainingAppState state) => buildTrainingInsights(
  state,
  planId: state.activePlan!.id,
  asOf: insightsToday,
).single;

void main() {
  test('AMRAP 실제 세트·반복·최대 중량·평균 RIR은 추세 통계에 포함한다', () {
    final trend = _trend(_recorded());
    expect(trend.points, hasLength(3));
    for (final point in trend.points) {
      expect(point.performedSets, 2);
      expect(point.repetitions, 16);
      expect(point.maxWeightKg, 120);
      expect(point.averageRir, .5);
      expect(point.rirCount, 2);
      // Fixed set: target RIR 2 minus actual RIR 1. AMRAP is not averaged here.
      expect(point.comparableRirGap, 1);
    }
  });

  test('모든 필수 세트가 AMRAP이면 기준 반복과 실제가 같아도 D5 근거가 없다', () {
    final state = _recorded(plan: _plan(allAmrap: true), amrapRepetitions: 5);
    final trend = _trend(state);
    expect(
      trend.points.every(
        (point) => point.performedSets == 2 && point.repetitions == 10,
      ),
      isTrue,
    );
    expect(
      trend.points.every((point) => point.comparableRirGap == null),
      isTrue,
    );
    expect(trend.suggestion, isNull);
  });

  test('AMRAP만 힘들었던 혼합 기록은 고정 반복 세트가 정상이면 D5를 제안하지 않는다', () {
    final state = _recorded(amrapRepetitions: 5, amrapRir: 0, fixedRir: 2);
    final trend = _trend(state);
    expect(trend.points.every((point) => point.averageRir == 1), isTrue);
    expect(trend.points.every((point) => point.comparableRirGap == 0), isTrue);
    expect(trend.suggestion, isNull);
  });

  test('AMRAP 반복·RIR은 혼합 D5 수치 근거가 아니며 미래 AMRAP 목표는 제외한다', () {
    for (final amrapRir in <double?>[null, 0, 10]) {
      final state = _recorded(amrapRepetitions: 14, amrapRir: amrapRir);
      final suggestion = _trend(state).suggestion!;
      expect(suggestion.evidenceRirGaps, [1, 1, 1]);
      final future = state.activePlan!.sessions
          .skip(3)
          .expand((session) => session.exercises.single.sets);
      final fixedIds = future
          .where((set) => !set.isAmrap && set.targetKg != null)
          .map((set) => set.id)
          .toSet();
      final amrapIds = future
          .where((set) => set.isAmrap)
          .map((set) => set.id)
          .toSet();
      expect(suggestion.beforeKg.keys.toSet(), fixedIds);
      expect(suggestion.afterKg.keys.toSet(), fixedIds);
      expect(suggestion.afterKg.keys.any(amrapIds.contains), isFalse);
      expect(suggestion.afterKg.values.toSet(), {95});
      // All required records are frozen to reject a stale proposal after editing.
      expect(suggestion.evidenceRecords, hasLength(6));
    }
  });

  test('필수 AMRAP의 누락·초안·제외는 세션 완료 조건을 충족하지 않는다', () {
    final state = _recorded();
    final amrap = state.activePlan!.sessions[1].exercises.single.sets[1];
    for (final changed in [
      state.withSetActual(amrap.id, null),
      state.withSetDraft(amrap.id, {'repetitions': '14.'}),
      state.withSetActual(amrap.id, const SetActual.skipped()),
    ]) {
      expect(_trend(changed).points[1].comparableRirGap, isNull);
      expect(_trend(changed).suggestion, isNull);
    }
  });

  test('미래 처방이 AMRAP뿐이면 과거의 고정 반복 근거가 있어도 감량하지 않는다', () {
    final trend = _trend(_recorded(plan: _plan(futureOnlyAmrap: true)));
    expect(trend.points.map((point) => point.comparableRirGap), [1, 1, 1]);
    expect(trend.suggestion, isNull);
  });

  test('D5 적용·복원·되돌리기 후에도 AMRAP 목표와 처방·실제 기록을 보존한다', () {
    final original = _recorded();
    final suggestion = _trend(original).suggestion!;
    final future = original.activePlan!.sessions[3].exercises.single.sets;
    final applied = original.withLoadAdjustment(
      suggestion,
      asOf: insightsToday,
    );
    expect(applied.effectiveTargetKg(future.first), 95);
    expect(applied.effectiveTargetKg(future[1]), 100);
    expect(applied.activePlan!.toJson(), original.activePlan!.toJson());
    final restored = TrainingAppState.fromJson(deepJson(applied.toJson()));
    final undone = restored.undoLoadAdjustment(
      suggestion.id,
      asOf: insightsToday,
    );
    final reopened = TrainingAppState.fromJson(deepJson(undone.toJson()));
    expect(reopened.effectiveTargetKg(future.first), 100);
    expect(reopened.effectiveTargetKg(future[1]), 100);
    expect(
      reopened.activePlan!.program.toJson(),
      original.activePlan!.program.toJson(),
    );
    expect(reopened.loadAdjustments.single.isUndone, isTrue);
    expect(
      jsonEncode(
        reopened.setActuals.map((key, value) => MapEntry(key, value.toJson())),
      ),
      jsonEncode(
        original.setActuals.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
    expect(_trend(reopened).suggestion, isNull);
  });

  test('제안 뒤 필수 AMRAP 실제 기록이 바뀌면 오래된 D5 적용을 막는다', () {
    final original = _recorded();
    final suggestion = _trend(original).suggestion!;
    final amrap = original.activePlan!.sessions.first.exercises.single.sets[1];
    final changed = original.withSetActual(
      amrap.id,
      SetActual.completed(
        weight: 120,
        unit: WeightUnit.kg,
        repetitions: 12,
        rir: 0,
      ),
    );
    expect(
      () => changed.withLoadAdjustment(suggestion, asOf: insightsToday),
      throwsFormatException,
    );
  });
}
