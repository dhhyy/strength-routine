import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_program_fixtures.dart';

void main() {
  test('authored composition and order survive weekday scheduling', () {
    final plan = fixturePlan();
    expect(plan.sessions.map((s) => isoDate(s.date)), [
      '2026-09-09',
      '2026-09-14',
      '2026-09-16',
      '2026-09-21',
    ]);
    expect(plan.sessions.map((s) => s.week), [1, 1, 2, 2]);
    expect(plan.program.toJson(), fixtureProgram().toJson());
    final sets = plan.sessions.first.exercises.single.sets;
    expect(sets.map((s) => s.repetitions), [5, 3, 8]);
    expect(sets.map((s) => s.targetKg), [100, 92.5, null]);
    expect(
      plan.sessions
          .expand((s) => s.exercises)
          .expand((e) => e.sets)
          .map((s) => s.id)
          .toSet(),
      hasLength(12),
    );
    expect(
      fixturePlan(id: 'plan-2').sessions.first.exercises.single.sets.first.id,
      isNot(sets.first.id),
    );
  });

  test('percentage prescriptions require an explicit matching baseline', () {
    expect(
      () => createActivePlan(
        id: 'p',
        program: fixtureProgram(),
        startDate: DateTime.utc(2026, 9, 7),
        weekdays: [1, 3],
        incrementKg: 2.5,
      ),
      throwsFormatException,
    );
    expect(
      () => createActivePlan(
        id: 'p',
        program: fixtureProgram(),
        startDate: DateTime.utc(2026, 9, 7),
        weekdays: [1, 3],
        incrementKg: 2.5,
        baselines: {
          MainLift.squat: LiftBaseline(
            lift: MainLift.squat,
            kilograms: 120,
            source: BaselineSource.recordedWeight,
            recordDate: DateTime.utc(2026, 9, 8),
          ),
        },
      ),
      throwsFormatException,
    );
  });

  test(
    'invalid schedules, increments and duplicate composition are rejected',
    () {
      for (final days in [
        [1],
        [1, 1],
        [0, 3],
        [1, 8],
      ]) {
        expect(
          () => createActivePlan(
            id: 'p',
            program: fixtureProgram(),
            startDate: DateTime.utc(2026, 9, 7),
            weekdays: days,
            incrementKg: 2.5,
          ),
          throwsFormatException,
        );
      }
      for (final increment in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => createActivePlan(
            id: 'p',
            program: fixtureProgram(),
            startDate: DateTime.utc(2026, 9, 7),
            weekdays: [1, 3],
            incrementKg: increment,
          ),
          throwsFormatException,
        );
      }
      final set = ProgramSet(
        id: 'duplicate',
        repetitions: 1,
        load: const LoadPrescription.manual(),
      );
      expect(
        () => ProgramExercise(id: 'e', name: 'e', sets: [set, set]),
        throwsFormatException,
      );
      expect(
        () => ProgramExercise(id: 'e', name: 'e', sets: []),
        throwsFormatException,
      );
    },
  );

  test(
    'snapshot roundtrip restores exact dates, loads and baseline provenance',
    () {
      final plan = fixturePlan();
      final restored = ActiveTrainingPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), plan.toJson());
      expect(restored.sessions.first.exercises.single.sets[1].targetKg, 92.5);
      expect(
        restored.baselines[MainLift.squat]!.source,
        BaselineSource.userEntered,
      );
      expect(
        restored.program.sessions.first.exercises.single.mainLift,
        MainLift.squat,
      );
      expect(
        () => ActiveTrainingPlan.fromJson({...plan.toJson(), 'targets': {}}),
        throwsFormatException,
      );
      final missingTarget = Map<String, double?>.of(plan.targetKgBySetId);
      missingTarget[plan.sessions.first.exercises.single.sets.first.id] = null;
      expect(
        () => ActiveTrainingPlan.fromJson({
          ...plan.toJson(),
          'targets': missingTarget,
        }),
        throwsFormatException,
      );
    },
  );

  test('explicit future edits preserve prior snapshot and past dates', () {
    final original = fixturePlan();
    final futureId = original.sessions.last.id;
    final edited = original.rescheduleFuture({
      futureId: DateTime.utc(2026, 9, 28),
    }, asOf: DateTime.utc(2026, 9, 14));
    expect(isoDate(original.sessions.last.date), '2026-09-21');
    expect(isoDate(edited.sessions.last.date), '2026-09-28');
    expect(
      edited.sessions.take(3).map((s) => s.date),
      original.sessions.take(3).map((s) => s.date),
    );
    expect(edited.targetKgBySetId, original.targetKgBySetId);
    expect(
      () => original.rescheduleFuture({
        original.sessions[1].id: DateTime.utc(2026, 9, 23),
      }, asOf: DateTime.utc(2026, 9, 14)),
      throwsFormatException,
    );
    expect(
      () => original.rescheduleFuture({
        futureId: DateTime.utc(2026, 9, 14),
      }, asOf: DateTime.utc(2026, 9, 14)),
      throwsFormatException,
    );
  });

  test(
    'actuals and skipping affect completion without editing prescribed sets',
    () {
      final plan = fixturePlan();
      final session = plan.sessions.first;
      final sets = session.exercises.single.sets;
      final initial = TrainingAppState(activePlan: plan);
      var state = initial.withSetActual(
        sets[0].id,
        SetActual.completed(
          weight: 90,
          unit: WeightUnit.kg,
          repetitions: 4,
          rir: 1,
          note: 'Actual',
        ),
      );
      expect(state.isSessionComplete(session.id), isFalse);
      state = state.withSetActual(
        sets[1].id,
        const SetActual.skipped(note: 'Skipped'),
      );
      expect(state.isSessionComplete(session.id), isTrue);
      expect(state.setActuals.containsKey(sets[2].id), isFalse);
      expect(state.activePlan!.toJson(), plan.toJson());
      expect(initial.setActuals, isEmpty);
      final notified = state.withCompletionNotified(session.id);
      state = notified.withSetActual(sets[0].id, null);
      expect(state.isSessionComplete(session.id), isFalse);
      expect(state.completionNotified, contains(session.id));
      expect(
        () => initial.withCompletionNotified(session.id),
        throwsFormatException,
      );
    },
  );

  test(
    'invalid raw drafts roundtrip and completion clears only that draft',
    () {
      final plan = fixturePlan();
      final sets = plan.sessions.first.exercises.single.sets;
      final raw = {
        'weight': '12..',
        'repetitions': '',
        'rir': '-',
        'note': 'typing',
        'unit': 'lb',
      };
      final state = TrainingAppState(activePlan: plan)
          .withSetDraft(sets[0].id, raw)
          .withSetDraft(sets[1].id, {'weight': '25'});
      raw['weight'] = 'changed externally';
      expect(state.setDrafts[sets[0].id]!['weight'], '12..');
      expect(
        () => state.setDrafts[sets[0].id]!['weight'] = 'write',
        throwsUnsupportedError,
      );
      final restored = TrainingAppState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), state.toJson());
      final completed = state.withSetActual(
        sets[0].id,
        SetActual.completed(weight: 12, unit: WeightUnit.lb, repetitions: 1),
      );
      expect(completed.setDrafts.keys, [sets[1].id]);
      expect(state.setDrafts, hasLength(2));
    },
  );

  test('a new active plan preserves previous plan snapshots and actuals', () {
    final first = fixturePlan();
    final set = first.sessions.first.exercises.single.sets.first;
    final state = TrainingAppState(activePlan: first)
        .withSetActual(set.id, const SetActual.skipped())
        .withActivePlan(fixturePlan(id: 'second'));
    expect(state.planHistory.single.toJson(), first.toJson());
    expect(state.setActuals, contains(set.id));
    expect(state.activePlan!.id, 'second');
    expect(() => state.withSetActual(set.id, null), throwsFormatException);
    expect(() => state.withSetDraft('unknown', {}), throwsFormatException);
    expect(
      () => state.withSessionNote('unknown', 'note'),
      throwsFormatException,
    );
  });

  test('program and plan collections cannot be modified by callers', () {
    final plan = fixturePlan();
    expect(() => plan.program.sessions.clear(), throwsUnsupportedError);
    expect(
      () => plan.sessions.first.exercises.single.sets.clear(),
      throwsUnsupportedError,
    );
    expect(() => plan.targetKgBySetId.clear(), throwsUnsupportedError);
    expect(() => plan.weekdays.clear(), throwsUnsupportedError);
  });

  test(
    'schema data cannot attach actuals to missing plans or unknown status',
    () {
      expect(
        () => TrainingAppState(
          setActuals: {'missing': const SetActual.skipped()},
        ),
        throwsFormatException,
      );
      expect(
        () => SetActual.fromJson({'status': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => LoadPrescription.fromJson({'kind': 'guess'}),
        throwsFormatException,
      );
    },
  );
}
