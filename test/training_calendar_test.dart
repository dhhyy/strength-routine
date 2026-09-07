import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/training_screens.dart';
import 'package:strength_routine/workout_screen.dart';

import 'training_program_fixtures.dart';

void main() {
  late Directory temporary;
  late File file;
  late TrainingController controller;
  late ActiveTrainingPlan plan;
  final today = DateTime.utc(2026, 9, 18);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('training-calendar-');
    file = File('${temporary.path}/state.json');
    plan = fixturePlan();
    controller = TrainingController(
      store: LocalTrainingStore(file),
      loadPrograms: () async => [],
    );
    controller.loading = false;
  });

  tearDown(() async {
    controller.dispose();
    await temporary.delete(recursive: true);
  });

  Future<void> restoreCalendar(
    WidgetTester tester,
    TrainingAppState state,
  ) async {
    await tester.runAsync(() async {
      await LocalTrainingStore(file).save(state);
      controller.state = await LocalTrainingStore(file).load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: SavedRecordsScreen(controller: controller, today: today),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDate(
    WidgetTester tester,
    String calendarLabel,
    String action,
  ) async {
    final date = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == calendarLabel,
    );
    expect(date, findsOneWidget);
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    final button = find.text(action);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutScreen), findsOneWidget);
  }

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );

  testWidgets('더 최근 미완료 운동이 있어도 과거 초안 날짜를 열어 입력을 복원한다', (tester) async {
    final first = plan.sessions.first;
    final set = first.exercises.single.sets.first;
    final state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetDraft(set.id, {
          'weight': '87.',
          'repetitions': '4',
          'rir': '-',
          'note': '다음에 이어서 입력',
          'unit': 'lb',
        });
    expect(
      plan.sessions.where(
        (session) =>
            session.date.isAfter(first.date) && session.date.isBefore(today),
      ),
      hasLength(2),
    );
    await restoreCalendar(tester, state);
    expect(controller.state.setActuals, isEmpty);
    await openDate(tester, '9월 9일, 운동 계획 있음', '운동 기록하기');
    expect(
      tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).readOnly,
      isFalse,
    );
    expect(find.text('작성하던 기록이 있어요'), findsOneWidget);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsOneWidget);
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '87.',
    );
    expect(
      tester.widget<TextFormField>(input('set-repetitions')).controller!.text,
      '4',
    );
    expect(
      tester.widget<TextFormField>(input('set-rir')).controller!.text,
      '-',
    );
    expect(
      tester.widget<TextFormField>(input('set-note')).controller!.text,
      '다음에 이어서 입력',
    );
    expect(find.text('실제 중량 (lb)'), findsOneWidget);
    expect(controller.state.setActuals, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미래 계획은 달력에서 열 수 있지만 실제 수행을 입력할 수 없다', (tester) async {
    final state = TrainingAppState(onboarded: true, activePlan: plan);
    await restoreCalendar(tester, state);
    await openDate(tester, '9월 21일, 운동 계획 있음', '계획 미리보기');
    final screen = tester.widget<WorkoutScreen>(find.byType(WorkoutScreen));
    expect(screen.readOnly, isTrue);
    expect(screen.session.date, DateTime.utc(2026, 9, 21));
    expect(
      tester.widget<WorkoutSetRow>(find.byType(WorkoutSetRow).first).onPressed,
      isNull,
    );
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.toJson(), state.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('보관된 이전 계획의 실제 기록은 달력에서 읽기 전용으로 확인한다', (tester) async {
    final archivedSet = plan.sessions.first.exercises.single.sets.first;
    final next = createActivePlan(
      id: 'next-plan',
      program: fixtureProgram(),
      startDate: DateTime.utc(2026, 9, 21),
      weekdays: [1, 3],
      incrementKg: 2.5,
      baselines: plan.baselines,
    );
    final state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetActual(
          archivedSet.id,
          SetActual.completed(
            weight: 87.5,
            unit: WeightUnit.kg,
            repetitions: 4,
            note: '보관된 실제 수행',
          ),
        )
        .withActivePlan(next);
    await restoreCalendar(tester, state);
    await openDate(tester, '9월 9일, 운동 기록 있음', '계획 미리보기');
    expect(
      tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).readOnly,
      isTrue,
    );
    final row = tester.widget<WorkoutSetRow>(find.byType(WorkoutSetRow).first);
    expect(row.actual!.weight, 87.5);
    expect(row.actual!.note, '보관된 실제 수행');
    expect(row.onPressed, isNull);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.toJson(), state.toJson());
    final stored = await tester.runAsync(() => LocalTrainingStore(file).load());
    expect(stored!.toJson(), state.toJson());
    expect(tester.takeException(), isNull);
  });
}
