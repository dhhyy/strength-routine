import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/exercise_guides.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/exercise_guide_screen.dart';
import 'package:strength_routine/program_screen.dart';
import 'package:strength_routine/search_screen.dart';
import 'package:strength_routine/theme.dart';

void main() {
  const render = String.fromEnvironment('GUIDE_RENDER_DIR');
  var fontsLoaded = false;
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double scale = 1,
  }) async {
    if (render.isNotEmpty && !fontsLoaded) {
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
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('guide-render'),
            child: child!,
          ),
        ),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (render.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('guide-render')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(render).create(recursive: true);
      await File('$render/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('guide search opens offline instructions and glossary', (
    tester,
  ) async {
    await pump(tester, const ExerciseGuidesScreen());
    final query = find.byKey(const ValueKey('guide-search-query'));
    await tester.enterText(query, '랫풀다운');
    await tester.pumpAndSettle();
    expect(find.text('운동 가이드 1개'), findsOneWidget);
    await capture(tester, 'guide-search');
    await tester.tap(find.text('랫 풀다운', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('시작 자세'), findsOneWidget);
    expect(find.text('움직임'), findsOneWidget);
    await capture(tester, 'guide-detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색어 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('운동 용어 읽기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('AMRAP', findRichText: true),
      200,
    );
    expect(
      find.textContaining('기준 반복은 최소 합격선이 아니', findRichText: true),
      findsOneWidget,
    );
    await capture(tester, 'guide-glossary');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'empty search is recoverable and unknown name has no misleading action',
    (tester) async {
      await pump(tester, const ExerciseGuidesScreen());
      await tester.enterText(
        find.byKey(const ValueKey('guide-search-query')),
        '없는 운동',
      );
      await tester.pumpAndSettle();
      expect(find.text('가이드 검색 결과가 없어요'), findsOneWidget);
      await tester.tap(find.text('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('운동 가이드 24개'), findsOneWidget);
      await pump(
        tester,
        const Scaffold(body: ExerciseGuideLink(exerciseName: '스쿼트 변형')),
      );
      expect(find.text('이 종목은 등록된 가이드가 없어요.'), findsOneWidget);
      expect(find.text('운동 가이드 보기'), findsNothing);
    },
  );
  testWidgets(
    'source failure retains offline body and retry opens exact reviewed URI',
    (tester) async {
      var tries = 0;
      Uri? opened;
      final guide = exerciseGuides.first;
      await pump(
        tester,
        ExerciseGuideScreen(
          guide: guide,
          openSource: (uri) async {
            tries++;
            opened = uri;
            return tries > 1;
          },
        ),
      );
      await tester.scrollUntilVisible(find.text('출처 원문 열기'), 200);
      await tester.tap(find.text('출처 원문 열기'));
      await tester.pumpAndSettle();
      expect(find.text('출처 연결 실패'), findsOneWidget);
      expect(find.text(guide.movement, findRichText: true), findsOneWidget);
      await tester.ensureVisible(find.text('출처 다시 열기'));
      await tester.pumpAndSettle();
      await capture(tester, 'guide-link-failure');
      await tester.tap(find.text('출처 다시 열기'));
      await tester.pumpAndSettle();
      expect(find.text('출처 연결 실패'), findsNothing);
      expect(tries, 2);
      expect(opened, Uri.parse(guide.sourceUrl));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'opening disables duplicate tap and thrown platform error is recoverable',
    (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      await pump(
        tester,
        ExerciseGuideScreen(
          guide: exerciseGuides.first,
          openSource: (_) {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.scrollUntilVisible(find.text('출처 원문 열기'), 200);
      await tester.tap(find.text('출처 원문 열기'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(calls, 1);
      pending.completeError(StateError('platform unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('출처 연결 실패'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long guide and glossary remain readable with large Korean text',
    (tester) async {
      await pump(
        tester,
        ExerciseGuideScreen(guide: guideForExercise('덤벨 체스트 서포티드 로우')!),
        scale: 1.8,
      );
      await capture(tester, 'guide-detail-large');
      await tester.scrollUntilVisible(find.text('출처 원문 열기'), 250);
      await capture(tester, 'guide-source-large');
      expect(tester.takeException(), isNull);
      await pump(tester, const TrainingGlossaryScreen(), scale: 1.8);
      await tester.scrollUntilVisible(
        find.text('슈퍼세트', findRichText: true),
        250,
      );
      await capture(tester, 'guide-glossary-large');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search tab and actual program detail both connect to guides', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('guides-navigation-'),
    ))!;
    final programs = (await tester.runAsync(() => loadBundledPrograms()))!;
    final controller = TrainingController(
      store: LocalTrainingStore(File('${directory.path}/state.json')),
      loadPrograms: () async => programs,
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    addTearDown(() => directory.delete(recursive: true));
    await pump(tester, SearchScreen(controller: controller));
    await tester.tap(find.text('운동·용어 가이드'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseGuidesScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(
      tester,
      ProgramDetailScreen(controller: controller, program: programs.first),
    );
    await tester.scrollUntilVisible(find.text('운동 가이드 보기').first, 200);
    await tester.tap(find.text('운동 가이드 보기').first);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseGuideScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
