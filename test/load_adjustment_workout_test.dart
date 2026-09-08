import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/workout_screen.dart';
import '../tool/device_qa_state.dart';

void main() {
  testWidgets('조정된 목표를 운동 화면에서 읽고 되돌리면 원래 목표로 갱신', (tester) async {
    final today = DateTime(2026, 9, 8);
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('adjusted-workout-'),
    ))!;
    final c = TrainingController(
      store: LocalTrainingStore(File('${directory.path}/state.json')),
      loadPrograms: () async => [],
    );
    addTearDown(() async {
      c.dispose();
      await directory.delete(recursive: true);
    });
    await tester.runAsync(() async {
      var state = createDeviceQaState(today);
      for (final set in state.activePlan!.sessions[3].exercises.single.sets) {
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
      final suggestion = buildTrainingInsights(
        state,
        planId: state.activePlan!.id,
        asOf: today,
      ).single.suggestion!;
      await c.store.save(state.withLoadAdjustment(suggestion, asOf: today));
      await c.initialize();
    });
    final session = c.state.activePlan!.sessions[4];
    expect(session.exercises.single.sets.first.targetKg, 60);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: WorkoutScreen(controller: c, session: session, readOnly: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('57.5 kg ×', findRichText: true),
      findsNWidgets(2),
    );
    expect(find.textContaining('조정 목표', findRichText: true), findsNWidgets(2));
    await tester.runAsync(
      () => c.update(
        (s) => s.undoLoadAdjustment(s.loadAdjustments.single.id, asOf: today),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('57.5 kg ×', findRichText: true), findsNothing);
    expect(
      find.textContaining('60 kg ×', findRichText: true),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
}
