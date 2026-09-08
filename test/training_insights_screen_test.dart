import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/theme.dart';
import 'package:strength_routine/training_insights_screen.dart';
import 'training_insights_fixtures.dart';

void main() {
  final captureKey = GlobalKey();
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_INSIGHTS')) return;
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

  Future<TrainingController> prepare(
    WidgetTester tester, {
    bool empty = false,
  }) async {
    final controller = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'insights-screen-',
      );
      final c = TrainingController(
        store: LocalTrainingStore(File('${directory.path}/state.json')),
        loadPrograms: () async => [],
      );
      await c.initialize();
      if (!empty) await c.update((_) => insightsState());
      return c;
    }))!;
    addTearDown(() async {
      controller.dispose();
      await controller.store.file.parent.delete(recursive: true);
    });
    return controller;
  }

  Future<void> pump(
    WidgetTester tester,
    TrainingController controller, {
    bool showSuggestions = true,
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
          home: TrainingInsightsScreen(
            controller: controller,
            now: () => insightsToday,
            showSuggestions: showSuggestions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester, TrainingController controller) async {
    for (var attempt = 0; attempt < 200 && controller.saving; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(controller.saving, isFalse);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    // 대화상자 전환만 진행한다. 실제 파일 I/O는 flush의 runAsync에서 기다린다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_INSIGHTS')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/strength-insights-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('빈 기록에는 가상 추세나 감량 제안을 만들지 않는다', (tester) async {
    final controller = await prepare(tester, empty: true);
    await pump(tester, controller);
    expect(find.text('아직 프로그램 기록이 없어요'), findsOneWidget);
    expect(find.text('변경 내용 확인'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('변경 목록 취소는 원본을 보존하고 적용·복원·되돌리기를 저장한다', (tester) async {
    final controller = await prepare(tester);
    final initial = controller.state.toJson();
    await pump(tester, controller);
    await capture(tester, 'proposal');
    await tap(tester, '변경 내용 확인');
    expect(find.text('100 → 95 kg'), findsNWidgets(6));
    await capture(tester, 'review');
    await tap(tester, '취소');
    expect(controller.state.toJson(), initial);
    await tap(tester, '변경 내용 확인');
    await tap(tester, '적용하기');
    await flush(tester, controller);
    expect(controller.state.loadAdjustments.length, 1);
    final future =
        controller.state.activePlan!.sessions[3].exercises.single.sets.first;
    expect(controller.state.effectiveTargetKg(future), 95);
    final restored = (await tester.runAsync(
      () => LocalTrainingStore(controller.store.file).load(),
    ))!;
    expect(restored.toJson(), controller.state.toJson());
    final reopened = (await tester.runAsync(() async {
      final c = TrainingController(
        store: LocalTrainingStore(controller.store.file),
        loadPrograms: () async => [],
      );
      await c.initialize();
      return c;
    }))!;
    addTearDown(reopened.dispose);
    await pump(tester, reopened);
    await tap(tester, '조정 되돌리기');
    expect(find.text('95 → 100 kg'), findsNWidgets(6));
    await tap(tester, '되돌리기');
    await flush(tester, reopened);
    expect(reopened.state.effectiveTargetKg(future), 100);
    final undone = (await tester.runAsync(
      () => LocalTrainingStore(controller.store.file).load(),
    ))!;
    expect(undone.loadAdjustments.single.isUndone, isTrue);
    expect(undone.activePlan!.toJson(), controller.state.activePlan!.toJson());
    expect(find.text('변경 내용 확인'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('적용·되돌리기 저장 실패는 메모리를 유지하고 재시도로 이력을 한 번 저장한다', (tester) async {
    final controller = await prepare(tester);
    final file = controller.store.file;
    await pump(tester, controller);
    await tap(tester, '변경 내용 확인');
    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tap(tester, '적용하기');
    await flush(tester, controller);
    expect(controller.saveError, isNotNull);
    expect(controller.state.loadAdjustments.length, 1);
    expect(find.text('저장 다시 시도'), findsOneWidget);
    await tester.runAsync(() => Directory(file.path).delete());
    await tap(tester, '저장 다시 시도');
    await flush(tester, controller);
    expect(controller.saveError, isNull);
    expect(
      (await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      ))!.loadAdjustments.length,
      1,
    );
    await tap(tester, '조정 되돌리기');
    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tap(tester, '되돌리기');
    await flush(tester, controller);
    expect(controller.saveError, isNotNull);
    expect(controller.state.loadAdjustments.single.isUndone, isTrue);
    await tester.runAsync(() => Directory(file.path).delete());
    await tap(tester, '저장 다시 시도');
    await flush(tester, controller);
    expect(
      (await tester.runAsync(
        () => LocalTrainingStore(file).load(),
      ))!.loadAdjustments.single.isUndone,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('제안 표시를 꺼도 적용 이력·되돌리기와 큰 글자 추세를 확인한다', (tester) async {
    final controller = await prepare(tester);
    final proposal = buildTrainingInsights(
      controller.state,
      planId: controller.state.activePlan!.id,
      asOf: insightsToday,
    ).single.suggestion!;
    await tester.runAsync(
      () => controller.update(
        (state) => state.withLoadAdjustment(proposal, asOf: insightsToday),
      ),
    );
    await pump(tester, controller, showSuggestions: false, scale: 1.5);
    expect(find.text('변경 내용 확인'), findsNothing);
    await tester.ensureVisible(find.text('조정 되돌리기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '조정 되돌리기'),
          )
          .onPressed,
      isNotNull,
    );
    await capture(tester, 'history-large');
    await tester.ensureVisible(find.text('평균 RIR 1 · 2세트 입력').first);
    await tester.pumpAndSettle();
    await capture(tester, 'trend-large');
    expect(tester.takeException(), isNull);
  });

  testWidgets('기록이 생긴 대상은 되돌리기를 비활성화하고 이유를 보인다', (tester) async {
    final controller = await prepare(tester);
    final proposal = buildTrainingInsights(
      controller.state,
      planId: controller.state.activePlan!.id,
      asOf: insightsToday,
    ).single.suggestion!;
    final futureId = proposal.afterKg.keys.first;
    await tester.runAsync(
      () => controller.update(
        (state) => state
            .withLoadAdjustment(proposal, asOf: insightsToday)
            .withSetDraft(futureId, {'weight': '95'}),
      ),
    );
    await pump(tester, controller);
    await tester.ensureVisible(find.text('조정 되돌리기'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '조정 되돌리기'),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('기록·초안이 있는 세트는 바꾸지 않아요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
