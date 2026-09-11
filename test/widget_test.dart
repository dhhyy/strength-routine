import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/auth/auth_controller.dart';
import 'package:strength_routine/auth/auth_session.dart';
import 'package:strength_routine/auth/login_screen.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/main.dart';
import 'package:strength_routine/onboarding_screen.dart';
import 'package:strength_routine/training_screens.dart';

AuthController signedInAuth() => AuthController.preview(
  session: AuthSession(
    userId: 'test-user',
    signedInAt: DateTime.utc(2026, 9, 10),
    displayName: 'Tester',
  ),
);

void main() {
  testWidgets('첫 실행은 소개를 보이고 건너뛰면 가입 허브로 이동한다', (WidgetTester tester) async {
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
        auth: AuthController.preview(),
        habitStore: LocalHabitStore(File('${directory!.path}/habits.json')),
      ),
    );
    await flushController(tester, controller);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('간단하게 가입하기'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('로그인하기를 누르면 로그인 화면이 열린다', (WidgetTester tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('strength-login-'),
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
        auth: AuthController.preview(),
        habitStore: LocalHabitStore(File('${directory!.path}/habits.json')),
      ),
    );
    await flushController(tester, controller);
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('로그인하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsOneWidget);
  });

  testWidgets('세션이 있으면 소개 없이 홈으로 진입한다', (WidgetTester tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('strength-session-'),
    );
    final controller = (await tester.runAsync(() async {
      final c = TrainingController(
        store: LocalTrainingStore(File('${directory!.path}/state.json')),
        loadPrograms: () async => [],
      );
      await c.initialize();
      await c.update((s) => s.copyWith(onboarded: true));
      return c;
    }))!;
    addTearDown(() async {
      controller.dispose();
      await directory!.delete(recursive: true);
    });
    await tester.pumpWidget(
      StrengthApp(
        controller: controller,
        auth: signedInAuth(),
        habitStore: LocalHabitStore(File('${directory!.path}/habits.json')),
      ),
    );
    await flushController(tester, controller);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('프로그램 선택하기'), findsOneWidget);
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
        auth: signedInAuth(),
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
  await tester.pump();
}
