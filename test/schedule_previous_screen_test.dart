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
import 'package:strength_routine/schedule_screen.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/training_screens.dart';
import 'package:strength_routine/workout_screen.dart';
import 'schedule_previous_fixtures.dart';

void main() {
  const renderDir = String.fromEnvironment('SCHEDULE_PREVIOUS_RENDER_DIR');
  var fontsLoaded = false;
  late Directory temp;
  late File file;
  late TrainingController controller;
  late ActiveTrainingPlan plan;
  var now = DateTime.utc(2026, 9, 8);
  setUp(() async {
    now = DateTime.utc(2026, 9, 8);
    temp = await Directory.systemTemp.createTemp('schedule-ui-');
    file = File('${temp.path}/state.json');
    plan = scheduleFixture();
    await LocalTrainingStore(file).save(TrainingAppState(activePlan: plan));
    controller = TrainingController(
      store: LocalTrainingStore(file),
      now: () => now,
      loadPrograms: () async => [],
    );
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await temp.delete(recursive: true);
  });
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (!controller.saving && !controller.sessionActionPending) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 100,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await flush(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
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

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Future<void> chooseDate(WidgetTester tester) async {
    await tap(
      tester,
      find.byKey(ValueKey('schedule-date-${plan.sessions.last.id}')),
    );
    await tester.tap(find.text('21'));
    await tester.tap(find.text('선택'));
    await flush(tester);
    await tap(tester, find.byKey(const ValueKey('schedule-review')));
  }

  Future<void> source(WidgetTester tester, {bool draft = false}) async {
    now = DateTime.utc(2026, 9, 20);
    await tester.runAsync(
      () => controller.update(
        (state) => TrainingAppState(
          activePlan: plan,
          setActuals: {
            plan.sessions.first.exercises.first.sets.first.id:
                SetActual.completed(
                  weight: 22.5,
                  unit: WeightUnit.lb,
                  repetitions: 7,
                  performedDate: DateTime.utc(2026, 9, 7),
                ),
          },
          setDrafts: draft
              ? {
                  plan.sessions.last.exercises.first.sets.first.id: {
                    'weight': '11',
                    'unit': 'kg',
                    'repetitions': '3',
                    'rir': ' 2.5 ',
                    'note': '내 메모 ',
                    'performedDate': '2026-09-19',
                  },
                }
              : {},
        ),
      ),
    );
  }

  Widget editor() => Scaffold(
    body: SetEditor(
      controller: controller,
      exerciseName: plan.sessions.last.exercises.first.name,
      set: plan.sessions.last.exercises.first.sets.first,
      number: 1,
    ),
  );

  testWidgets(
    'schedule date review is explicit and cancel preserves original',
    (tester) async {
      await pump(tester, ScheduleScreen(controller: controller));
      await chooseDate(tester);
      expect(find.text('변경 전후 확인'), findsOneWidget);
      expect(find.text('2026-09-21'), findsOneWidget);
      expect(
        controller.state.activePlan!.sessionDates[plan.sessions.last.id],
        DateTime.utc(2026, 9, 17),
      );
      await capture(tester, 'schedule-review');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        controller.state.activePlan!.sessionDates[plan.sessions.last.id],
        DateTime.utc(2026, 9, 17),
      );
    },
  );
  testWidgets('apply persists reviewed schedule and stale review is blocked', (
    tester,
  ) async {
    await pump(tester, ScheduleScreen(controller: controller));
    await chooseDate(tester);
    await tap(tester, find.byKey(const ValueKey('schedule-apply')));
    expect(find.text('open'), findsOneWidget);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(file).load(),
    );
    expect(
      restored!.activePlan!.sessionDates[plan.sessions.last.id],
      DateTime.utc(2026, 9, 21),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => controller.update((state) => state.copyWith(onboarded: true)),
    );
    await flush(tester);
    expect(find.text('기록이 바뀌었어요'), findsOneWidget);
    await tap(tester, find.text('최신 일정 다시 불러오기'));
    expect(find.text('기록이 바뀌었어요'), findsNothing);
  });
  testWidgets('schedule storage failure retains candidate for retry', (
    tester,
  ) async {
    await pump(tester, ScheduleScreen(controller: controller));
    await chooseDate(tester);
    await tester.runAsync(() async {
      await file.rename('${file.path}.original');
      await Directory(file.path).create();
    });
    await tap(tester, find.byKey(const ValueKey('schedule-apply')));
    expect(find.byKey(const ValueKey('schedule-error')), findsOneWidget);
    expect(
      controller.state.activePlan!.sessionDates[plan.sessions.last.id],
      DateTime.utc(2026, 9, 17),
    );
    await capture(tester, 'schedule-save-failure');
    await tester.runAsync(() async {
      await Directory(file.path).delete();
      await File('${file.path}.original').rename(file.path);
    });
    await tap(tester, find.byKey(const ValueKey('schedule-apply')));
    expect(
      controller.state.activePlan!.sessionDates[plan.sessions.last.id],
      DateTime.utc(2026, 9, 21),
    );
  });
  testWidgets(
    'large schedule text stays scrollable and missed workouts keep dates',
    (tester) async {
      await pump(tester, ScheduleScreen(controller: controller), scale: 1.5);
      await capture(tester, 'schedule-large');
      expect(tester.takeException(), isNull);
      now = DateTime.utc(2026, 9, 20);
      await pump(
        tester,
        MissedWorkoutsScreen(controller: controller, today: now),
        scale: 1.5,
      );
      await tap(tester, find.text('운동 기록하기').first);
      expect(find.text('2026-09-07'), findsOneWidget);
      expect(
        controller.state.activePlan!.sessions.first.date,
        DateTime.utc(2026, 9, 7),
      );
    },
  );
  testWidgets(
    'copy confirms provenance and overwrite, preserves raw fields and reloads draft',
    (tester) async {
      await source(tester, draft: true);
      await pump(tester, editor());
      final target = plan.sessions.last.exercises.first.sets.first.id;
      final original = controller.state.setDrafts[target];
      await tap(tester, find.byKey(const ValueKey('previous-record-open')));
      expect(find.text('2026-09-07'), findsOneWidget);
      expect(
        find.textContaining('22.5 lb', findRichText: true),
        findsOneWidget,
      );
      await capture(tester, 'previous-source');
      await tap(tester, find.text('이 기록 선택'));
      await tester.tap(find.text('취소'));
      await flush(tester);
      expect(controller.state.setDrafts[target], original);
      await tap(tester, find.byKey(const ValueKey('previous-record-open')));
      await tap(tester, find.text('이 기록 선택'));
      await tester.tap(
        find.byKey(const ValueKey('previous-overwrite-confirm')),
      );
      await flush(tester);
      final copied = controller.state.setDrafts[target]!;
      expect(copied, {
        ...original!,
        'weight': '22.5',
        'unit': 'lb',
        'repetitions': '7',
      });
      expect(controller.state.setActuals.containsKey(target), isFalse);
      final restored = await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      );
      expect(restored!.setDrafts[target], copied);
      await tap(tester, input('set-weight'));
      await capture(tester, 'previous-copied');
    },
  );
  testWidgets(
    'empty previous records and large source dialog remain readable',
    (tester) async {
      now = DateTime.utc(2026, 9, 20);
      await pump(tester, editor(), scale: 1.5);
      await tap(tester, find.byKey(const ValueKey('previous-record-open')));
      expect(find.textContaining('가져올 기록이 없어요'), findsOneWidget);
      await capture(tester, 'previous-empty-large');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기'));
      await flush(tester);
      await source(tester);
      await pump(tester, editor(), scale: 1.5);
      await tap(tester, find.byKey(const ValueKey('previous-record-open')));
      await capture(tester, 'previous-source-large');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'copy save failure retains new input and retry persists without completing',
    (tester) async {
      await source(tester);
      await pump(tester, editor());
      final target = plan.sessions.last.exercises.first.sets.first.id;
      await tester.runAsync(() async {
        await file.rename('${file.path}.original');
        await Directory(file.path).create();
      });
      await tap(tester, find.byKey(const ValueKey('previous-record-open')));
      await tap(tester, find.text('이 기록 선택'));
      expect(controller.saveError, isNotNull);
      expect(controller.state.setDrafts[target]!['weight'], '22.5');
      expect(controller.state.setActuals.containsKey(target), isFalse);
      await tester.runAsync(() async {
        await Directory(file.path).delete();
        await File('${file.path}.original').rename(file.path);
      });
      await tap(tester, find.text('저장 다시 시도'));
      final restored = await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      );
      expect(restored!.setDrafts[target]!['unit'], 'lb');
      expect(restored.setActuals.containsKey(target), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('review crossing midnight cannot move a now-current session', (
    tester,
  ) async {
    await pump(tester, ScheduleScreen(controller: controller));
    await chooseDate(tester);
    now = DateTime.utc(2026, 9, 17);
    await tap(tester, find.byKey(const ValueKey('schedule-apply')));
    expect(find.byKey(const ValueKey('schedule-error')), findsOneWidget);
    expect(
      controller.state.activePlan!.sessionDates[plan.sessions.last.id],
      DateTime.utc(2026, 9, 17),
    );
  });
  testWidgets('changed previous source is rejected after review', (
    tester,
  ) async {
    await source(tester);
    await pump(tester, editor());
    await tap(tester, find.byKey(const ValueKey('previous-record-open')));
    await tester.runAsync(
      () => controller.update(
        (state) => state.withSetActual(
          plan.sessions.first.exercises.first.sets.first.id,
          SetActual.completed(
            weight: 30,
            unit: WeightUnit.kg,
            repetitions: 4,
            performedDate: DateTime.utc(2026, 9, 7),
          ),
        ),
      ),
    );
    await tap(tester, find.text('이 기록 선택'));
    expect(find.text('이전 기록이 바뀌었어요. 다시 선택해 주세요.'), findsOneWidget);
    expect(controller.state.setDrafts, isEmpty);
  });
}
