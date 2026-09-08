import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/settings_controller.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_settings_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/app_settings.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/rest_timer.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/workout_screen.dart';
import 'training_program_fixtures.dart';

void main() {
  const renderDir = String.fromEnvironment('REST_AUTO_RENDER_DIR');
  var fontsLoaded = false;
  late Directory directory;
  late File file;
  late TrainingController controller;
  late SettingsController settings;
  late ActiveTrainingPlan plan;
  final now = DateTime.utc(2026, 9, 10, 12);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rest-auto-ui-');
    file = File('${directory.path}/state.json');
    plan = fixturePlan();
    await LocalTrainingStore(file).save(TrainingAppState(activePlan: plan));
    controller = TrainingController(
      store: LocalTrainingStore(file),
      now: () => now,
      loadPrograms: () async => [],
    );
    await controller.initialize();
    settings = SettingsController(
      store: LocalSettingsStore(File('${directory.path}/settings.json')),
    );
    await settings.initialize();
    await settings.update(
      const AppSettings(defaultRestSeconds: 90, autoStartRestTimer: true),
    );
  });
  tearDown(() async {
    controller.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (!controller.saving &&
          !controller.restTimer.saving &&
          !settings.saving) {
        break;
      }
    }
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 350));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> pump(WidgetTester tester) async {
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('rest-auto-capture'),
          child: child!,
        ),
        home: SettingsScope(
          controller: settings,
          child: WorkoutScreen(
            controller: controller,
            session: plan.sessions.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('rest-auto-capture')),
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 60,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await flush(tester);
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Future<void> openSet(WidgetTester tester, int index) async {
    await tap(tester, find.byType(WorkoutSetRow).at(index));
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(field('set-weight'), '20');
    await flush(tester);
    await tester.enterText(field('set-repetitions'), '5');
    await flush(tester);
  }

  Future<void> complete(WidgetTester tester, int index) async {
    await openSet(tester, index);
    await fill(tester);
    await tap(tester, find.text('세트 완료'));
  }

  testWidgets(
    'durable new completion starts custom timer once and page re-entry preserves deadline',
    (tester) async {
      await pump(tester);
      await complete(tester, 0);
      final timer = controller.restTimer.available!;
      expect(timer.durationSeconds, 90);
      expect(timer.durationSource, RestDurationSource.userDefault);
      expect(
        controller.state.setActuals[timer.setId]!.status,
        SetActualStatus.completed,
      );
      final deadline = timer.endsAt;
      await capture(tester, 'auto-start-completed');
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(controller.restTimer.available!.endsAt, deadline);
      await tester.runAsync(
        () => settings.update(
          const AppSettings(defaultRestSeconds: 120, autoStartRestTimer: true),
        ),
      );
      expect(controller.restTimer.available!.durationSeconds, 90);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'automatic off preserves manual fallback and explicit zero suppresses fallback',
    (tester) async {
      await tester.runAsync(
        () => settings.update(const AppSettings(defaultRestSeconds: 90)),
      );
      await pump(tester);
      await complete(tester, 0);
      expect(controller.restTimer.snapshot, isNull);
      final set = plan.sessions.first.exercises.single.sets.first;
      expect(find.byKey(ValueKey('rest-start-${set.id}')), findsOneWidget);
      expect(find.text('1세트 휴식 시작 · 90초'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final json =
          jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>;
      for (final session in json['program']['sessions']) {
        for (final exercise in session['exercises']) {
          for (final set in exercise['sets']) {
            set['restSeconds'] = 0;
          }
        }
      }
      plan = ActiveTrainingPlan.fromJson(json);
      await tester.runAsync(
        () => controller.update((_) => TrainingAppState(activePlan: plan)),
      );
      await tester.runAsync(
        () => settings.update(
          const AppSettings(defaultRestSeconds: 90, autoStartRestTimer: true),
        ),
      );
      await pump(tester);
      await complete(tester, 0);
      expect(controller.restTimer.available, isNull);
      expect(find.byKey(ValueKey('rest-start-${set.id}')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'existing completed record edit never starts a new automatic interval',
    (tester) async {
      final set = plan.sessions.first.exercises.single.sets.first;
      await tester.runAsync(
        () => controller.update(
          (s) => s.withSetActual(
            set.id,
            SetActual.completed(
              weight: 10,
              unit: WeightUnit.kg,
              repetitions: 5,
              performedDate: DateTime.utc(2026, 9, 10),
            ),
          ),
        ),
      );
      await pump(tester);
      await openSet(tester, 0);
      await tester.enterText(field('set-weight'), '21');
      await flush(tester);
      await tap(tester, find.text('수정한 기록 저장'));
      expect(controller.state.setActuals[set.id]!.weight, 21);
      expect(controller.restTimer.snapshot, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a running timer requires explicit replacement and cancel preserves both actuals',
    (tester) async {
      await pump(tester);
      await complete(tester, 0);
      final original = controller.restTimer.available!.toJson();
      await complete(tester, 1);
      expect(find.text('진행 중인 휴식을 바꿀까요?'), findsOneWidget);
      await capture(tester, 'auto-replacement-confirmation');
      await tester.tap(find.text('취소'));
      await flush(tester);
      expect(controller.restTimer.available!.toJson(), original);
      expect(controller.state.setActuals, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed workout save starts no timer until first durable completion retry',
    (tester) async {
      await pump(tester);
      await openSet(tester, 0);
      await fill(tester);
      final savedFile = File('${file.path}.before-failure');
      await tester.runAsync(() async {
        await file.rename(savedFile.path);
        await Directory(file.path).create();
      });
      await tap(tester, find.text('세트 완료'));
      expect(controller.saveError, isNotNull);
      expect(controller.restTimer.snapshot, isNull);
      await tester.runAsync(() async {
        await Directory(file.path).delete();
        await savedFile.rename(file.path);
      });
      await tap(
        tester,
        find.descendant(
          of: find.byType(SetEditor),
          matching: find.text('저장 다시 시도'),
        ),
      );
      expect(controller.saveError, isNull);
      expect(controller.restTimer.available, isNotNull);
      final deadline = controller.restTimer.available!.endsAt;
      await tester.pump();
      await flush(tester);
      expect(controller.restTimer.available!.endsAt, deadline);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'timer write failure leaves workout complete and retry keeps original deadline',
    (tester) async {
      await tester.runAsync(
        () => Directory('${controller.restTimer.store.file.path}.tmp').create(),
      );
      await pump(tester);
      await complete(tester, 0);
      expect(controller.state.setActuals, hasLength(1));
      expect(controller.restTimer.snapshot, isNull);
      expect(controller.restTimer.saveError, isNotNull);
      final restored = await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      );
      expect(restored!.setActuals, hasLength(1));
      await tester.runAsync(
        () => Directory('${controller.restTimer.store.file.path}.tmp').delete(),
      );
      await tap(tester, find.text('타이머 저장 재시도'));
      expect(
        controller.restTimer.available!.endsAt,
        now.add(const Duration(seconds: 90)),
      );
      expect(controller.state.setActuals, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
