import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/program_screen.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/workout_screen.dart';

// Synthetic fixtures exercise the editor. They are never published programs.
ActiveTrainingPlan advancedWorkoutPlan({bool long = false}) => createActivePlan(
  id: 'advanced-plan',
  program: TrainingProgram(
    id: 'advanced-fixture',
    version: 'test',
    title: '고급 처방 검증용',
    trainerName: 'Test',
    description: 'Synthetic fixture only',
    weeks: 1,
    sessions: [
      ProgramSession(
        id: 'session',
        week: 1,
        dayOrder: 1,
        title: 'Test fixture',
        exercises: [
          for (var e = 0; e < (long ? 7 : 2); e++)
            ProgramExercise(
              id: 'e$e',
              name: '검증 운동 ${e + 1}',
              supersetGroup: e < 2 ? '상체' : null,
              sets: [
                for (var s = 0; s < (e == 1 ? 1 : 2); s++)
                  ProgramSet(
                    id: 's$s',
                    repetitions: 8,
                    rir: 2,
                    isAmrap: e == 0 && s == 0,
                    restSeconds: e == 0 ? 0 : 90,
                    tempo: e == 0 ? '3-1-X-0' : null,
                    load: LoadPrescription.fixedKg(20),
                  ),
              ],
            ),
        ],
      ),
    ],
  ),
  startDate: DateTime.utc(2026, 9, 8),
  weekdays: [2],
  incrementKg: 1,
);

