import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/rest_timer_controller.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/rest_timer_store.dart';
import 'package:strength_routine/domain/rest_timer.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_program_fixtures.dart';

void main() {
  final instant = DateTime.utc(2026, 9, 8, 12);
  ActiveTrainingPlan restPlan() {
    final json =
        jsonDecode(jsonEncode(fixturePlan().toJson())) as Map<String, dynamic>;
    for (final session in json['program']['sessions']) {
      for (final exercise in session['exercises']) {
        for (final set in exercise['sets']) {
          set['restSeconds'] = 90;
        }
      }
    }
    return ActiveTrainingPlan.fromJson(json);
  }

  RestTimerSnapshot timer({DateTime? endsAt}) => RestTimerSnapshot(
    planId: 'plan',
    sessionId: 'session',
    setId: 'set',
    exerciseName: 'Test fixture',
    sourceStamp: 'source',
    setNumber: 1,
    durationSeconds: 90,
    endsAt: endsAt ?? instant.add(const Duration(seconds: 90)),
  );
  test(
    'UTC deadline is unchanged by serialization, background delay or expiry',
    () {
      final original = timer();
      final restored = RestTimerSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );
      expect(
        restored.remainingSeconds(instant.add(const Duration(seconds: 32))),
        58,
      );
      expect(
        restored.remainingSeconds(instant.add(const Duration(hours: 3))),
        0,
      );
      expect(
        restored.remainingSeconds(instant.subtract(const Duration(hours: 3))),
        90,
      );
      expect(restored.toJson(), original.toJson());
    },
  );
  test('pause retains milliseconds and resume makes one new deadline', () {
    final paused = timer().pause(
      instant.add(const Duration(milliseconds: 2501)),
    );
    expect(paused.pausedMilliseconds, 87499);
    expect(paused.remainingSeconds(instant.add(const Duration(days: 1))), 88);
    final resumed = paused.resume(instant.add(const Duration(days: 1)));
    expect(
      resumed.endsAt,
      instant.add(const Duration(days: 1, milliseconds: 87499)),
    );
    expect(() => resumed.resume(instant), throwsFormatException);
    expect(
      () => timer().pause(instant.add(const Duration(seconds: 91))),
      throwsFormatException,
    );
  });
  test(
    'invalid schema fields, impossible dates and ambiguous clock state reject',
    () {
      final json = timer().toJson();
      for (final change in [
        {'durationSeconds': 0},
        {'durationSeconds': 3601},
        {'durationSeconds': 2.5},
        {'endsAt': '2026-02-30T12:00:00.000Z'},
        {'endsAt': '2026-09-08T12:00:00+09:00'},
        {'pausedMilliseconds': 1000},
        {'endsAt': null},
        {'sourceStamp': ''},
        {'unknown': true},
      ]) {
        expect(
          () => RestTimerSnapshot.fromJson({...json, ...change}),
          throwsA(anything),
        );
      }
    },
  );

  late Directory temporary;
  late File file;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('rest-timer-');
    file = File('${temporary.path}/timer.json');
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'store serializes frozen snapshots and clearing restores null',
    () async {
      final store = RestTimerStore(file);
      final original = timer();
      final paused = original.pause(instant.add(const Duration(seconds: 10)));
      await Future.wait([store.save(original), store.save(paused)]);
      expect((await RestTimerStore(file).load())!.toJson(), paused.toJson());
      await store.save(null);
      expect(await RestTimerStore(file).load(), isNull);
    },
  );
  test(
    'corrupt or future timer envelope preserves exact original bytes',
    () async {
      for (final raw in [
        'broken',
        '{"schemaVersion":2,"timer":null}',
        '{"schemaVersion":1}',
      ]) {
        await file.writeAsString(raw);
        await expectLater(RestTimerStore(file).load(), throwsA(anything));
        expect(await file.readAsString(), raw);
      }
    },
  );
  test(
    'start failure retains old timer and retry does not reset the candidate deadline',
    () async {
      var now = instant;
      final control = RestTimerController(
        store: RestTimerStore(file),
        now: () => now,
        isEligible: (_) => true,
      );
      addTearDown(control.dispose);
      await control.initialize();
      expect(await control.start(timer()), isTrue);
      final old = control.snapshot!.toJson();
      await Directory('${file.path}.tmp').create();
      now = now.add(const Duration(seconds: 10));
      final replacement = timer(endsAt: now.add(const Duration(seconds: 90)));
      expect(await control.start(replacement, replace: true), isFalse);
      expect(control.snapshot!.toJson(), old);
      expect(control.saveError, isNotNull);
      await Directory('${file.path}.tmp').delete();
      now = now.add(const Duration(seconds: 20));
      expect(await control.retrySave(), isTrue);
      expect(control.snapshot!.remainingSeconds(now), 70);
      expect(
        (await RestTimerStore(file).load())!.toJson(),
        replacement.toJson(),
      );
    },
  );
  test(
    'duplicate starts require replacement, failed pause and stop preserve prior timer',
    () async {
      var now = instant;
      final control = RestTimerController(
        store: RestTimerStore(file),
        now: () => now,
        isEligible: (_) => true,
      );
      addTearDown(control.dispose);
      await control.initialize();
      await control.start(timer());
      expect(await control.start(timer()), isFalse);
      now = now.add(const Duration(seconds: 10));
      await Directory('${file.path}.tmp').create();
      expect(await control.pause(), isFalse);
      expect(control.snapshot!.isPaused, isFalse);
      await Directory('${file.path}.tmp').delete();
      expect(await control.retrySave(), isTrue);
      expect(control.snapshot!.pausedMilliseconds, 80000);
      now = now.add(const Duration(minutes: 1));
      expect(await control.resume(), isTrue);
      expect(control.snapshot!.remainingSeconds(now), 80);
      await Directory('${file.path}.tmp').create();
      expect(await control.stop(), isFalse);
      expect(control.snapshot, isNotNull);
      await Directory('${file.path}.tmp').delete();
      expect(await control.retrySave(), isTrue);
      expect(control.snapshot, isNull);
    },
  );
  test(
    'read failure blocks starting while unrelated workout file stays intact',
    () async {
      await file.writeAsString('invalid timer');
      final workout = File('${temporary.path}/workout.json');
      await workout.writeAsString('untouched');
      final control = RestTimerController(
        store: RestTimerStore(file),
        now: () => instant,
        isEligible: (_) => true,
      );
      addTearDown(control.dispose);
      await control.initialize();
      expect(control.loadError, isNotNull);
      expect(await control.start(timer()), isFalse);
      expect(await file.readAsString(), 'invalid timer');
      expect(await workout.readAsString(), 'untouched');
    },
  );
  test('a stale failed candidate cannot be restarted by retry', () async {
    var eligible = true;
    final control = RestTimerController(
      store: RestTimerStore(file),
      now: () => instant,
      isEligible: (_) => eligible,
    );
    addTearDown(control.dispose);
    await control.initialize();
    await Directory('${file.path}.tmp').create();
    expect(await control.start(timer()), isFalse);
    await Directory('${file.path}.tmp').delete();
    eligible = false;
    expect(await control.retrySave(), isFalse);
    expect(await file.exists(), isFalse);
    expect(control.saveError, isNull);
  });
  test('pause uses one clock sample at the expiry boundary', () async {
    var now = instant;
    var clockReads = 0;
    final control = RestTimerController(
      store: RestTimerStore(file),
      now: () {
        clockReads++;
        final sampled = now;
        now = now.add(const Duration(milliseconds: 2));
        return sampled;
      },
      isEligible: (_) => true,
    );
    addTearDown(control.dispose);
    await control.initialize();
    await control.start(timer());
    now = instant.add(const Duration(milliseconds: 89999));
    clockReads = 0;
    expect(await control.pause(), isTrue);
    expect(clockReads, 1);
    expect(control.snapshot!.pausedMilliseconds, 1);
  });
  test(
    'timer source must match authored duration, exercise and set ordinal',
    () async {
      final plan = restPlan();
      final session = plan.sessions.first;
      final exercise = session.exercises.single;
      final set = exercise.sets.first;
      final control = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(control.dispose);
      await control.initialize();
      await control.update(
        (_) => TrainingAppState(activePlan: plan).withSetActual(
          set.id,
          SetActual.completed(weight: 10, unit: WeightUnit.kg, repetitions: 3),
        ),
      );
      final correct = RestTimerSnapshot(
        planId: plan.id,
        sessionId: session.id,
        setId: set.id,
        exerciseName: exercise.name,
        sourceStamp: control.restSourceStamp(session.id, set.id),
        setNumber: 1,
        durationSeconds: 90,
        endsAt: instant.add(const Duration(seconds: 90)),
      );
      for (final change in [
        {'durationSeconds': 3600},
        {'exerciseName': 'Wrong'},
        {'setNumber': 2},
      ]) {
        final tampered = RestTimerSnapshot.fromJson({
          ...correct.toJson(),
          ...change,
        });
        expect(await control.restTimer.start(tampered), isFalse);
        await control.restTimer.store.save(tampered);
        await control.restTimer.initialize();
        expect(control.restTimer.available, isNull);
      }
      expect(await control.restTimer.start(correct), isTrue);
    },
  );
  test(
    'fresh training controller restores timer; closing/reopening never resurrects it',
    () async {
      final plan = restPlan();
      final session = plan.sessions.first;
      var state = TrainingAppState(activePlan: plan);
      for (final set in session.exercises.single.sets) {
        state = state.withSetActual(
          set.id,
          SetActual.completed(weight: 10, unit: WeightUnit.kg, repetitions: 3),
        );
      }
      final store = LocalTrainingStore(file);
      await store.save(state);
      final control = TrainingController(
        store: store,
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(control.dispose);
      await control.initialize();
      final set = session.exercises.single.sets.first;
      await control.restTimer.start(
        RestTimerSnapshot(
          planId: plan.id,
          sessionId: session.id,
          setId: set.id,
          exerciseName: session.exercises.single.name,
          sourceStamp: control.restSourceStamp(session.id, set.id),
          setNumber: 1,
          durationSeconds: 90,
          endsAt: instant.add(const Duration(seconds: 90)),
        ),
      );
      final fresh = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant.add(const Duration(seconds: 30)),
        loadPrograms: () async => [],
      );
      addTearDown(fresh.dispose);
      await fresh.initialize();
      expect(fresh.restTimer.available!.remainingSeconds(fresh.now()), 60);
      expect(await fresh.closeSession(session.id, eventId: 'close'), isTrue);
      expect(fresh.restTimer.available, isNull);
      expect(await fresh.reopenSession(session.id, eventId: 'reopen'), isTrue);
      expect(fresh.restTimer.available, isNull);
      final restored = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.restTimer.available, isNull);
    },
  );
  test(
    'editing the source actual, drafting or switching active plan invalidates timer',
    () async {
      final plan = restPlan();
      final session = plan.sessions.first;
      final set = session.exercises.single.sets.first;
      final control = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(control.dispose);
      await control.initialize();
      await control.update(
        (_) => TrainingAppState(activePlan: plan).withSetActual(
          set.id,
          SetActual.completed(weight: 10, unit: WeightUnit.kg, repetitions: 3),
        ),
      );
      Future<bool> start() => control.restTimer.start(
        RestTimerSnapshot(
          planId: plan.id,
          sessionId: session.id,
          setId: set.id,
          exerciseName: session.exercises.single.name,
          sourceStamp: control.restSourceStamp(session.id, set.id),
          setNumber: 1,
          durationSeconds: 90,
          endsAt: instant.add(const Duration(seconds: 90)),
        ),
      );
      expect(await start(), isTrue);
      await control.update(
        (s) => s.withSetActual(
          set.id,
          SetActual.completed(weight: 11, unit: WeightUnit.kg, repetitions: 3),
        ),
      );
      expect(control.restTimer.available, isNull);
      expect(await start(), isTrue);
      await control.update((s) => s.withSetDraft(set.id, {'weight': '12.'}));
      expect(control.restTimer.available, isNull);
      await control.update((s) => s.withSetDraft(set.id, null));
      await control.update(
        (s) => s.withActivePlan(fixturePlan(id: 'new-plan')),
      );
      expect(control.restTimer.available, isNull);
    },
  );
}
