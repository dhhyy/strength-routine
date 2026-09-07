import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/workout_screen.dart';

void main() {
  late Directory temporary;
  late File file;
  late TrainingController controller;
  late ActiveTrainingPlan plan;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('workout-ui-');
    file = File('${temporary.path}/state.json');
    plan = createActivePlan(
      id: 'test-plan',
      program: TrainingProgram(
        id: 'test-program',
        version: 'test-v1',
        title: '검증 전용 프로그램',
        trainerName: '테스트 작성자',
        description: '제품에 배포하지 않는 테스트 데이터',
        weeks: 1,
        sessions: [
          ProgramSession(
            id: 'session',
            week: 1,
            dayOrder: 1,
            title: '첫 번째 훈련',
            exercises: [
              ProgramExercise(
                id: 'exercise',
                name: '긴 운동 이름의 바벨 백스쿼트',
                sets: [
                  ProgramSet(
                    id: 'set-1',
                    repetitions: 5,
                    rir: 2,
                    load: LoadPrescription.fixedKg(50),
                  ),
                  ProgramSet(
                    id: 'set-2',
                    repetitions: 5,
                    load: LoadPrescription.fixedKg(50),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      startDate: DateTime.utc(2026, 9, 7),
      weekdays: [1],
      incrementKg: 1,
    );
    controller = TrainingController(
      store: LocalTrainingStore(file),
      loadPrograms: () async => [],
    );
    controller.loading = false;
    controller.state = TrainingAppState(onboarded: true, activePlan: plan);
  });

  tearDown(() async {
    controller.dispose();
    await temporary.delete(recursive: true);
  });

  Future<void> pumpWorkout(WidgetTester tester, {bool readOnly = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: WorkoutScreen(
          controller: controller,
          session: plan.sessions.single,
          readOnly: readOnly,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flushSave(WidgetTester tester) async {
    for (var attempt = 0; attempt < 200 && controller.saving; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(controller.saving, isFalse);
    await tester.pumpAndSettle();
  }

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );

  Finder editorAction(String label) =>
      find.descendant(of: find.byType(SetEditor), matching: find.text(label));

  testWidgets('저장 후 다음은 완료·제외를 건너뛰고 다음 운동의 기존 초안을 복원한다', (tester) async {
    final originalProgram = plan.program;
    final originalSession = originalProgram.sessions.single;
    plan = createActivePlan(
      id: plan.id,
      program: TrainingProgram(
        id: originalProgram.id,
        version: originalProgram.version,
        title: originalProgram.title,
        trainerName: originalProgram.trainerName,
        description: originalProgram.description,
        weeks: originalProgram.weeks,
        sessions: [
          ProgramSession(
            id: originalSession.id,
            week: originalSession.week,
            dayOrder: originalSession.dayOrder,
            title: originalSession.title,
            exercises: [
              ...originalSession.exercises,
              ProgramExercise(
                id: 'next-exercise',
                name: '다음 운동 벤치프레스',
                sets: [
                  for (var index = 1; index <= 2; index++)
                    ProgramSet(
                      id: 'next-$index',
                      repetitions: 6,
                      load: LoadPrescription.fixedKg(30),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      startDate: plan.startDate,
      weekdays: plan.weekdays,
      incrementKg: plan.incrementKg,
    );
    final sets = plan.sessions.single.exercises.expand((e) => e.sets).toList();
    final planSnapshot = plan.toJson();
    controller.state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetActual(
          sets[1].id,
          SetActual.completed(weight: 45, unit: WeightUnit.kg, repetitions: 5),
        )
        .withSetActual(sets[2].id, const SetActual.skipped(note: '기존 제외'))
        .withSetDraft(sets[3].id, {
          'weight': '44.',
          'unit': 'lb',
          'repetitions': '4',
          'rir': '0',
          'note': '작성 중인 마지막 세트',
        });
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    await tester.enterText(input('set-weight'), '0');
    await tester.enterText(input('set-repetitions'), '5');
    await flushSave(tester);
    await tester.ensureVisible(editorAction('저장하고 다음 세트'));
    await tester.tap(editorAction('저장하고 다음 세트'));
    await flushSave(tester);

    expect(find.byType(SetEditor), findsOneWidget);
    expect(tester.widget<SetEditor>(find.byType(SetEditor)).set.id, sets[3].id);
    expect(find.text('다음 운동 벤치프레스 · 2세트'), findsOneWidget);
    for (final entry in {
      'set-weight': '44.',
      'set-repetitions': '4',
      'set-rir': '0',
      'set-note': '작성 중인 마지막 세트',
    }.entries) {
      expect(
        tester.widget<TextFormField>(input(entry.key)).controller!.text,
        entry.value,
      );
    }
    expect(
      tester
          .widget<SegmentedButton<WeightUnit>>(
            find.byKey(const ValueKey('set-weight-unit')),
          )
          .selected,
      {WeightUnit.lb},
    );
    expect(editorAction('저장하고 다음 세트'), findsNothing);
    expect(controller.state.setActuals[sets.first.id]!.weight, 0);
    expect(controller.state.setActuals[sets[2].id]!.note, '기존 제외');
    expect(controller.state.setActuals.containsKey(sets.last.id), isFalse);
    expect(plan.toJson(), planSnapshot);
    final saved = (await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    ))!;
    expect(saved.setDrafts[sets.last.id]!['weight'], '44.');

    await tester.ensureVisible(editorAction('세트 완료'));
    await tester.tap(editorAction('세트 완료'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsNothing);
    expect(find.text('운동 기록을 저장했어요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.setActuals[sets.last.id]!.unit, WeightUnit.lb);
    expect(controller.state.setDrafts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다음 세트 이동은 검증·저장 실패에서 멈추고 중복 재시도에도 한 번만 열린다', (tester) async {
    final sets = plan.sessions.single.exercises.single.sets;
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(editorAction('저장하고 다음 세트'));
    await tester.tap(editorAction('저장하고 다음 세트'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SetEditor>(find.byType(SetEditor)).set.id,
      sets.first.id,
    );
    expect(controller.state.setActuals, isEmpty);
    expect(find.text('0 이상의 중량을 입력해 주세요.'), findsOneWidget);
    await tester.enterText(input('set-weight'), '45');
    await tester.enterText(input('set-repetitions'), '4');
    await flushSave(tester);
    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.ensureVisible(editorAction('저장하고 다음 세트'));
    await tester.tap(editorAction('저장하고 다음 세트'));
    await tester.tap(editorAction('저장하고 다음 세트'));
    await flushSave(tester);
    expect(
      tester.widget<SetEditor>(find.byType(SetEditor)).set.id,
      sets.first.id,
    );
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '45',
    );
    expect(controller.saveError, isNotNull);
    await tester.runAsync(() => Directory(file.path).delete());
    await tester.ensureVisible(editorAction('저장 다시 시도'));
    await tester.tap(editorAction('저장 다시 시도'));
    await tester.tap(editorAction('저장 다시 시도'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsOneWidget);
    expect(
      tester.widget<SetEditor>(find.byType(SetEditor)).set.id,
      sets.last.id,
    );
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      isEmpty,
    );
    expect(controller.state.setActuals.length, 1);
    expect(controller.state.setActuals.containsKey(sets.last.id), isFalse);
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsNothing);
    expect(find.text('운동 기록을 저장했어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마지막 세트 저장은 앞쪽 미기록을 자동 처리하지 않고 목록으로 돌아간다', (tester) async {
    final sets = plan.sessions.single.exercises.single.sets;
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).last);
    await tester.pumpAndSettle();
    expect(editorAction('저장하고 다음 세트'), findsNothing);
    await tester.enterText(input('set-weight'), '50');
    await tester.enterText(input('set-repetitions'), '5');
    await flushSave(tester);
    await tester.ensureVisible(editorAction('세트 완료'));
    await tester.tap(editorAction('세트 완료'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.setActuals.containsKey(sets.first.id), isFalse);
    expect(controller.state.setActuals.containsKey(sets.last.id), isTrue);
    expect(find.text('운동 기록을 저장했어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('초안 저장 후 닫기 실패를 재시도하면 초안을 보존하고 닫힌다', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    await tester.enterText(input('set-weight'), '42.');
    await flushSave(tester);
    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsOneWidget);
    await tester.runAsync(() => Directory(file.path).delete());
    await tester.ensureVisible(editorAction('저장 다시 시도'));
    await tester.tap(editorAction('저장 다시 시도'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsNothing);
    final restored = (await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    ))!;
    expect(restored.setActuals, isEmpty);
    expect(restored.setDrafts.values.single['weight'], '42.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('중량 처방을 실제 기록으로 채우지 않고 입력 초안을 새 저장소로 복원한다', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    final weightField = tester.widget<TextFormField>(input('set-weight'));
    expect(weightField.controller!.text, isEmpty);
    await tester.enterText(input('set-weight'), '42.');
    await tester.enterText(input('set-repetitions'), '4');
    await tester.enterText(input('set-note'), '다음 세트에서 확인');
    await flushSave(tester);
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsNothing);

    final restored = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    final setId = plan.sessions.single.exercises.single.sets.first.id;
    expect(restored!.setDrafts[setId]!['weight'], '42.');
    expect(restored.setDrafts[setId]!['note'], '다음 세트에서 확인');
    expect(restored.setActuals, isEmpty);
    controller.state = restored;
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '42.',
    );
    expect(find.text('작성하던 기록이 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검증 오류와 저장 실패를 유지하고 재시도로 실제 수행을 저장한다', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.tap(find.text('세트 완료'));
    await tester.pumpAndSettle();
    expect(find.text('0 이상의 중량을 입력해 주세요.'), findsOneWidget);
    expect(find.text('1 이상의 정수로 입력해 주세요.'), findsOneWidget);
    expect(controller.state.setActuals, isEmpty);
    await tester.enterText(input('set-weight'), '45');
    await tester.enterText(input('set-repetitions'), '4');
    await tester.enterText(input('set-rir'), '1.5');
    await flushSave(tester);

    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.tap(find.text('세트 완료'));
    await flushSave(tester);
    expect(find.byType(SetEditor), findsOneWidget);
    expect(find.text('저장 다시 시도'), findsWidgets);
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '45',
    );
    expect(controller.saveError, isNotNull);

    await tester.runAsync(() => Directory(file.path).delete());
    final retry = find.descendant(
      of: find.byType(SetEditor),
      matching: find.text('저장 다시 시도'),
    );
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await flushSave(tester);
    expect(find.byType(SetEditor), findsNothing);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    final actual = restored!.setActuals.values.single;
    expect(actual.status, SetActualStatus.completed);
    expect(actual.weight, 45);
    expect(actual.repetitions, 4);
    expect(actual.rir, 1.5);
    expect(restored.setDrafts, isEmpty);
    expect(plan.sessions.single.exercises.single.sets.first.targetKg, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lb 단위 선택은 숫자를 유지하고 초안과 완료 기록을 재실행 후 복원한다', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    await tester.enterText(input('set-weight'), '100');
    await tester.enterText(input('set-repetitions'), '5');
    final units = find.byKey(const ValueKey('set-weight-unit'));
    final pounds = find.descendant(of: units, matching: find.text('lb'));
    await tester.ensureVisible(pounds);
    await tester.tap(pounds);
    await flushSave(tester);
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '100',
    );
    expect(find.text('단위를 바꿔도 입력한 숫자는 유지돼요.'), findsOneWidget);
    final setId = plan.sessions.single.exercises.single.sets.first.id;
    final draft = (await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    ))!;
    expect(draft.setDrafts[setId]!['unit'], 'lb');
    expect(draft.setDrafts[setId]!['weight'], '100');
    expect(draft.setActuals, isEmpty);
    await tester.ensureVisible(find.byTooltip('기록 초안 저장하고 닫기'));
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await flushSave(tester);
    controller.state = draft;
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<WeightUnit>>(units).selected, {
      WeightUnit.lb,
    });
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.tap(find.text('세트 완료'));
    await flushSave(tester);
    final completed = (await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    ))!;
    expect(completed.setActuals[setId]!.unit, WeightUnit.lb);
    expect(completed.setActuals[setId]!.weight, 100);
    expect(completed.setDrafts, isEmpty);
    expect(
      completed
          .activePlan!
          .sessions
          .single
          .exercises
          .single
          .sets
          .first
          .targetKg,
      50,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    controller = (await tester.runAsync(() async {
      final reopened = TrainingController(
        store: LocalTrainingStore(file),
        loadPrograms: () async => [],
      );
      await reopened.initialize();
      return reopened;
    }))!;
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<WeightUnit>>(units).selected, {
      WeightUnit.lb,
    });
    expect(
      tester.widget<TextFormField>(input('set-weight')).controller!.text,
      '100',
    );
    expect(find.text('실제 중량 (lb)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면과 키보드에서도 기록 버튼에 접근하고 읽기 전용은 수정하지 않는다', (tester) async {
    await pumpWorkout(tester, readOnly: true);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.setActuals, isEmpty);
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.pumpAndSettle();
    expect(find.text('세트 완료').hitTestable(), findsOneWidget);
    await tester.ensureVisible(editorAction('저장하고 다음 세트'));
    await tester.pumpAndSettle();
    expect(editorAction('저장하고 다음 세트').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('제외와 완료를 구분하고 완료 안내는 되돌린 뒤에도 한 번만 표시한다', (tester) async {
    final sets = plan.sessions.single.exercises.single.sets;
    controller.state = controller.state.withSetActual(
      sets.first.id,
      SetActual.completed(weight: 45, unit: WeightUnit.kg, repetitions: 5),
    );
    await pumpWorkout(tester);
    await tester.tap(find.byType(WorkoutSetRow).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이번 세트 제외').last);
    await tester.tap(find.text('이번 세트 제외').last);
    await flushSave(tester);
    expect(find.text('운동 기록을 저장했어요'), findsOneWidget);
    expect(
      controller.state.setActuals[sets.last.id]!.status,
      SetActualStatus.skipped,
    );
    expect(
      controller.state.completionNotified,
      contains(plan.sessions.single.id),
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(WorkoutSetRow).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('기록 전으로 되돌리기'));
    await tester.tap(find.text('기록 전으로 되돌리기'));
    await flushSave(tester);
    expect(
      controller.state.isSessionComplete(plan.sessions.single.id),
      isFalse,
    );
    await tester.tap(find.byType(WorkoutSetRow).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이번 세트 제외').last);
    await tester.tap(find.text('이번 세트 제외').last);
    await flushSave(tester);
    expect(find.text('운동 기록을 저장했어요'), findsNothing);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    expect(restored!.isSessionComplete(plan.sessions.single.id), isTrue);
    expect(restored.completionNotified, contains(plan.sessions.single.id));
    expect(tester.takeException(), isNull);
  });
}
