import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/schedule_edit.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'schedule_previous_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);
  final plan = scheduleFixture();
  final first = plan.sessions.first;
  final last = plan.sessions.last;
  final firstSet = first.exercises.first.sets.first.id;
  final lastSet = last.exercises.first.sets.first.id;
  final changes = {last.id: DateTime.utc(2026, 9, 21)};
  test('only schedule dates change and all existing metadata survives', () {
    final state = TrainingAppState(
      onboarded: true,
      activePlan: plan,
      setActuals: {
        firstSet: SetActual.completed(
          weight: 20,
          unit: WeightUnit.lb,
          repetitions: 8,
        ),
      },
      setDrafts: {
        first.exercises.first.sets.last.id: {'weight': ' 1x ', 'note': '원문'},
      },
      sessionNotes: {first.id: '남긴 메모'},
      legacySessionIds: {first.id},
      loadAdjustments: [
        TargetLoadAdjustment(
          id: 'adjust',
          planId: plan.id,
          exerciseKey: 'row',
          exerciseName: '시티드 케이블 로우',
          policyId: 'test',
          appliedOn: now,
          evidenceSessionIds: [first.id],
          evidenceRirGaps: [2],
          evidenceRecords: {firstSet: 'fixture'},
          beforeKg: {lastSet: 20},
          afterKg: {lastSet: 18},
        ),
      ],
    );
    final next = state.withReviewedSchedule(changes, asOf: now);
    final beforeJson = state.toJson();
    final afterJson = next.toJson();
    expect(next.activePlan!.sessionDates[last.id], changes[last.id]);
    expect(next.activePlan!.targetKgBySetId, plan.targetKgBySetId);
    expect(next.effectiveTargetKg(last.exercises.first.sets.first), 18);
    expect(next.setActuals[firstSet]!.performedDate, isNull);
    beforeJson.remove('activePlan');
    afterJson.remove('activePlan');
    expect(afterJson, beforeJson);
  });
  test('today and past are protected', () {
    final state = TrainingAppState(activePlan: plan);
    expect(
      () => state.withReviewedSchedule({
        first.id: DateTime.utc(2026, 9, 10),
      }, asOf: now),
      throwsFormatException,
    );
    expect(
      () => state.withReviewedSchedule(changes, asOf: last.date),
      throwsFormatException,
    );
  });
  test(
    'future actuals, skips, drafts, notes and legacy state are protected',
    () {
      for (final state in [
        TrainingAppState(
          activePlan: plan,
          setActuals: {lastSet: const SetActual.skipped()},
        ),
        TrainingAppState(
          activePlan: plan,
          setActuals: {
            lastSet: SetActual.completed(
              weight: 20,
              unit: WeightUnit.kg,
              repetitions: 8,
            ),
          },
        ),
        TrainingAppState(activePlan: plan, setDrafts: {lastSet: {}}),
        TrainingAppState(activePlan: plan, sessionNotes: {last.id: ''}),
        TrainingAppState(activePlan: plan, legacySessionIds: {last.id}),
        TrainingAppState(activePlan: plan, completionNotified: {last.id}),
      ]) {
        expect(
          () => state.withReviewedSchedule(changes, asOf: now),
          throwsFormatException,
        );
      }
    },
  );
  test('closed and reopened future sessions stay protected', () {
    var state = TrainingAppState(activePlan: plan);
    for (final set in last.exercises.first.sets) {
      state = state.withSetActual(set.id, const SetActual.skipped());
    }
    state = state
        .closeSession(last.id, eventId: 'close', at: now)
        .reopenSession(last.id, eventId: 'reopen', at: now);
    for (final set in last.exercises.first.sets) {
      state = state.withSetActual(set.id, null);
    }
    expect(
      () => state.withReviewedSchedule(changes, asOf: now),
      throwsFormatException,
    );
  });
  test(
    'unknown sessions, weekdays, order and nonfuture dates fail precisely',
    () {
      final state = TrainingAppState(activePlan: plan);
      for (final change in [
        {'unknown': DateTime.utc(2026, 9, 21)},
        {last.id: DateTime.utc(2026, 9, 22)},
        {last.id: DateTime.utc(2026, 9, 14)},
        {last.id: DateTime.utc(2026, 9, 7)},
      ]) {
        expect(
          () => state.withReviewedSchedule(change, asOf: now),
          throwsFormatException,
        );
      }
    },
  );
  test('unchanged protected dates are a no-op', () {
    final state = TrainingAppState(activePlan: plan);
    expect(
      state.withReviewedSchedule({first.id: first.date}, asOf: now).toJson(),
      state.toJson(),
    );
  });
  test('durable review saves dates and rejects a stale revision', () async {
    final temp = await Directory.systemTemp.createTemp('schedule-review-');
    final store = LocalTrainingStore(File('${temp.path}/state.json'));
    await store.save(TrainingAppState(activePlan: plan));
    final controller = TrainingController(
      store: store,
      now: () => now,
      loadPrograms: () async => [],
    );
    await controller.initialize();
    final revision = controller.revision;
    final candidate = controller.state.withReviewedSchedule(changes, asOf: now);
    expect(
      await controller.commitReviewedState(
        candidate,
        expectedRevision: revision,
      ),
      isTrue,
    );
    expect(
      (await LocalTrainingStore(
        store.file,
      ).load()).activePlan!.sessionDates[last.id],
      changes[last.id],
    );
    expect(
      await controller.commitReviewedState(
        candidate,
        expectedRevision: revision,
      ),
      isFalse,
    );
    controller.dispose();
    await temp.delete(recursive: true);
  });
  test(
    'save failure preserves original state and can retry same review',
    () async {
      final temp = await Directory.systemTemp.createTemp('schedule-failure-');
      final file = File('${temp.path}/state.json');
      final store = LocalTrainingStore(file);
      await store.save(TrainingAppState(activePlan: plan));
      final controller = TrainingController(
        store: store,
        now: () => now,
        loadPrograms: () async => [],
      );
      await controller.initialize();
      final original = controller.state.toJson();
      final candidate = controller.state.withReviewedSchedule(
        changes,
        asOf: now,
      );
      await file.rename('${file.path}.original');
      await Directory(file.path).create();
      expect(
        await controller.commitReviewedState(
          candidate,
          expectedRevision: controller.revision,
        ),
        isFalse,
      );
      expect(controller.state.toJson(), original);
      await Directory(file.path).delete();
      await File('${file.path}.original').rename(file.path);
      expect(
        await controller.commitReviewedState(
          candidate,
          expectedRevision: controller.revision,
        ),
        isTrue,
      );
      controller.dispose();
      await temp.delete(recursive: true);
    },
  );
}
