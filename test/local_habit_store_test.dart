import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/domain/habit_record.dart';

void main() {
  late Directory directory;
  late File file;
  final today = DateTime.utc(2026, 9, 7);
  HabitState initial() => HabitState().add(
    HabitDefinition(id: 'habit-1', name: '검증용 습관', createdDate: today),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('habit-store-test-');
    file = File('${directory.path}/habits-state.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'a missing file loads an empty state without inventing habits',
    () async {
      final state = await LocalHabitStore(file).load();
      expect(state.habits, isEmpty);
      expect(state.completedCount(today), 0);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'checks on different dates survive archive, restore and uncheck',
    () async {
      final tomorrow = today.add(const Duration(days: 1));
      var state = initial()
          .setCompleted('habit-1', today, true, asOf: today)
          .setCompleted('habit-1', tomorrow, true, asOf: tomorrow)
          .setArchived('habit-1', true);
      await LocalHabitStore(file).save(state);
      state = await LocalHabitStore(file).load();
      expect(state.habits.single.archived, isTrue);
      expect(state.completedCount(today), 1);
      state = state
          .setArchived('habit-1', false)
          .setCompleted('habit-1', tomorrow, false, asOf: tomorrow);
      await LocalHabitStore(file).save(state);
      final restored = await LocalHabitStore(file).load();
      expect(restored.toJson(), state.toJson());
      expect(restored.completedCount(today), 1);
      expect(restored.completedCount(tomorrow), 0);
      expect(await directory.list().toList(), hasLength(1));
    },
  );

  test('queued writes and reads preserve the most recent check', () async {
    final store = LocalHabitStore(file);
    final first = initial();
    final second = first.setCompleted('habit-1', today, true, asOf: today);
    final writes = [store.save(first), store.save(second)];
    final read = store.load();
    await Future.wait(writes);
    expect((await read).completedCount(today), 1);
  });

  test(
    'corrupt schema, duplicate checks and invalid dates preserve file bytes',
    () async {
      final samples = [
        '{broken',
        jsonEncode({'schemaVersion': 2, 'state': initial().toJson()}),
        jsonEncode({
          'schemaVersion': 1,
          'state': {
            'habits': initial().toJson()['habits'],
            'completedByDate': {
              '2026-09-07': ['habit-1', 'habit-1'],
            },
          },
        }),
        jsonEncode({
          'schemaVersion': 1,
          'state': {
            'habits': initial().toJson()['habits'],
            'completedByDate': {
              '2026-09-31': ['habit-1'],
            },
          },
        }),
        jsonEncode({
          'schemaVersion': 1,
          'state': {
            'habits': [],
            'completedByDate': {
              '2026-09-07': ['missing'],
            },
          },
        }),
      ];
      for (final sample in samples) {
        await file.writeAsString(sample);
        await expectLater(
          LocalHabitStore(file).load(),
          throwsA(isA<LocalHabitStoreException>()),
        );
        expect(await file.readAsString(), sample);
      }
    },
  );

  test(
    'write failure preserves prior bytes and queue allows a later retry',
    () async {
      final blocked = File('${directory.path}/blocked');
      await blocked.writeAsString('keep');
      final store = LocalHabitStore(File('${blocked.path}/habits-state.json'));
      await expectLater(
        store.save(initial()),
        throwsA(isA<LocalHabitStoreException>()),
      );
      expect(await blocked.readAsString(), 'keep');
      await blocked.delete();
      await store.save(initial());
      expect((await store.load()).habits.single.name, '검증용 습관');
    },
  );

  test(
    'empty or duplicate names, unknown IDs and future checks are rejected',
    () {
      expect(
        () => HabitDefinition(id: 'empty', name: '  ', createdDate: today),
        throwsFormatException,
      );
      expect(
        () => initial().add(
          HabitDefinition(id: 'other', name: '검증용 습관', createdDate: today),
        ),
        throwsFormatException,
      );
      expect(
        () => initial().setCompleted('missing', today, true, asOf: today),
        throwsFormatException,
      );
      expect(
        () => initial().setCompleted(
          'habit-1',
          today.add(const Duration(days: 1)),
          true,
          asOf: today,
        ),
        throwsFormatException,
      );
      expect(
        () => initial().setCompleted(
          'habit-1',
          today.subtract(const Duration(days: 1)),
          true,
          asOf: today,
        ),
        throwsFormatException,
      );
    },
  );
}
