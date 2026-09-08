import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/previous_record.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'schedule_previous_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20);
  final plan = scheduleFixture();
  final target = plan.sessions.last.exercises.first.sets.first.id;
  final source = plan.sessions.first.exercises.first.sets.first.id;
  SetActual actual({DateTime? date, WeightUnit unit = WeightUnit.kg}) =>
      SetActual.completed(
        weight: 22.5,
        unit: unit,
        repetitions: 7,
        performedDate: date,
      );
  List<PreviousSetRecord> candidates(
    TrainingAppState state, {
    DateTime? before,
  }) => previousSetRecords(
    state,
    targetSetId: target,
    performedBefore: before ?? now,
    asOf: now,
  );
  test('original kg/lb and only weight, unit and reps copy into raw draft', () {
    for (final unit in WeightUnit.values) {
      final state = TrainingAppState(
        activePlan: plan,
        setActuals: {
          source: actual(date: DateTime.utc(2026, 9, 7), unit: unit),
        },
      );
      final record = candidates(state).single;
      final draft = {
        'weight': '0',
        'unit': 'kg',
        'repetitions': '1',
        'rir': ' 2.5 ',
        'note': '현재 메모 ',
        'performedDate': '2026-09-20',
      };
      expect(record.copyInto(draft), {
        ...draft,
        'weight': '22.5',
        'unit': unit.key,
        'repetitions': '7',
      });
      expect(record.actual, state.setActuals[source]);
    }
  });
  test('sort by performed date instead of scheduled date', () {
    final source2 = plan.sessions[1].exercises.first.sets.first.id;
    final state = TrainingAppState(
      activePlan: plan,
      setActuals: {
        source: actual(date: DateTime.utc(2026, 9, 18)),
        source2: actual(date: DateTime.utc(2026, 9, 12)),
      },
    );
    expect(candidates(state).map((r) => r.setId), [source, source2]);
  });
  test('unknown, same/future day, excluded and draft sources are absent', () {
    for (final entry in [
      actual(),
      actual(date: now),
      actual(date: now.add(const Duration(days: 1))),
      const SetActual.skipped(),
    ]) {
      expect(
        candidates(
          TrainingAppState(activePlan: plan, setActuals: {source: entry}),
        ),
        isEmpty,
      );
    }
    expect(
      candidates(
        TrainingAppState(
          activePlan: plan,
          setActuals: {source: actual(date: DateTime.utc(2026, 9, 7))},
          setDrafts: {
            source: {'weight': 'unfinished'},
          },
        ),
      ),
      isEmpty,
    );
  });
  test('unknown current performed date does not infer date order', () {
    final state = TrainingAppState(
      activePlan: plan,
      setActuals: {source: actual(date: DateTime.utc(2026, 9, 7))},
    );
    expect(
      previousSetRecords(
        state,
        targetSetId: target,
        performedBefore: null,
        asOf: now,
      ),
      isEmpty,
    );
  });
  test('different program or version with same display name is not merged', () {
    for (final history in [
      scheduleFixture(id: 'old', programId: 'other'),
      scheduleFixture(id: 'old', version: '2'),
    ]) {
      final oldSet = history.sessions.first.exercises.first.sets.first.id;
      expect(
        candidates(
          TrainingAppState(
            activePlan: plan,
            planHistory: [history],
            setActuals: {oldSet: actual(date: DateTime.utc(2026, 9, 7))},
          ),
        ),
        isEmpty,
      );
    }
  });
  test('matching immutable program snapshot across plans is supported', () {
    final history = scheduleFixture(id: 'old');
    final oldSet = history.sessions.first.exercises.first.sets.first.id;
    final record = candidates(
      TrainingAppState(
        activePlan: plan,
        planHistory: [history],
        setActuals: {oldSet: actual(date: DateTime.utc(2026, 9, 7))},
      ),
    ).single;
    expect(record.planId, 'old');
    expect(record.sessionTitle, history.sessions.first.title);
  });
  test('ambiguous exercise identifier fails closed', () {
    final ambiguous = scheduleFixture(ambiguous: true);
    final state = TrainingAppState(
      activePlan: ambiguous,
      setActuals: {source: actual(date: DateTime.utc(2026, 9, 7))},
    );
    expect(candidates(state), isEmpty);
  });
  test('warm-up and work set kinds are not combined', () {
    final programJson = Map<String, dynamic>.from(plan.program.toJson());
    final sessions = programJson['sessions'] as List;
    (((sessions.first as Map)['exercises'] as List).first
            as Map)['sets'][0]['setKind'] =
        'warmup';
    final changed = createActivePlan(
      id: plan.id,
      program: TrainingProgram.fromJson(programJson),
      startDate: plan.startDate,
      weekdays: plan.weekdays,
      incrementKg: plan.incrementKg,
    );
    expect(
      candidates(
        TrainingAppState(
          activePlan: changed,
          setActuals: {source: actual(date: DateTime.utc(2026, 9, 7))},
        ),
      ),
      isEmpty,
    );
  });
  test('different set ordinal is never borrowed', () {
    final other = plan.sessions.first.exercises.first.sets.last.id;
    expect(
      candidates(
        TrainingAppState(
          activePlan: plan,
          setActuals: {other: actual(date: DateTime.utc(2026, 9, 7))},
        ),
      ),
      isEmpty,
    );
  });
}
