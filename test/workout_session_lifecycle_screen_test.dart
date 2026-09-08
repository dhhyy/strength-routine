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
import 'package:strength_routine/flow_components.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/workout_screen.dart';

void main() {
  final captureKey = GlobalKey();
  late TrainingController controller;
  late Directory directory;
  late ActiveTrainingPlan plan;
  late DateTime clock;
  List<PlannedSet> getSets() => plan.sessions.single.exercises.single.sets;

  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_LIFECYCLE')) return;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['IBM Plex Sans KR', 'IBM Plex Mono']) {
      final file = family == 'IBM Plex Sans KR'
          ? 'IBMPlexSansKR'
          : 'IBMPlexMono';
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/$file-$weight.ttf'));
      }
      await loader.load();
    }
  });

  Future<void> prepare(WidgetTester tester, {bool resolved = false}) async {
    clock = DateTime.utc(2026, 9, 8, 9, 30);
    plan = createActivePlan(
      id: 'lifecycle-plan',
      program: TrainingProgram(
        id: 'lifecycle-fixture',
        version: '1',
        title: '화면 검증 프로그램',
        trainerName: '테스트',
        description: '제품에 배포하지 않는 예시',
        weeks: 1,
        sessions: [
          ProgramSession(
            id: 'day',
            week: 1,
            dayOrder: 1,
            title: '운동 기록 검증',
            exercises: [
              ProgramExercise(
                id: 'squat',
                name: '바벨 백스쿼트',
                sets: [
                  for (var i = 0; i < 3; i++)
                    ProgramSet(
                      id: 's$i',
                      repetitions: 5,
                      rir: 2,
                      isRequired: i < 2,
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
      incrementKg: 2.5,
    );
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('lifecycle-screen-');
      controller = TrainingController(
        store: LocalTrainingStore(File('${directory.path}/state.json')),
        loadPrograms: () async => [],
        now: () => clock,
      );
      await controller.initialize();
      var state = TrainingAppState(onboarded: true, activePlan: plan);
      if (resolved) {
        for (final set in getSets().take(2)) {
          state = state.withSetActual(set.id, const SetActual.skipped());
        }
      }
      await controller.update((_) => state);
    });
    addTearDown(() async {
      controller.dispose();
      await directory.delete(recursive: true);
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    bool readOnly = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildConsoleTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: WorkoutScreen(
            controller: controller,
            session: plan.sessions.single,
            readOnly: readOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester) async {
    for (
      var i = 0;
      i < 400 && (controller.saving || controller.sessionActionPending);
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(controller.saving || controller.sessionActionPending, isFalse);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        240,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> change(
    WidgetTester tester,
    TrainingAppState Function(TrainingAppState) transform,
  ) async {
    await tester.runAsync(() => controller.update(transform));
    await tester.pumpAndSettle();
  }

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Finder action(String text) =>
      find.descendant(of: find.byType(SetEditor), matching: find.text(text));
  Finder lifecycle() => find.byKey(const ValueKey('session-lifecycle-action'));
  Finder confirm() => find.byKey(const ValueKey('session-lifecycle-confirm'));
  Finder dialog() => find.byKey(const ValueKey('session-lifecycle-dialog'));

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_LIFECYCLE')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/strength-lifecycle-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('필수·초안을 해결해야 마감하며 전체 제외와 선택 미기록을 구분한다', (tester) async {
    await prepare(tester);
    await pump(tester);
    await tester.scrollUntilVisible(lifecycle(), 240);
    expect(tester.widget<PrimaryAction>(lifecycle()).onPressed, isNull);
    await change(
      tester,
      (state) => state
          .withSetActual(getSets()[0].id, const SetActual.skipped())
          .withSetActual(getSets()[1].id, const SetActual.skipped())
          .withSetDraft(getSets()[2].id, {'weight': '42.'}),
    );
    expect(tester.widget<PrimaryAction>(lifecycle()).onPressed, isNull);
    expect(find.text('필수 미기록 0세트 · 초안 1세트를 먼저 확인해 주세요.'), findsOneWidget);
    await change(tester, (state) => state.withSetDraft(getSets()[2].id, null));
    final before = controller.state.toJson();
    await tap(tester, lifecycle());
    expect(
      find.descendant(
        of: dialog(),
        matching: find.text('실제 수행 0세트', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog(),
        matching: find.text('제외 2세트', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog(),
        matching: find.text('미기록 1세트', findRichText: true),
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('취소'));
    expect(controller.state.toJson(), before);
    await tap(tester, lifecycle());
    await capture(tester, 'close-review');
    await tap(tester, confirm());
    await flush(tester);
    expect(controller.state.isSessionClosed(plan.sessions.single.id), isTrue);
    expect(
      controller.state.sessionSummary(plan.sessions.single.id).performedSets,
      0,
    );
    expect(controller.state.setActuals.containsKey(getSets()[2].id), isFalse);
    expect(
      controller.state.sessionEvents.single.kind,
      SessionLifecycleKind.closed,
    );
    expect(controller.state.completionNotified, isEmpty);
    expect(find.text('마감 시각 · 기기 시간'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마감한 세트는 막고 재개 취소는 유지하며 재개 성공 후 수정한다', (tester) async {
    await prepare(tester, resolved: true);
    await change(
      tester,
      (state) => state.closeSession(
        plan.sessions.single.id,
        eventId: 'initial-close',
        at: clock,
      ),
    );
    await pump(tester, scale: 1.5);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(find.byType(SetEditor), findsNothing);
    final before = controller.state.toJson();
    await tap(tester, lifecycle());
    await tap(tester, find.text('취소'));
    expect(controller.state.toJson(), before);
    await tester.ensureVisible(lifecycle());
    await capture(tester, 'closed-large');
    await tap(tester, lifecycle());
    await tap(tester, confirm());
    await flush(tester);
    expect(controller.state.isSessionClosed(plan.sessions.single.id), isFalse);
    expect(controller.state.sessionEvents.map((e) => e.kind), [
      SessionLifecycleKind.closed,
      SessionLifecycleKind.reopened,
    ]);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(find.byType(SetEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마감 검토는 실제 수행일 여러 개와 날짜 미상을 분리해 저장한다', (tester) async {
    await prepare(tester);
    await change(
      tester,
      (state) => state
          .withSetActual(
            getSets()[0].id,
            SetActual.completed(
              weight: 0,
              unit: WeightUnit.kg,
              repetitions: 5,
              performedDate: DateTime.utc(2026, 9, 6),
            ),
          )
          .withSetActual(
            getSets()[1].id,
            SetActual.completed(
              weight: 45,
              unit: WeightUnit.kg,
              repetitions: 5,
              performedDate: DateTime.utc(2026, 9, 7),
            ),
          )
          .withSetActual(
            getSets()[2].id,
            SetActual.completed(
              weight: 45,
              unit: WeightUnit.kg,
              repetitions: 5,
            ),
          ),
    );
    await pump(tester);
    await tap(tester, lifecycle());
    for (final label in [
      '실제 수행 3세트',
      '수행일 미상 1세트',
      '2026-09-06',
      '2026-09-07',
    ]) {
      expect(
        find.descendant(
          of: dialog(),
          matching: find.text(label, findRichText: true),
        ),
        findsOneWidget,
      );
    }
    await capture(tester, 'dated-review');
    await tap(tester, confirm());
    await flush(tester);
    final summary = controller.state.sessionEvents.single.summary;
    expect(summary.performedDates, [
      DateTime.utc(2026, 9, 6),
      DateTime.utc(2026, 9, 7),
    ]);
    expect(summary.unknownDateSets, 1);
    expect(summary.performedSets, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마감·재개 저장 실패는 원래 상태와 확인창을 유지하고 같은 시각으로 재시도한다', (tester) async {
    await prepare(tester, resolved: true);
    await pump(tester);
    for (final reopen in [false, true]) {
      final before = controller.state.toJson(), at = clock;
      final file = controller.store.file, backup = File('${file.path}.backup');
      await tester.runAsync(() async {
        await file.rename(backup.path);
        await Directory(file.path).create();
      });
      await tap(tester, lifecycle());
      await tap(tester, confirm());
      await flush(tester);
      expect(controller.state.toJson(), before);
      expect(dialog(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-lifecycle-error')),
        findsOneWidget,
      );
      expect(controller.saveError, isNull);
      await capture(tester, reopen ? 'reopen-error' : 'close-error');
      clock = clock.add(const Duration(minutes: 5));
      await tester.runAsync(() async {
        await Directory(file.path).delete();
        await backup.rename(file.path);
      });
      await tap(tester, confirm());
      await flush(tester);
      expect(dialog(), findsNothing);
      expect(controller.state.sessionEvents.last.at, at);
      expect(
        controller.state.isSessionClosed(plan.sessions.single.id),
        !reopen,
      );
      final restored = (await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      ))!;
      expect(restored.toJson(), controller.state.toJson());
    }
    expect(controller.state.sessionEvents.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy 날짜 미상은 날짜 지정 취소와 기록 수정 뒤에도 미상으로 남는다', (tester) async {
    await prepare(tester);
    await change(
      tester,
      (state) => state.withSetActual(
        getSets()[0].id,
        SetActual.completed(weight: 0, unit: WeightUnit.kg, repetitions: 5),
      ),
    );
    await pump(tester);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(find.text('날짜 지정'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('set-performed-date-picker')));
    await tap(tester, find.text('취소'));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('set-performed-date-value')))
          .data,
      '수행일 미상',
    );
    await tester.enterText(input('set-note'), '날짜를 추정하지 않는 수정');
    await flush(tester);
    expect(controller.state.setDrafts[getSets()[0].id]!['performedDate'], '');
    await tap(tester, action('수정한 기록 저장'));
    await flush(tester);
    final actual = controller.state.setActuals[getSets()[0].id]!;
    expect(actual.performedDate, isNull);
    expect(actual.recordedAt, isNull);
    expect(actual.updatedAt, clock);
    expect(actual.weight, 0);
    expect(find.text('수행일 미상'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('신규 수행일 초안을 복원하고 선택한 날짜와 입력·수정 시각을 저장한다', (tester) async {
    await prepare(tester);
    await pump(tester);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('set-performed-date-value')))
          .data,
      '2026-09-08',
    );
    await tap(tester, find.byKey(const ValueKey('set-performed-date-picker')));
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      DateTime(2026, 9, 8),
    );
    await tap(tester, find.text('7'));
    await tap(
      tester,
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('선택'),
      ),
    );
    await flush(tester);
    await tester.enterText(input('set-weight'), '42.');
    await flush(tester);
    await tap(tester, find.byTooltip('기록 초안 저장하고 닫기'));
    await flush(tester);
    final restored = (await tester.runAsync(
      () => LocalTrainingStore(controller.store.file).load(),
    ))!;
    expect(restored.setDrafts[getSets()[0].id]!['performedDate'], '2026-09-07');
    controller.state = restored;
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('set-performed-date-value')))
          .data,
      '2026-09-07',
    );
    await tester.enterText(input('set-repetitions'), '5');
    await flush(tester);
    await tap(tester, action('세트 완료'));
    await flush(tester);
    final actual = controller.state.setActuals[getSets()[0].id]!;
    expect(actual.performedDate, DateTime.utc(2026, 9, 7));
    expect(actual.recordedAt, clock);
    expect(actual.updatedAt, clock);
    expect(controller.state.setDrafts, isEmpty);
    clock = clock.add(const Duration(hours: 1));
    await tap(tester, find.byType(WorkoutSetRow).first);
    await tester.enterText(input('set-note'), '기존 최초 입력 시각 보존');
    await flush(tester);
    await tap(tester, action('수정한 기록 저장'));
    await flush(tester);
    final edited = controller.state.setActuals[getSets()[0].id]!;
    expect(edited.recordedAt, actual.recordedAt);
    expect(edited.updatedAt, clock);
    expect(edited.performedDate, actual.performedDate);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잘못된 날짜와 미래 날짜 초안은 완료를 차단하고 원문을 보존한다', (tester) async {
    await prepare(tester);
    for (final date in ['2026-02-30', '2026-09-09']) {
      await change(
        tester,
        (state) => state.withSetDraft(getSets()[0].id, {
          'weight': '40',
          'repetitions': '5',
          'performedDate': date,
        }),
      );
      await pump(tester);
      await tap(tester, find.byType(WorkoutSetRow).first);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('set-performed-date-value')),
            )
            .data,
        date,
      );
      await tap(tester, action('세트 완료'));
      await tester.pumpAndSettle();
      expect(controller.state.setActuals, isEmpty);
      expect(
        controller.state.setDrafts[getSets()[0].id]!['performedDate'],
        date,
      );
      expect(
        find.text(
          date == '2026-02-30' ? '실제 수행일 형식을 확인해 주세요.' : '오늘 이후 날짜는 선택할 수 없어요.',
        ),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('기록 초안 저장하고 닫기'));
      await flush(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('보관·미래 readOnly는 요약만 보고 마감·수정하지 않는다', (tester) async {
    await prepare(tester, resolved: true);
    await pump(tester, readOnly: true);
    expect(lifecycle(), findsNothing);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(find.byType(SetEditor), findsNothing);
    final state = controller.state;
    controller.state = TrainingAppState(
      onboarded: true,
      planHistory: [plan],
      setActuals: state.setActuals,
      sessionNotes: {plan.sessions.single.id: '이전 세션의 메모\n원문 확인'},
    );
    await pump(tester);
    expect(find.text('이전 세션의 메모\n원문 확인'), findsOneWidget);
    expect(lifecycle(), findsNothing);
    await tap(tester, find.byType(WorkoutSetRow).first);
    expect(find.byType(SetEditor), findsNothing);
    expect(controller.state.sessionEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('375px 큰 글자와 키보드에서도 수행일과 저장·닫기를 확인한다', (tester) async {
    await prepare(tester);
    await pump(tester, scale: 1.5);
    await tap(tester, find.byType(WorkoutSetRow).first);
    await capture(tester, 'editor-large');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    for (final finder in [
      find.byKey(const ValueKey('set-performed-date-picker')),
      action('세트 완료'),
      find.byTooltip('기록 초안 저장하고 닫기'),
    ]) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget);
    }
    await capture(tester, 'keyboard-large');
    expect(tester.takeException(), isNull);
  });
}
