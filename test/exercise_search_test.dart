import 'dart:async';
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
import 'package:strength_routine/search_screen.dart';
import 'package:strength_routine/theme.dart';

TrainingProgram program(String id, String title, String exerciseName) =>
    TrainingProgram(
      id: id,
      version: 'test-v1',
      title: title,
      trainerName: '검증 전용 작성자',
      description: '배포하지 않는 테스트 데이터',
      weeks: 1,
      sessions: [
        ProgramSession(
          id: 'session',
          week: 1,
          dayOrder: 1,
          title: '첫 번째 세션',
          exercises: [
            ProgramExercise(
              id: 'exercise',
              name: exerciseName,
              mainLift: MainLift.squat,
              sets: [
                ProgramSet(
                  id: 'percentage',
                  repetitions: 5,
                  rir: 2,
                  load: LoadPrescription.percentOfBaseline(MainLift.squat, 75),
                ),
                ProgramSet(
                  id: 'fixed',
                  repetitions: 8,
                  load: LoadPrescription.fixedKg(42.5),
                ),
                ProgramSet(
                  id: 'manual',
                  repetitions: 10,
                  isRequired: false,
                  load: const LoadPrescription.manual(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

ActiveTrainingPlan plan(String id, TrainingProgram source) => createActivePlan(
  id: id,
  program: source,
  startDate: DateTime.utc(2026, 9, 7),
  weekdays: [1],
  incrementKg: 2.5,
  baselines: {
    MainLift.squat: LiftBaseline(
      lift: MainLift.squat,
      kilograms: 100,
      source: BaselineSource.userEntered,
    ),
  },
);

void main() {
  late TrainingController controller;
  final captureKey = GlobalKey();

  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_SEARCH')) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
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
    }
  });

  setUp(() {
    controller = TrainingController(
      store: LocalTrainingStore(
        File('/private/tmp/unused-exercise-search.json'),
      ),
      loadPrograms: () async => [],
    )..loading = false;
  });

  tearDown(() => controller.dispose());

  Future<void> pumpSearch(WidgetTester tester) async {
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
          home: SearchScreen(controller: controller),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_SEARCH')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/strength-search-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder queryField() => find.descendant(
    of: find.byKey(const ValueKey('exercise-search-query')),
    matching: find.byType(TextFormField),
  );

  testWidgets('빈 카탈로그에는 가상 운동 대신 빈 상태를 보여준다', (tester) async {
    await pumpSearch(tester);
    await tester.pumpAndSettle();
    expect(find.text('검색할 운동이 없어요'), findsOneWidget);
    expect(find.text('백스쿼트'), findsNothing);
    expect(find.text('운동 구성 보기'), findsNothing);
    await capture(tester, 'empty');
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 이름도 프로그램별로 유지하고 검색어 지우기로 결과를 복구한다', (tester) async {
    controller.programs = [
      program('one', '첫 번째 프로그램', '스쿼트'),
      program('two', '두 번째 프로그램', '스쿼트'),
      program('third', '세 번째 프로그램', '벤치프레스'),
    ];
    final before = controller.state.toJson();
    await pumpSearch(tester);
    await tester.enterText(queryField(), '  스쿼트  ');
    await tester.pumpAndSettle();
    expect(find.text('프로그램별 운동 2개'), findsOneWidget);
    expect(find.text('첫 번째 프로그램'), findsOneWidget);
    expect(find.text('두 번째 프로그램'), findsOneWidget);
    expect(find.text('벤치프레스'), findsNothing);
    await tester.tap(find.text('운동 구성 보기').first);
    await tester.pumpAndSettle();
    expect(find.text('등록 프로그램 · 읽기 전용'), findsOneWidget);
    expect(
      find.text('원래 처방 · 스쿼트 기준 중량의 75%', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('이 계획의 목표', findRichText: true), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(queryField(), '찾을 수 없는 운동');
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    await tester.tap(find.text('검색어 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('프로그램별 운동 3개'), findsOneWidget);
    expect(controller.state.toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('목록 실패에도 보관/진행 계획을 검색하고 재시도로 카탈로그를 더한다', (tester) async {
    final active = plan('active', program('active-p', '진행 프로그램', '스쿼트'));
    final archived = plan('old', program('old-p', '보관 프로그램', '스쿼트'));
    final completer = Completer<List<TrainingProgram>>();
    controller.dispose();
    controller =
        TrainingController(
            store: LocalTrainingStore(
              File('/private/tmp/unused-exercise-search.json'),
            ),
            loadPrograms: () => completer.future,
          )
          ..loading = false
          ..catalogError = '목록 읽기 실패'
          ..state = TrainingAppState(
            activePlan: active,
            planHistory: [archived],
          );
    final before = controller.state.toJson();
    await pumpSearch(tester);
    await tester.pumpAndSettle();
    expect(find.text('기기에 있는 운동은 계속 검색할 수 있어요.'), findsOneWidget);
    expect(find.text('프로그램별 운동 2개'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('프로그램별 운동 2개'), findsOneWidget);
    completer.complete([program('catalog', '등록 프로그램 제목', '스쿼트')]);
    await tester.pumpAndSettle();
    expect(find.text('등록된 프로그램을 불러오지 못했어요'), findsNothing);
    expect(find.text('프로그램별 운동 3개'), findsOneWidget);
    expect(controller.state.toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 목록 로딩과 실패를 구분하며 실패 재시도를 처리한다', (tester) async {
    controller.dispose();
    controller = TrainingController(
      store: LocalTrainingStore(
        File('/private/tmp/unused-exercise-search.json'),
      ),
      loadPrograms: () async => throw const FormatException('bad catalog'),
    )..loading = false;
    final load = controller.refreshPrograms();
    await pumpSearch(tester);
    await load;
    await tester.pumpAndSettle();
    expect(find.text('등록된 프로그램을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('검색할 운동이 없어요'), findsNothing);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 프로그램을 불러오지 못했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('375 화면과 키보드에서 출처/세트를 열고 원래 처방과 계획 목표를 구분한다', (tester) async {
    const title = '검증 전용 · 긴 프로그램 제목도 줄바꿈되는지 확인';
    const name = '검증 전용 · 긴 운동 이름의 바벨 백스쿼트';
    final active = plan('active', program('active-p', title, name));
    controller.state = TrainingAppState(activePlan: active);
    final before = controller.state.toJson();
    await pumpSearch(tester);
    await tester.pumpAndSettle();
    await capture(tester, 'results');
    await tester.enterText(queryField(), '백스쿼트');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('운동 구성 보기'));
    expect(find.text('운동 구성 보기').hitTestable(), findsOneWidget);
    await tester.tap(find.text('운동 구성 보기'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('진행 중 계획 · 읽기 전용'), findsOneWidget);
    expect(find.text('검증 전용 작성자'), findsOneWidget);
    expect(
      find.text('원래 처방 · 스쿼트 기준 중량의 75%', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('이 계획의 목표 · 75 kg', findRichText: true), findsOneWidget);
    expect(find.text('5회 · RIR 2', findRichText: true), findsOneWidget);
    await capture(tester, 'detail');
    await tester.scrollUntilVisible(
      find.text('3세트 · 선택'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('원래 처방 · 중량 직접 기록', findRichText: true), findsOneWidget);
    expect(
      find.text('이 계획의 목표 · 중량 직접 기록', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(controller.state.toJson(), before);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(queryField()).controller!.text, '백스쿼트');
    expect(tester.takeException(), isNull);
  });
}