void main() {
  const renderDir = String.fromEnvironment('ADVANCED_WORKOUT_RENDER_DIR');
  var fontsLoaded = false;
  late Directory temporary;
  late File file;
  late TrainingController controller;
  late ActiveTrainingPlan plan;
  var now = DateTime.utc(2026, 9, 8, 12);

  setUp(() async {
    now = DateTime.utc(2026, 9, 8, 12);
    temporary = await Directory.systemTemp.createTemp('advanced-workout-');
    file = File('${temporary.path}/state.json');
    plan = advancedWorkoutPlan();
    await LocalTrainingStore(
      file,
    ).save(TrainingAppState(onboarded: true, activePlan: plan));
    controller = TrainingController(
      store: LocalTrainingStore(file),
      now: () => now,
      loadPrograms: () async => [plan.program],
    );
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await temporary.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Widget? home,
    bool readOnly = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    if (renderDir.isNotEmpty && !fontsLoaded) {
      await tester.runAsync(() async {
        for (final family in ['IBM Plex Sans KR', 'IBM Plex Mono']) {
          final stem = family == 'IBM Plex Sans KR'
              ? 'IBMPlexSansKR'
              : 'IBMPlexMono';
          final loader = FontLoader(family);
          for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
            loader.addFont(rootBundle.load('assets/fonts/$stem-$weight.ttf'));
          }
          await loader.load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      fontsLoaded = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('advanced-capture'),
            child: child!,
          ),
        ),
        home:
            home ??
            WorkoutScreen(
              controller: controller,
              session: plan.sessions.single,
              readOnly: readOnly,
            ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('advanced-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(renderDir).create(recursive: true);
      await File(
        '$renderDir/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (!controller.saving && !controller.restTimer.saving) break;
    }
    await tester.pumpAndSettle();
    expect(controller.saving, isFalse);
    expect(controller.restTimer.saving, isFalse);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 100,
    );
    await tester.ensureVisible(finder);
    await flush(tester);
    await tester.tap(finder);
    await tester.pump();
    await flush(tester);
  }

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Future<void> record(WidgetTester tester) async {
    await tester.enterText(input('set-weight'), '20');
    await tester.enterText(input('set-repetitions'), '3');
    await tap(tester, find.text('저장하고 다음 세트'));
    await flush(tester);
  }

  Future<void> completeAll(WidgetTester tester) async {
    await tester.runAsync(
      () => controller.update((state) {
        for (final entry in plan.sessions.single.executionSets) {
          state = state.withSetActual(
            entry.set.id,
            SetActual.completed(
              weight: 20,
              unit: WeightUnit.kg,
              repetitions: 3,
            ),
          );
        }
        return state;
      }),
    );
  }

  testWidgets(
    'AMRAP instructions keep actual input empty and permit fewer than reference reps',
    (tester) async {
      await pump(tester);
      await tap(tester, find.byType(WorkoutSetRow).first);
      expect(find.textContaining('기준 반복은 최소 완료 조건'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(input('set-repetitions')).controller!.text,
        isEmpty,
      );
      expect(controller.state.setActuals, isEmpty);
      await capture(tester, 'amrap-editor');
      await record(tester);
      final first = plan.sessions.single.executionSets.first.set;
      expect(controller.state.setActuals[first.id]!.repetitions, 3);
      expect(find.text('검증 운동 2 · 1세트'), findsOneWidget);
      final restored = await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      );
      expect(
        restored!.activePlan!.sessions.single.executionSets.first.set.isAmrap,
        isTrue,
      );
      expect(restored.setActuals[first.id]!.repetitions, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('next set follows superset rounds and skips completed sets', (
    tester,
  ) async {
    final b = plan.sessions.single.exercises[1].sets.first;
    await tester.runAsync(
      () => controller.update(
        (s) => s.withSetActual(b.id, const SetActual.skipped()),
      ),
    );
    await pump(tester);
    await tap(tester, find.byType(WorkoutSetRow).first);
    await record(tester);
    expect(find.text('검증 운동 1 · 2세트'), findsOneWidget);
    expect(controller.state.setActuals[b.id]!.status, SetActualStatus.skipped);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'positive prescribed rest starts explicitly, pauses, resumes and cancels replacement',
    (tester) async {
      await completeAll(tester);
      await pump(tester);
      expect(controller.restTimer.snapshot, isNull);
      expect(
        find.byKey(
          ValueKey(
            'rest-start-${plan.sessions.single.exercises.first.sets.first.id}',
          ),
        ),
        findsNothing,
      );
      final target = plan.sessions.single.exercises[1].sets.first;
      await tap(tester, find.byKey(ValueKey('rest-start-${target.id}')));
      await flush(tester);
      expect(
        find.byKey(const ValueKey('rest-time')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('01:30'), findsOneWidget);
      now = now.add(const Duration(seconds: 25));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:05'), findsOneWidget);
      await tap(tester, find.widgetWithText(TextButton, '휴식 일시정지'));
      await flush(tester);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:05'), findsOneWidget);
      await tap(tester, find.text('휴식 재개'));
      await flush(tester);
      final before = controller.restTimer.snapshot!.toJson();
      await tap(tester, find.byKey(ValueKey('rest-start-${target.id}')));
      expect(find.text('진행 중인 휴식을 바꿀까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(controller.restTimer.snapshot!.toJson(), before);
      await tap(tester, find.text('휴식 종료'));
      await flush(tester);
      expect(controller.restTimer.snapshot, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'bottom set exposes timer failure and retry without changing workout records',
    (tester) async {
      plan = advancedWorkoutPlan(long: true);
      await tester.runAsync(
        () => controller.update((_) => TrainingAppState(activePlan: plan)),
      );
      await completeAll(tester);
      final before = controller.state.toJson();
      await tester.runAsync(
        () => Directory('${controller.restTimer.store.file.path}.tmp').create(),
      );
      await pump(tester);
      final bottom = plan.sessions.single.exercises.last.sets.last;
      await tap(tester, find.byKey(ValueKey('rest-start-${bottom.id}')));
      await flush(tester);
      expect(find.text('타이머 저장 재시도').hitTestable(), findsOneWidget);
      expect(controller.restTimer.snapshot, isNull);
      expect(controller.state.toJson(), before);
      await capture(tester, 'timer-save-failure');
      await tester.runAsync(
        () => Directory('${controller.restTimer.store.file.path}.tmp').delete(),
      );
      now = now.add(const Duration(seconds: 12));
      await tap(tester, find.text('타이머 저장 재시도'));
      await flush(tester);
      expect(find.text('01:18'), findsOneWidget);
      expect(find.text('휴식 중').hitTestable(), findsOneWidget);
      expect(controller.state.toJson(), before);
      await capture(tester, 'timer-running');
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('휴식 시간이 끝났어요'), findsOneWidget);
      await tap(tester, find.text('휴식 확인'));
      await flush(tester);
      expect(controller.restTimer.snapshot, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('program detail shows authored advanced instructions', (
    tester,
  ) async {
    await pump(
      tester,
      home: ProgramDetailScreen(controller: controller, program: plan.program),
    );
    await tester.scrollUntilVisible(find.textContaining('AMRAP · 기준 8회'), 200);
    expect(find.textContaining('AMRAP · 기준 8회'), findsOneWidget);
    expect(find.textContaining('슈퍼세트 상체', findRichText: true), findsWidgets);
    expect(find.textContaining('세트 후 휴식 0초', findRichText: true), findsWidgets);
    await capture(tester, 'program-details');
  });
  testWidgets(
    'large text and keyboard keep advanced instructions scrollable and archived timer disabled',
    (tester) async {
      await completeAll(tester);
      await pump(tester, scale: 1.5, readOnly: true);
      expect(find.textContaining('휴식 시작'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'workout-large');
      await pump(tester, scale: 1.5);
      await tap(tester, find.byType(WorkoutSetRow).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tap(tester, input('set-repetitions'));
      expect(input('set-repetitions').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'amrap-keyboard-large');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
