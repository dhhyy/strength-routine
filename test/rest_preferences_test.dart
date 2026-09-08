import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/settings_controller.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_settings_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/rest_timer_store.dart';
import 'package:strength_routine/domain/app_settings.dart';
import 'package:strength_routine/domain/rest_timer.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'training_program_fixtures.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rest-preferences-');
    file = File('${directory.path}/settings.json');
  });
  tearDown(() async => directory.delete(recursive: true));
  test(
    'legacy settings read defaults and new preferences restore in schema 2',
    () async {
      await file.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'state': {'defaultWeightUnit': 'lb', 'showLoadSuggestions': false},
        }),
      );
      final old = await LocalSettingsStore(file).load();
      expect(old.defaultRestSeconds, isNull);
      expect(old.autoStartRestTimer, isFalse);
      final next = old.copyWith(
        defaultRestSeconds: 123,
        autoStartRestTimer: true,
      );
      await LocalSettingsStore(file).save(next);
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 2);
      expect((await LocalSettingsStore(file).load()).toJson(), next.toJson());
      expect(next.copyWith(clearDefaultRest: true).defaultRestSeconds, isNull);
    },
  );
  test(
    'legacy envelope rejects new meaning and schema 2 rejects absent preferences',
    () async {
      for (final json in [
        {'schemaVersion': 1, 'state': const AppSettings().toJson()},
        {
          'schemaVersion': 2,
          'state': {'defaultWeightUnit': 'kg', 'showLoadSuggestions': true},
        },
      ]) {
        final raw = jsonEncode(json);
        await file.writeAsString(raw);
        await expectLater(LocalSettingsStore(file).load(), throwsA(anything));
        expect(await file.readAsString(), raw);
      }
    },
  );
  test(
    'rest seconds reject invalid values and preserve last stored settings',
    () async {
      final controller = SettingsController(store: LocalSettingsStore(file));
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.update(const AppSettings(defaultRestSeconds: 60));
      final raw = await file.readAsString();
      for (final seconds in [-1, 0, 3601]) {
        expect(
          await controller.update(AppSettings(defaultRestSeconds: seconds)),
          isFalse,
        );
        expect(controller.settings.defaultRestSeconds, 60);
        expect(await file.readAsString(), raw);
      }
      for (final invalid in [1.5, '90', true]) {
        expect(
          () => AppSettings.fromJson({
            ...const AppSettings().toJson(),
            'defaultRestSeconds': invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'failed rest choice is pending only and applies once on successful retry',
    () async {
      final controller = SettingsController(store: LocalSettingsStore(file));
      addTearDown(controller.dispose);
      await controller.initialize();
      await Directory(file.path).create();
      expect(
        await controller.update(
          const AppSettings(defaultRestSeconds: 75, autoStartRestTimer: true),
        ),
        isFalse,
      );
      expect(controller.settings.autoStartRestTimer, isFalse);
      expect(controller.displayedSettings.defaultRestSeconds, 75);
      await Directory(file.path).delete();
      expect(await controller.retrySave(), isTrue);
      expect(
        (await LocalSettingsStore(file).load()).autoStartRestTimer,
        isTrue,
      );
    },
  );
  test(
    'prescription including explicit zero has priority over user default',
    () {
      expect(resolveRestSeconds(0, 90), 0);
      expect(resolveRestSeconds(45, 90), 45);
      expect(resolveRestSeconds(null, 90), 90);
      expect(resolveRestSeconds(null, null), isNull);
    },
  );
  test(
    'user default timer source and deadline survive pause, resume and file reload',
    () async {
      final instant = DateTime.utc(2026, 9, 8);
      final timer = RestTimerSnapshot(
        planId: 'p',
        sessionId: 's',
        setId: 'a',
        exerciseName: '운동',
        sourceStamp: 'stamp',
        setNumber: 1,
        durationSeconds: 123,
        durationSource: RestDurationSource.userDefault,
        endsAt: instant.add(const Duration(seconds: 123)),
      );
      final paused = timer.pause(instant.add(const Duration(seconds: 20)));
      expect(paused.durationSource, RestDurationSource.userDefault);
      final resumed = paused.resume(instant.add(const Duration(minutes: 10)));
      await RestTimerStore(file).save(resumed);
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 2);
      expect((await RestTimerStore(file).load())!.toJson(), resumed.toJson());
      final downgraded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      downgraded['schemaVersion'] = 1;
      await file.writeAsString(jsonEncode(downgraded));
      await expectLater(RestTimerStore(file).load(), throwsFormatException);
    },
  );
  test(
    'custom source restores without consulting new defaults and invalidates on actual edit',
    () async {
      final instant = DateTime.utc(2026, 9, 8);
      final plan = fixturePlan();
      final session = plan.sessions.first;
      final exercise = session.exercises.single;
      final set = exercise.sets.first;
      final controller = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.update(
        (_) => TrainingAppState(activePlan: plan).withSetActual(
          set.id,
          SetActual.completed(weight: 10, unit: WeightUnit.kg, repetitions: 5),
        ),
      );
      final timer = RestTimerSnapshot(
        planId: plan.id,
        sessionId: session.id,
        setId: set.id,
        exerciseName: exercise.name,
        sourceStamp: controller.restSourceStamp(session.id, set.id),
        setNumber: 1,
        durationSeconds: 123,
        durationSource: RestDurationSource.userDefault,
        endsAt: instant.add(const Duration(seconds: 123)),
      );
      expect(await controller.restTimer.start(timer), isTrue);
      final fresh = TrainingController(
        store: LocalTrainingStore(file),
        now: () => instant,
        loadPrograms: () async => [],
      );
      addTearDown(fresh.dispose);
      await fresh.initialize();
      expect(fresh.restTimer.available!.durationSeconds, 123);
      await fresh.update(
        (s) => s.withSetActual(
          set.id,
          SetActual.completed(weight: 11, unit: WeightUnit.kg, repetitions: 5),
        ),
      );
      expect(fresh.restTimer.available, isNull);
    },
  );
}
