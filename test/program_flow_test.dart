import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/main.dart';
import 'package:strength_routine/program_screen.dart';
import 'training_program_fixtures.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('프로그램 선택과 기록·일정 입력 후 시작한 원본 계획을 새 저장소로 복원한다', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('strength-program-ui-'),
    );
    final file = File('${directory!.path}/state.json');
    final program = fixtureProgram();
    final c = (await tester.runAsync(() async {
      final controller = TrainingController(
        store: LocalTrainingStore(file),
        loadPrograms: () async => [program],
      );
      await controller.initialize();
      await controller.update((state) => state.copyWith(onboarded: true));
      return controller;
    }))!;
    addTearDown(() async {
      c.dispose();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      StrengthApp(
        controller: c,
        habitStore: LocalHabitStore(File('${directory.path}/habits.json')),
      ),
    );
    await flushController(tester, c);
    await tester.tap(find.text('프로그램 선택하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프로그램 보기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 프로그램으로 시작'), 400);
    await tester.tap(find.text('이 프로그램으로 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    final today = calendarDate(DateTime.now());
    final start = today.add(const Duration(days: 1));
    await tester.tap(find.text(isoDate(today)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(InputDatePickerFormField),
        matching: find.byType(TextField),
      ),
      '${start.month}/${start.day}/${start.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(isoDate(start)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '월'));
    await tester.tap(find.widgetWithText(FilterChip, '수'));
    await tester.enterText(field('장비 최소 증량 단위 (kg)'), '2.5');
    await tester.ensureVisible(field('스쿼트 프로그램 기준 중량 (kg)'));
    await tester.enterText(field('스쿼트 프로그램 기준 중량 (kg)'), '120');
    await tester.ensureVisible(find.text('루틴 시작하기'));
    await tester.tap(find.text('루틴 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('프로그램에 필요한 최근 기록을 입력해 주세요.'), findsOneWidget);
    expect(c.state.activePlan, isNull);
    await tester.ensureVisible(find.text('최근 기록 입력'));
    await tester.tap(find.text('최근 기록 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(field('실제 중량'), '100');
    await tester.enterText(field('반복 횟수'), '5');
    await tester.ensureVisible(find.text('기록 확인'));
    await tester.tap(find.text('기록 확인'));
    await flushController(tester, c);
    await tester.ensureVisible(find.text('루틴 시작하기'));
    await tester.tap(find.text('루틴 시작하기'));
    await flushController(tester, c);
    expect(find.byType(PlanReviewScreen), findsOneWidget);
    expect(c.state.activePlan, isNull);
    final preview = tester.widget<PlanReviewScreen>(
      find.byType(PlanReviewScreen),
    );
    expect(preview.plan.program.toJson(), program.toJson());
    expect(preview.plan.startDate, start);
    expect(preview.plan.sessions.first.exercises.single.sets[0].targetKg, 100);
    expect(preview.plan.sessions.first.exercises.single.sets[1].targetKg, 92.5);
    expect(
      preview.plan.sessions.first.exercises.single.sets[2].targetKg,
      isNull,
    );
    final beforeStart = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    expect(beforeStart!.activePlan, isNull);

    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.scrollUntilVisible(find.text('이 일정으로 시작'), 400);
    await tester.tap(find.text('이 일정으로 시작'));
    await flushController(tester, c);
    expect(find.byType(PlanReviewScreen), findsOneWidget);
    expect(find.text('저장 다시 시도'), findsOneWidget);
    expect(c.saveError, isNotNull);
    final failedPlanId = c.state.activePlan!.id;
    expect(failedPlanId, preview.plan.id);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PlanReviewScreen), findsNothing);
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    await tester.ensureVisible(find.text('저장 다시 시도'));
    await tester.tap(find.text('저장 다시 시도'));
    await tester.pumpAndSettle();
    final retryPreview = tester.widget<PlanReviewScreen>(
      find.byType(PlanReviewScreen),
    );
    expect(retryPreview.plan.id, failedPlanId);
    expect(retryPreview.plan.toJson(), preview.plan.toJson());
    expect(c.state.planHistory, isEmpty);
    await tester.runAsync(() => Directory(file.path).delete());
    await tester.scrollUntilVisible(find.text('이 일정으로 시작'), 400);
    await tester.tap(find.text('이 일정으로 시작'));
    await flushController(tester, c);
    expect(find.byType(ProgramSetupScreen), findsNothing);
    expect(find.byType(PlanReviewScreen), findsNothing);
    expect(c.state.activePlan, isNotNull);
    expect(c.state.activePlan!.id, failedPlanId);
    expect(c.state.planHistory, isEmpty);
    expect(c.state.activePlan!.program.toJson(), program.toJson());
    expect(c.state.activePlan!.weekdays, [1, 3]);
    expect(c.state.activePlan!.startDate, start);
    expect(c.state.recentRecords.single.weight, 100);
    expect(c.state.recentRecords.single.repetitions, 5);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    expect(restored!.activePlan!.toJson(), c.state.activePlan!.toJson());
    expect(
      restored.activePlan!.sessions.every(
        (s) => [1, 3].contains(s.date.weekday),
      ),
      isTrue,
    );
    expect(
      restored.activePlan!.sessions.first.exercises.single.sets.first.targetKg,
      100,
    );
    expect(restored.setActuals, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = (await tester.runAsync(() async {
      final controller = TrainingController(
        store: LocalTrainingStore(file),
        loadPrograms: () async => [],
      );
      await controller.initialize();
      return controller;
    }))!;
    addTearDown(reopened.dispose);
    await tester.pumpWidget(
      StrengthApp(
        controller: reopened,
        habitStore: LocalHabitStore(File('${directory.path}/habits.json')),
      ),
    );
    await flushController(tester, reopened);
    expect(reopened.state.activePlan!.program.title, 'Test fixture');
    expect(reopened.state.activePlan!.toJson(), c.state.activePlan!.toJson());
    expect(reopened.state.recentRecords.single.weight, 100);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로그램 목록 로딩 실패는 재시도로 회복한다', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('catalog-ui-'),
    );
    var fails = true;
    final c = (await tester.runAsync(() async {
      final controller = TrainingController(
        store: LocalTrainingStore(File('${directory!.path}/state.json')),
        loadPrograms: () async {
          if (fails) throw const FormatException('test-only failure');
          return [fixtureProgram()];
        },
      );
      await controller.initialize();
      return controller;
    }))!;
    addTearDown(() async {
      c.dispose();
      await directory!.delete(recursive: true);
    });
    await tester.pumpWidget(MaterialApp(home: ProgramScreen(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('목록을 불러오지 못했어요'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('다시 불러오기'));
    await flushController(tester, c);
    expect(find.text('Test fixture'), findsOneWidget);
    expect(find.text('목록을 불러오지 못했어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> flushController(
  WidgetTester tester,
  TrainingController controller,
) async {
  // 재시도 저장을 추가하지 않고 UI가 요청한 원래 I/O의 완료를 기다린다.
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump();
    if (!controller.saving &&
        !controller.loading &&
        !controller.catalogLoading &&
        find
            .byType(LinearProgressIndicator, skipOffstage: false)
            .evaluate()
            .isEmpty) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(
    controller.saving || controller.loading || controller.catalogLoading,
    isFalse,
  );
  expect(
    find.byType(LinearProgressIndicator, skipOffstage: false),
    findsNothing,
  );
  await tester.pumpAndSettle();
}
