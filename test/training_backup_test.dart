import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/training_backup.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/rest_timer.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'training_program_fixtures.dart';

void main() {
  late Directory dir;
  late File file;
  late TrainingController controller;
  late TrainingBackupService service;
  late TrainingAppState original;
  final at = DateTime.utc(2026, 9, 8, 12);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup-test-');
    file = File('${dir.path}/state.json');
    final plan = fixturePlan();
    original = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetActual(
          plan.sessions.first.exercises.first.sets.first.id,
          SetActual.completed(
            weight: 100,
            unit: WeightUnit.lb,
            repetitions: 5,
            performedDate: at,
            recordedAt: at,
            note: '원문',
          ),
        )
        .withSetDraft(plan.sessions.last.exercises.first.sets.last.id, {
          'weight': '9.',
          'rir': '',
          'note': '미완성',
        });
    await LocalTrainingStore(file).save(original);
    controller = TrainingController(
      store: LocalTrainingStore(file),
      now: () => at,
      loadPrograms: () async => [],
    );
    await controller.initialize();
    service = TrainingBackupService(controller);
  });
  tearDown(() async {
    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('workout backup preserves complete state, raw drafts and dates', () {
    final restored = TrainingBackup.parse(service.export());
    expect(restored.state.toJson(), original.toJson());
    expect(restored.createdAt, at);
    final envelope = jsonDecode(service.export()) as Map;
    expect(
      envelope.keys,
      unorderedEquals([
        'kind',
        'backupVersion',
        'createdAt',
        'data',
        'checksum',
      ]),
    );
  });

  test('damage, unknown backup version and extra envelope field fail', () {
    final raw = jsonDecode(service.export()) as Map<String, dynamic>;
    final broken = jsonDecode(service.export()) as Map<String, dynamic>;
    (broken['data']['state'] as Map)['onboarded'] = false;
    expect(
      () => TrainingBackup.parse(jsonEncode(broken)),
      throwsFormatException,
    );
    raw['backupVersion'] = 2;
    expect(() => TrainingBackup.parse(jsonEncode(raw)), throwsFormatException);
    raw['backupVersion'] = 1;
    raw['unknown'] = true;
    expect(() => TrainingBackup.parse(jsonEncode(raw)), throwsFormatException);
  });

  test('future state, orphan references and unsupported fields fail', () {
    final raw = jsonDecode(service.export()) as Map<String, dynamic>;
    final data = raw['data'] as Map<String, dynamic>;
    data['schemaVersion'] = 7;
    raw['checksum'] = TrainingBackup.checksum(data);
    expect(() => TrainingBackup.parse(jsonEncode(raw)), throwsFormatException);
    data['schemaVersion'] = 3;
    (data['state']['setDrafts'] as Map)['missing-set'] = {'weight': '8'};
    raw['checksum'] = TrainingBackup.checksum(data);
    expect(() => TrainingBackup.parse(jsonEncode(raw)), throwsFormatException);
  });

  test('size and deep nesting limits are applied before parsing', () {
    expect(
      () => TrainingBackup.parse(' ' * (TrainingBackup.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => TrainingBackup.parse('${'[' * 65}0${']' * 65}'),
      throwsFormatException,
    );
  });

  test('legacy state migrates only missing lifecycle metadata', () {
    final raw = jsonDecode(service.export()) as Map<String, dynamic>;
    final data = raw['data'] as Map<String, dynamic>;
    data['schemaVersion'] = 1;
    (data['state'] as Map)
      ..remove('sessionEvents')
      ..remove('legacySessionIds');
    raw['checksum'] = TrainingBackup.checksum(data);
    final parsed = TrainingBackup.parse(jsonEncode(raw));
    expect(parsed.state.activePlan!.toJson(), original.activePlan!.toJson());
    expect(parsed.state.setDrafts, original.setDrafts);
    expect(parsed.state.legacySessionIds, isNotEmpty);
  });

  test(
    'restore writes recovery then publishes durable state and unique generation',
    () async {
      final backup = TrainingBackup(
        state: TrainingAppState(onboarded: true),
        createdAt: at,
      );
      expect(
        await service.restore(backup, expectedRevision: controller.revision),
        isTrue,
      );
      expect(controller.state.activePlan, isNull);
      expect(
        TrainingBackup.parse(
          await service.recoveryFile.readAsString(),
        ).state.toJson(),
        original.toJson(),
      );
      final reload = LocalTrainingStore(file);
      expect((await reload.load()).toJson(), backup.state.toJson());
      expect(reload.restorationGeneration, isNotEmpty);
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 6);
      await controller.retrySave();
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 6);
    },
  );

  test('stale review refuses replacement and preserves file', () async {
    final revision = controller.revision;
    await controller.update((s) => s.copyWith(onboarded: false));
    final bytes = await file.readAsString();
    expect(
      await service.restore(
        TrainingBackup(state: original, createdAt: at),
        expectedRevision: revision,
      ),
      isFalse,
    );
    expect(await file.readAsString(), bytes);
    expect(await service.recoveryFile.exists(), isFalse);
  });

  test(
    'pending save blocks restore/export and cannot overwrite restored state',
    () async {
      final pending = controller.update((s) => s.copyWith(onboarded: false));
      expect(() => service.export(), throwsFormatException);
      expect(
        await service.restore(
          TrainingBackup(state: original, createdAt: at),
          expectedRevision: controller.revision,
        ),
        isFalse,
      );
      await pending;
      expect(
        await service.restore(
          TrainingBackup(state: original, createdAt: at),
          expectedRevision: controller.revision,
        ),
        isTrue,
      );
      expect(
        (await LocalTrainingStore(file).load()).toJson(),
        original.toJson(),
      );
    },
  );

  test('review lock rejects late updates and duplicate commits', () async {
    final revision = controller.revision;
    final first = controller.commitReviewedState(
      TrainingAppState(onboarded: true),
      expectedRevision: revision,
    );
    expect(await controller.update((s) => original), isFalse);
    expect(
      await controller.commitReviewedState(
        original,
        expectedRevision: revision,
      ),
      isFalse,
    );
    expect(await first, isTrue);
    expect(controller.state.activePlan, isNull);
  });

  test('recovery write failure preserves original memory and bytes', () async {
    await Directory(service.recoveryFile.path).create();
    final bytes = await file.readAsString();
    expect(
      await service.restore(
        TrainingBackup(state: TrainingAppState(), createdAt: at),
        expectedRevision: controller.revision,
      ),
      isFalse,
    );
    expect(controller.state.toJson(), original.toJson());
    expect(await file.readAsString(), bytes);
    expect(controller.sessionActionPending, isFalse);
  });

  test('main write failure retains memory and readable recovery', () async {
    final bytes = await file.readAsString();
    await file.delete();
    await Directory(file.path).create();
    expect(
      await service.restore(
        TrainingBackup(state: TrainingAppState(), createdAt: at),
        expectedRevision: controller.revision,
      ),
      isFalse,
    );
    expect(controller.state.toJson(), original.toJson());
    expect(
      TrainingBackup.parse(
        await service.recoveryFile.readAsString(),
      ).state.toJson(),
      original.toJson(),
    );
    await Directory(file.path).delete();
    await file.writeAsString(bytes);
  });

  test(
    'restore invalidates old timer even when same plan and actual are restored',
    () async {
      final plan = createActivePlan(
        id: 'timer-plan',
        program: TrainingProgram(
          id: 't',
          version: '1',
          title: 'timer',
          trainerName: 'test',
          description: 'test',
          weeks: 1,
          sessions: [
            ProgramSession(
              id: 's',
              week: 1,
              dayOrder: 1,
              title: 't',
              exercises: [
                ProgramExercise(
                  id: 'e',
                  name: 'test',
                  sets: [
                    ProgramSet(
                      id: 'set',
                      repetitions: 5,
                      restSeconds: 60,
                      load: const LoadPrescription.manual(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        startDate: at,
        weekdays: [2],
        incrementKg: 1,
      );
      final session = plan.sessions.single,
          entry = plan.sessions.single.executionSets.single;
      await controller.update(
        (s) => s
            .withActivePlan(plan)
            .withSetActual(
              entry.set.id,
              SetActual.completed(
                weight: 20,
                unit: WeightUnit.kg,
                repetitions: 5,
              ),
            ),
      );
      final timer = RestTimerSnapshot(
        planId: plan.id,
        sessionId: session.id,
        setId: entry.set.id,
        exerciseName: entry.exercise.name,
        sourceStamp: controller.restSourceStamp(session.id, entry.set.id),
        setNumber: 1,
        durationSeconds: 60,
        endsAt: at.add(const Duration(seconds: 60)),
      );
      expect(await controller.restTimer.start(timer), isTrue);
      final backup = TrainingBackup.parse(service.export());
      expect(
        await service.restore(backup, expectedRevision: controller.revision),
        isTrue,
      );
      expect(controller.restTimer.available, isNull);
      final restarted = TrainingController(
        store: LocalTrainingStore(file),
        now: () => at,
        loadPrograms: () async => [],
      );
      await restarted.initialize();
      expect(restarted.restTimer.available, isNull);
      restarted.dispose();
    },
  );

  test(
    'schema6 requires restoration generation and older schemas reject it',
    () {
      final envelope = Map<String, dynamic>.from(
        LocalTrainingStore.encodeEnvelope(original),
      );
      envelope['schemaVersion'] = 6;
      expect(
        () => LocalTrainingStore.decodeEnvelope(envelope),
        throwsFormatException,
      );
      envelope['restorationGeneration'] = 'generation';
      expect(
        LocalTrainingStore.decodeEnvelope(envelope).toJson(),
        original.toJson(),
      );
      envelope['schemaVersion'] = 3;
      expect(
        () => LocalTrainingStore.decodeEnvelope(envelope),
        throwsFormatException,
      );
    },
  );
  test(
    'unreadable state restores only after exact original bytes are preserved',
    () async {
      final valid = TrainingBackup(state: original, createdAt: at);
      const broken = '{ broken original workout bytes';
      await file.writeAsString(broken);
      await controller.initialize();
      expect(controller.loadError, isNotNull);
      expect(service.ready, isFalse);
      expect(service.canRestore, isTrue);
      expect(
        await service.restore(valid, expectedRevision: controller.revision),
        isTrue,
      );
      expect(await service.unreadableRecoveryFile.readAsString(), broken);
      expect(controller.loadError, isNull);
      expect(
        (await LocalTrainingStore(file).load()).toJson(),
        original.toJson(),
      );
    },
  );
}
