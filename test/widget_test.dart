import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/main.dart';
import 'package:strength_routine/onboarding_screen.dart';
import 'package:strength_routine/training_screens.dart';

void main() {
  testWidgets('첫 실행은 소개를 표시하고 건너뛰면 오늘 루틴으로 이동한다', (WidgetTester tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('strength-root-'),
    );
    final controller = (await tester.runAsync(() async {
      final c = TrainingController(
        store: LocalTrainingStore(File('${directory!.path}/state.json')),
        loadPrograms: () async => [],
      );
      await c.initialize();
      return c;
    }))!;
    addTearDown(() async {
      controller.dispose();
      await directory!.delete(recursive: true);
    });
    await tester.pumpWidget(
      StrengthApp(
        controller: controller,
        habitStore: LocalHabitStore(File('${directory!.path}/habits.json')),
      ),
    );
    await flushController(tester, controller);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.tap(find.text('건너뛰기'));
    await flushController(tester, controller);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(ActiveTodayScreen), findsOneWidget);
    expect(find.text('프로그램 선택하기'), findsOneWidget);
    expect(find.text('백스쿼트'), findsNothing);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(File('${directory.path}/state.json')).load(),
    );
    expect(restored!.onboarded, isTrue);

    await tester.tap(find.text('프로그램 선택하기'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 프로그램이 없어요'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('손상된 저장 파일은 소개로 초기화하지 않고 복구 후 재시도한다', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('strength-root-corrupt-'),
    ))!;
    final file = File('${directory.path}/state.json');
    final controller = (await tester.runAsync(() async {
      await file.writeAsString('broken state');
      final c = TrainingController(
        store: LocalTrainingStore(file),
        loadPrograms: () async => [],
      );
      await c.initialize();
      return c;
    }))!;
    addTearDown(() async {
      controller.dispose();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      StrengthApp(
        controller: controller,
        habitStore: LocalHabitStore(File('${directory.path}/habits.json')),
      ),
    );
    await flushController(tester, controller);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
    expect(await tester.runAsync(file.readAsString), 'broken state');

    await tester.runAsync(
      () => LocalTrainingStore(file).save(TrainingAppState(onboarded: true)),
    );
    await tester.tap(find.text('다시 시도'));
    await flushController(tester, controller);
    expect(find.text('기록을 불러오지 못했어요'), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('프로그램 선택하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> flushController(
  WidgetTester tester,
  TrainingController controller,
) async {
  // 운동·습관 파일 I/O와 fake-async 마이크로태스크를 번갈아 처리한다.
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
