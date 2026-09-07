import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_program_fixtures.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('strength-store-test-');
    file = File('${directory.path}/state.json');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('only a missing file loads the initial state', () async {
    final state = await LocalTrainingStore(file).load();
    expect(state.onboarded, isFalse);
    expect(state.activePlan, isNull);
    expect(await file.exists(), isFalse);
  });

  test(
    'save and fresh-store load restore plan, record, actual, draft and notes',
    () async {
      final plan = fixturePlan();
      final session = plan.sessions.first;
      final sets = session.exercises.single.sets;
      var state = TrainingAppState(
        onboarded: true,
        activePlan: plan,
        recentRecords: [
          RecentLiftRecord(
            lift: MainLift.squat,
            weight: 120,
            unit: WeightUnit.kg,
            repetitions: 1,
            date: DateTime.utc(2026, 9, 7),
          ),
        ],
      );
      state = state
          .withSetActual(
            sets[0].id,
            SetActual.completed(
              weight: 95,
              unit: WeightUnit.kg,
              repetitions: 5,
              rir: 2,
            ),
          )
          .withSetActual(sets[1].id, const SetActual.skipped())
          .withSetDraft(sets[2].id, {'weight': 'unfinished.'})
          .withSessionNote(session.id, 'Session note')
          .withCompletionNotified(session.id);
      await LocalTrainingStore(file).save(state);
      final restored = await LocalTrainingStore(file).load();
      expect(restored.toJson(), state.toJson());
      expect(restored.completionNotified, contains(session.id));
      expect(restored.isSessionComplete(session.id), isTrue);
      expect((await directory.list().toList()), hasLength(1));
    },
  );

  test(
    'corrupt and unknown schema files fail without wiping original bytes',
    () async {
      for (final content in [
        '{broken',
        jsonEncode({'schemaVersion': 99, 'state': {}}),
        jsonEncode({
          'schemaVersion': 1,
          'state': {'onboarded': true},
        }),
      ]) {
        await file.writeAsString(content);
        await expectLater(
          LocalTrainingStore(file).load(),
          throwsA(isA<LocalTrainingStoreException>()),
        );
        expect(await file.readAsString(), content);
      }
    },
  );

  test('queued saves and reads observe invocation order', () async {
    final store = LocalTrainingStore(file);
    final first = TrainingAppState(onboarded: true);
    final second = TrainingAppState(onboarded: false);
    final writes = [store.save(first), store.save(second)];
    final read = store.load();
    await Future.wait(writes);
    expect((await read).onboarded, isFalse);
    expect((await LocalTrainingStore(file).load()).toJson(), second.toJson());
  });

  test('a failed write propagates and does not poison later saves', () async {
    final blockedParent = File('${directory.path}/blocked');
    await blockedParent.writeAsString('Keep this file');
    final destination = File('${blockedParent.path}/state.json');
    final store = LocalTrainingStore(destination);
    await expectLater(
      store.save(TrainingAppState()),
      throwsA(isA<LocalTrainingStoreException>()),
    );
    expect(await blockedParent.readAsString(), 'Keep this file');
    await blockedParent.delete();
    await store.save(TrainingAppState(onboarded: true));
    expect((await store.load()).onboarded, isTrue);
  });

  test(
    'a structurally invalid restored record is rejected without wiping data',
    () async {
      final store = LocalTrainingStore(file);
      final invalid = TrainingAppState().toJson();
      invalid['recentRecords'] = [
        RecentLiftRecord(
          lift: MainLift.squat,
          weight: -1,
          unit: WeightUnit.kg,
          repetitions: 1,
          date: DateTime.utc(2026, 9, 7),
        ).toJson(),
      ];
      final bytes = jsonEncode({'schemaVersion': 1, 'state': invalid});
      await file.writeAsString(bytes);
      await expectLater(
        store.load(),
        throwsA(isA<LocalTrainingStoreException>()),
      );
      expect(await file.readAsString(), bytes);
    },
  );
}
