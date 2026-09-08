import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/domain/training_insights.dart';
import '../tool/device_qa_state.dart';

void main() {
  test('실기기 검증용 오늘 완료→D5→복원→되돌리기 자료를 재현한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'device-qa-fixture-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final today = DateTime(2026, 9, 8);
    var state = createDeviceQaState(today);
    expect(state.setActuals.length, 6);
    final current = state.activePlan!.sessions.singleWhere(
      (s) => s.date == calendarDate(today),
    );
    for (final set in current.exercises.single.sets) {
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: 60,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 1,
        ),
      );
    }
    expect(state.isSessionComplete(current.id), isTrue);
    final suggestion = buildTrainingInsights(
      state,
      planId: state.activePlan!.id,
      asOf: today,
    ).single.suggestion!;
    expect(suggestion.afterKg.values.toSet(), {57.5});
    state = state.withLoadAdjustment(suggestion, asOf: today);
    final file = File('${directory.path}/qa.json');
    await LocalTrainingStore(file).save(state);
    final restored = await LocalTrainingStore(file).load();
    expect(restored.loadAdjustments.single.id, suggestion.id);
    expect(restored.setActuals.length, 8);
    final undone = restored.undoLoadAdjustment(suggestion.id, asOf: today);
    expect(undone.loadAdjustments.single.isUndone, isTrue);
    expect(undone.activePlan!.targetKgBySetId.values.toSet(), {60});
  });
}
