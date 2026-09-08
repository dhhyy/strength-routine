import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/detailed_routine_screen.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';

// 화면·저장 동작 확인용 합성 자료이며 사용자 프로그램 처방이 아니다.
TrainingProgram _program({String version = '1'}) => TrainingProgram(
  id: 'advanced-ui-fixture',
  version: version,
  title: '고급 편집 검증 자료',
  trainerName: '검증용',
  description: '실제 운동 프로그램이 아닌 화면 검증 자료입니다.',
  weeks: 1,
  sessions: [
    ProgramSession(
      id: 'session-1',
      week: 1,
      dayOrder: 1,
      title: '합성 세션',
      exercises: [
        for (var i = 1; i <= 2; i++)
          ProgramExercise(
            id: 'exercise-$i',
            name: '검증 운동 $i',
            sets: [
              ProgramSet(
                id: 'set-1',
                repetitions: 8,
                rir: 2,
                load: const LoadPrescription.manual(),
              ),
            ],
          ),
      ],
    ),
  ],
);

void main() {
  const renderDir = String.fromEnvironment('ADVANCED_ADMIN_RENDER_DIR');
  var fontsLoaded = false;

  Future<void> pump(
    WidgetTester tester, {
    DetailedRoutineDraft? draft,
    List<TrainingProgram> catalog = const [],
    Future<bool> Function(DetailedRoutineDraft)? onDraft,
    Future<bool> Function(TrainingProgram, DetailedRoutineDraft)? onProgram,
    double width = 375,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            key: const ValueKey('advanced-admin-capture'),
            child: child!,
          ),
        ),
        home: DetailedRoutineScreen(
          initialDraft: draft ?? DetailedRoutineDraft.fromProgram(_program()),
          catalog: catalog,
          onDraftChanged: onDraft ?? (_) async => true,
          onSaveProgram: onProgram ?? (_, _) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String suffix) => find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField && widget.key.toString().contains("$suffix'"),
  );

  Finder advanced(int exercise) => find.byWidgetPredicate(
    (widget) =>
        widget is ExpansionTile &&
        widget.key.toString().contains('-w0-s0-e$exercise-t0-advanced'),
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String suffix, String value) async {
    await reveal(tester, field(suffix));
    await tester.enterText(field(suffix), value);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('advanced-admin-capture')),
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

  testWidgets('고급 처방과 슈퍼세트 변경을 검토하고 새 버전으로 저장한다', (tester) async {
    final old = _program();
    TrainingProgram? saved;
    DetailedRoutineDraft? persisted;
    await pump(
      tester,
      catalog: [old],
      onDraft: (draft) async {
        persisted = draft.copy();
        return true;
      },
      onProgram: (program, _) async {
        saved = program;
        return true;
      },
    );
    await tap(tester, find.text('프로그램 정보'));
    await enter(tester, 'version', '2');
    await tap(tester, advanced(0));
    await enter(tester, 'w0-s0-e0-t0-rest', '90');
    await enter(tester, 'w0-s0-e0-t0-tempo', '3-1-X-0');
    await tap(tester, find.byKey(const ValueKey('w0-s0-e0-t0-amrap')));
    await enter(tester, 'w0-s0-e0-t0-reps', '6');
    await tap(tester, find.byKey(const ValueKey('w0-s0-e0-superset-options')));
    await enter(tester, 'w0-s0-e0-superset', 'A');
    await tap(tester, find.text('검증 운동 2'));
    await tap(tester, find.byKey(const ValueKey('w0-s0-e1-superset-options')));
    await enter(tester, 'w0-s0-e1-superset', 'A');
    expect(
      persisted!.weeks.single.sessions.single.exercises[0].sets[0].rir,
      old.sessions.single.exercises[0].sets[0].rir.toString(),
    );
    await tap(tester, find.text('변경 검토'));
    expect(find.text('세트 추가 0 · 변경 1 · 삭제 0'), findsOneWidget);
    expect(find.text('슈퍼세트 묶음 변경 2개 운동'), findsOneWidget);
    expect(find.textContaining('묶음 없음 → A'), findsNWidgets(2));
    await tap(tester, find.byKey(const ValueKey('review-session-session-1')));
    expect(find.textContaining('AMRAP · 기준 6회'), findsOneWidget);
    expect(find.textContaining('휴식 90초 · 템포 3-1-X-0'), findsOneWidget);
    expect(find.textContaining('슈퍼세트 A · 묶인 운동'), findsNWidgets(2));
    await capture(tester, 'review-mobile');
    await tap(tester, find.text('검토한 프로그램 저장'));
    final exercise = saved!.sessions.single.exercises.first;
    expect(exercise.supersetGroup, 'A');
    expect(exercise.sets.single.restSeconds, 90);
    expect(exercise.sets.single.tempo, '3-1-X-0');
    expect(exercise.sets.single.isAmrap, isTrue);
    expect(exercise.sets.single.repetitions, 6);
    expect(exercise.sets.single.rir, 2);
    expect(old.sessions.single.exercises.first.sets.single.restSeconds, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('휴식 미지정과 0을 구별하고 고급 입력 원문을 되돌리고 다시 실행한다', (tester) async {
    DetailedRoutineDraft? persisted;
    await pump(
      tester,
      onDraft: (draft) async {
        persisted = draft.copy();
        return true;
      },
    );
    await tap(tester, advanced(0));
    await enter(tester, 'w0-s0-e0-t0-rest', '0');
    expect(
      generateDetailedRoutine(
        persisted!,
      ).sessions.single.exercises[0].sets[0].restSeconds,
      0,
    );
    await tap(tester, find.byTooltip('되돌리기'));
    expect(
      persisted!.weeks.single.sessions.single.exercises[0].sets[0].restSeconds,
      '',
    );
    await tap(tester, find.byTooltip('다시 실행'));
    expect(
      persisted!.weeks.single.sessions.single.exercises[0].sets[0].restSeconds,
      '0',
    );
    await enter(tester, 'w0-s0-e0-t0-rest', '');
    expect(
      generateDetailedRoutine(
        persisted!,
      ).sessions.single.exercises[0].sets[0].restSeconds,
      isNull,
    );
    await enter(tester, 'w0-s0-e0-t0-tempo', '3-');
    expect(
      persisted!.weeks.single.sessions.single.exercises[0].sets[0].tempo,
      '3-',
    );
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsNothing);
    expect(find.byKey(const ValueKey('detail-message')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연속 운동이 없는 슈퍼세트를 검토에서 차단하고 수정 후 진행한다', (tester) async {
    await pump(tester);
    await tap(tester, find.byKey(const ValueKey('w0-s0-e0-superset-options')));
    await enter(tester, 'w0-s0-e0-superset', 'A');
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsNothing);
    expect(find.byKey(const ValueKey('detail-message')), findsOneWidget);
    await enter(tester, 'w0-s0-e0-superset', '');
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카탈로그 저장 실패와 재시도에서 고급 처방 후보가 유지된다', (tester) async {
    final draft = DetailedRoutineDraft.fromProgram(_program());
    final set = draft.weeks.single.sessions.single.exercises[0].sets[0];
    set.restSeconds = '0';
    set.tempo = '2-0-1-0';
    set.isAmrap = true;
    final attempts = <TrainingProgram>[];
    await pump(
      tester,
      draft: draft,
      onProgram: (program, _) async {
        attempts.add(program);
        return attempts.length > 1;
      },
    );
    await tap(tester, find.text('변경 검토'));
    await tap(tester, find.text('검토한 프로그램 저장'));
    expect(find.text('카탈로그 저장 재시도'), findsOneWidget);
    await capture(tester, 'review-save-failure');
    await tap(tester, find.text('카탈로그 저장 재시도'));
    expect(attempts.length, 2);
    expect(attempts[0].toJson(), attempts[1].toJson());
    expect(attempts.last.sessions.single.exercises[0].sets[0].restSeconds, 0);
    expect(attempts.last.sessions.single.exercises[0].sets[0].isAmrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1200.0, 375.0]) {
    testWidgets('고급 입력 $width 폭에서 큰 글자와 키보드를 포함해 조작한다', (tester) async {
      await pump(tester, width: width, scale: width == 375 ? 1.5 : 1);
      await tap(tester, advanced(0));
      await enter(tester, 'w0-s0-e0-t0-rest', '90');
      await enter(tester, 'w0-s0-e0-t0-tempo', '3-1-X-0');
      await tap(tester, find.byKey(const ValueKey('w0-s0-e0-t0-amrap')));
      await reveal(tester, field('w0-s0-e0-t0-rest'));
      await capture(
        tester,
        width == 375 ? 'advanced-mobile-large' : 'advanced-desktop',
      );
      if (width == 375) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await enter(tester, 'w0-s0-e0-t0-tempo', '2-0-1-0');
        await capture(tester, 'advanced-mobile-keyboard');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      await tap(tester, find.text('변경 검토'));
      expect(find.text('프로그램 변경 검토'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('review-session-session-1')));
      await capture(
        tester,
        width == 375 ? 'review-mobile-large' : 'review-desktop',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
