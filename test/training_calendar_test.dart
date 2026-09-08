import 'dart:convert';
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
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/training_screens.dart';
import 'package:strength_routine/workout_screen.dart';

import 'training_program_fixtures.dart';

void main() {
  const renderDirectory = String.fromEnvironment('SESSION_CALENDAR_RENDER_DIR');
  var fontsLoaded = false;
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
      now: () => today,
    );
    controller.loading = false;
  });

  tearDown(() async {
    controller.dispose();
    await temporary.delete(recursive: true);
  });

  Future<void> restoreCalendar(
    WidgetTester tester,
    TrainingAppState state, {
    double textScale = 1,
  }) async {
    if (renderDirectory.isNotEmpty && !fontsLoaded) {
      await tester.runAsync(() async {
        for (final family in ['IBM Plex Sans KR', 'IBM Plex Mono']) {
          final loader = FontLoader(family);
          final stem = family == 'IBM Plex Sans KR'
              ? 'IBMPlexSansKR'
              : 'IBMPlexMono';
          for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
            loader.addFont(rootBundle.load('assets/fonts/$stem-$weight.ttf'));
          }
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      fontsLoaded = true;
    }
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(
            key: const ValueKey('calendar-render'),
            child: child!,
          ),
        ),
        home: SavedRecordsScreen(controller: controller, today: today),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> captureCalendar(WidgetTester tester, String name) async {
    if (renderDirectory.isEmpty) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('calendar-render')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(renderDirectory).create(recursive: true);
      await File(
        '$renderDirectory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
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
    await tester.pumpAndSettle();
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
    await openDate(tester, '9월 9일, 운동 기록 있음', '운동 기록하기');
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
    await openDate(tester, '9월 9일, 운동 기록 있음', '기록 확인하기');
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

  testWidgets('모든 세트를 제외해도 실제 운동 완료로 표시하지 않는다', (tester) async {
    final session = plan.sessions.first;
    var state = TrainingAppState(onboarded: true, activePlan: plan);
    for (final set in session.exercises.expand((e) => e.sets)) {
      state = state.withSetActual(set.id, SetActual.skipped());
    }
    controller.state = state;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: ActiveTodayScreen(controller: controller, today: session.date),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('운동 완료'), findsNothing);
    expect(find.text('모든 세트 기록됨'), findsOneWidget);
    expect(find.text('실제 수행 0세트 · 제외 3세트'), findsOneWidget);
  });

  testWidgets('중량 0의 실제 수행과 제외를 따로 집계한다', (tester) async {
    final session = plan.sessions.first;
    final sets = session.exercises.single.sets;
    controller.state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetActual(
          sets[0].id,
          SetActual.completed(
            weight: 0,
            unit: WeightUnit.kg,
            repetitions: 5,
            rir: 0,
          ),
        )
        .withSetActual(sets[1].id, SetActual.skipped());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: ActiveTodayScreen(controller: controller, today: session.date),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('필수 세트 기록됨'), findsOneWidget);
    expect(find.text('실제 수행 1세트 · 제외 1세트'), findsOneWidget);
    expect(find.text('운동 완료'), findsNothing);
  });

  testWidgets('프로그램 교체 후 재실행해도 보관 초안 원문을 열람한다', (tester) async {
    final set = plan.sessions.first.exercises.single.sets.first;
    final next = createActivePlan(
      id: 'next-plan',
      program: fixtureProgram(),
      startDate: DateTime.utc(2026, 9, 21),
      weekdays: [1, 3],
      incrementKg: 2.5,
      baselines: plan.baselines,
    );
    final state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetDraft(set.id, {
          'weight': '87.',
          'repetitions': '4',
          'rir': '-',
          'unit': 'lb',
          'note': '이전 프로그램의 미완성 입력',
        })
        .withActivePlan(next);
    await restoreCalendar(tester, state);
    await openDate(tester, '9월 9일, 운동 기록 있음', '기록 확인하기');
    expect(
      tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).readOnly,
      isTrue,
    );
    await tester.tap(find.byType(WorkoutSetRow).first);
    await tester.pumpAndSettle();
    expect(find.text('작성 중인 초안 · 읽기 전용'), findsOneWidget);
    expect(find.text('87.'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('이전 프로그램의 미완성 입력'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(controller.state.toJson(), state.toJson());
    expect(
      (await tester.runAsync(() => LocalTrainingStore(file).load()))!.toJson(),
      state.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('수행일 달력은 확인된 날짜만 표시하고 여러 날의 같은 세션을 유지한다', (tester) async {
    final session = plan.sessions.first;
    final sets = session.exercises.single.sets;
    var state = TrainingAppState(onboarded: true, activePlan: plan);
    for (var i = 0; i < sets.length; i++) {
      state = state.withSetActual(
        sets[i].id,
        SetActual.completed(
          weight: i == 0 ? 0 : 40,
          unit: WeightUnit.kg,
          repetitions: 5,
          performedDate: i == 2 ? null : DateTime.utc(2026, 9, 10 + i),
        ),
      );
    }
    state = state.withSetActual(
      plan.sessions[1].exercises.single.sets.first.id,
      const SetActual.skipped(),
    );
    await restoreCalendar(tester, state, textScale: 1.5);
    await tester.tap(find.text('수행일'));
    await tester.pumpAndSettle();
    await captureCalendar(tester, 'performed-calendar-large');
    expect(find.text('수행일 미상 1세트는 예정일 보기에서 확인할 수 있어요.'), findsOneWidget);
    for (final day in [10, 11]) {
      final date = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '9월 $day일, 실제 수행 있음',
      );
      expect(date, findsOneWidget);
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.text(session.title), findsOneWidget);
      expect(find.text('선택한 날 실제 수행 1세트'), findsOneWidget);
      expect(find.text('세션 전체 · 실제 수행 3세트 · 제외 0세트'), findsOneWidget);
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '9월 9일, 실제 수행 있음',
      ),
      findsNothing,
    );
    expect(controller.state.toJson(), state.toJson());
    await tester.ensureVisible(
      find.byKey(ValueKey('performed-on-${session.id}')),
    );
    await tester.pumpAndSettle();
    await captureCalendar(tester, 'performed-session-large');
    expect(tester.takeException(), isNull);
  });

  testWidgets('모두 제외한 마감은 수행일 달력에 운동일을 만들지 않는다', (tester) async {
    final session = plan.sessions.first;
    var state = TrainingAppState(onboarded: true, activePlan: plan);
    for (final set in session.exercises.single.sets) {
      state = state.withSetActual(set.id, const SetActual.skipped());
    }
    state = state.closeSession(session.id, eventId: 'close', at: today);
    await restoreCalendar(tester, state);
    await tester.tap(find.text('수행일'));
    await tester.pumpAndSettle();
    expect(find.text('확인된 실제 수행이 없어요'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.contains('실제 수행 있음') == true,
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.text('예정일'));
    await tester.tap(find.text('예정일'));
    await tester.pumpAndSettle();
    final date = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '9월 9일, 운동 기록 있음',
    );
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(find.text('기록 마침'), findsOneWidget);
    expect(find.text('실제 수행 0세트 · 제외 3세트'), findsOneWidget);
    expect(controller.state.toJson(), state.toJson());
  });

  testWidgets('지난 필수 기록이 충족됐어도 명시 마감 전에는 오늘 화면에서 다시 찾는다', (tester) async {
    final session = plan.sessions.last;
    var state = TrainingAppState(onboarded: true, activePlan: plan);
    for (final set in session.exercises.single.sets) {
      state = state.withSetActual(set.id, const SetActual.skipped());
    }
    controller.state = state;
    final afterPlan = DateTime.utc(2026, 9, 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: ActiveTodayScreen(controller: controller, today: afterPlan),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(session.title), findsOneWidget);
    expect(find.text('아직 기록을 마치지 않았어요'), findsOneWidget);
    controller.state = state.closeSession(
      session.id,
      eventId: 'close',
      at: afterPlan,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: ActiveTodayScreen(controller: controller, today: afterPlan),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(session.title), findsNothing);
    expect(controller.state.isSessionClosed(session.id), isTrue);
  });

  testWidgets('이전 메모만 있는 보관 세션도 마감 미상과 메모를 다시 확인한다', (tester) async {
    final session = plan.sessions.first;
    final source = TrainingAppState(onboarded: true, activePlan: plan)
        .withSessionNote(session.id, '세트 없이 남겨 둔 이전 메모')
        .withActivePlan(fixturePlan(id: 'next-note-plan'));
    final legacyJson = source.toJson()
      ..remove('sessionEvents')
      ..remove('legacySessionIds');
    final migrated = TrainingAppState.fromJson(
      jsonDecode(jsonEncode(legacyJson)) as Map<String, dynamic>,
    );
    await restoreCalendar(tester, migrated);
    await openDate(tester, '9월 9일, 운동 기록 있음', '기록 확인하기');
    expect(
      tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).readOnly,
      isTrue,
    );
    expect(find.text('세트 없이 남겨 둔 이전 메모'), findsOneWidget);
    expect(controller.state.legacySessionIds, contains(session.id));
    expect(controller.state.toJson(), migrated.toJson());
    expect(controller.state.sessionEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
