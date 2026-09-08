import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/admin_screen.dart';
import 'package:strength_routine/admin/detailed_bulk_screen.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/detailed_routine_screen.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';

// Delay only the real file's parent-create stage of an atomic write. The
// workspace store and its serialization/rename path remain production code.
class _WriteBarrier {
  Completer<void>? _release;
  bool entered = false;
  int writes = 0;
  void hold() {
    expect(_release, isNull);
    entered = false;
    _release = Completer<void>();
  }

  Future<void> wait() async {
    writes++;
    if (_release case final release?) {
      entered = true;
      await release.future;
    }
  }

  void release() {
    _release!.complete();
    _release = null;
  }
}

class _BarrierFile implements File {
  final File file;
  final _WriteBarrier barrier;
  _BarrierFile(this.file, this.barrier);
  @override
  String get path => file.path;
  @override
  Directory get parent => _BarrierDirectory(file.parent, barrier);
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      file.readAsString(encoding: encoding);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BarrierDirectory implements Directory {
  final Directory directory;
  final _WriteBarrier barrier;
  _BarrierDirectory(this.directory, this.barrier);
  @override
  Future<Directory> create({bool recursive = false}) async {
    await barrier.wait();
    return directory.create(recursive: recursive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// 조작/렌더 검증용 합성 자료. 사용자 프로그램 처방이 아니다.
TrainingProgram _program({String version = '1', String title = '편집 검증 프로그램'}) =>
    TrainingProgram(
      id: 'lc04-fixture',
      version: version,
      title: title,
      trainerName: '검증용',
      description: '합성 자료 · 반복 범위와 보관 이력의 화면 검증',
      weeks: 2,
      sessions: [
        for (var w = 1; w <= 2; w++)
          ProgramSession(
            id: 'session-$w',
            week: w,
            dayOrder: 1,
            title: '검증 세션',
            exercises: [
              for (var e = 1; e <= 2; e++)
                ProgramExercise(
                  id: 'exercise-$e',
                  name: '검증 운동 $e',
                  sets: [
                    for (var s = 1; s <= 2; s++)
                      ProgramSet(
                        id: 'set-$s',
                        repetitions: 8,
                        rir: 2,
                        load: LoadPrescription.fixedKg(20),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );

void main() {
  const renderDir = String.fromEnvironment('LOCAL_ADMIN_RENDER_DIR');
  var fontsLoaded = false;
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('lc04-widget-'),
  );
  tearDown(() => directory.delete(recursive: true));
  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    final elapsed = Stopwatch()..start();
    bool completed() =>
        until?.call() ??
        (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find
                .byWidgetPredicate(
                  (widget) => widget is AbsorbPointer && widget.absorbing,
                )
                .evaluate()
                .isEmpty &&
            find.text('초안 저장 중…').evaluate().isEmpty &&
            find.text('초안 저장 중').evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 16));
    while (!completed()) {
      if (elapsed.elapsed > const Duration(seconds: 10)) {
        fail('관리자 작업의 관찰 가능한 완료 상태를 10초 안에 확인하지 못했습니다.');
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Only settle route and expansion animations once actual I/O is done.
    if (until == null) await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
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
            key: const ValueKey('lc04-capture'),
            child: child!,
          ),
        ),
        home: home,
      ),
    );
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('lc04-capture')),
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

  Finder field(String suffix) => find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField && widget.key.toString().contains("$suffix'"),
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
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    bool Function()? until,
  }) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await settle(tester, until: until);
  }

  Future<void> enter(WidgetTester tester, String suffix, String text) async {
    await reveal(tester, field(suffix));
    await tester.enterText(field(suffix), text);
    await settle(tester);
  }

  Widget editor({
    DetailedRoutineDraft? draft,
    List<TrainingProgram> catalog = const [],
    Future<bool> Function(DetailedRoutineDraft)? onDraft,
    Future<bool> Function(TrainingProgram, DetailedRoutineDraft)? onProgram,
  }) => DetailedRoutineScreen(
    initialDraft: draft ?? DetailedRoutineDraft.fromProgram(_program()),
    catalog: catalog,
    onDraftChanged: onDraft ?? (_) async => true,
    onSaveProgram: onProgram ?? (_, _) async => true,
  );
  Future<void> dropdown(WidgetTester tester, String key, String option) async {
    await tap(tester, find.byKey(ValueKey(key)));
    await tester.tap(find.text(option).last);
    await settle(tester);
  }

  testWidgets('반복 범위와 세트 종류를 편집/검토하고 새 버전으로 저장한다', (tester) async {
    DetailedRoutineDraft? persisted;
    TrainingProgram? saved;
    final draft = DetailedRoutineDraft.fromProgram(_program())..version = '2';
    await pump(
      tester,
      editor(
        draft: draft,
        catalog: [_program()],
        onDraft: (value) async {
          persisted = value.copy();
          return true;
        },
        onProgram: (program, _) async {
          saved = program;
          return true;
        },
      ),
    );
    await enter(tester, 'w0-s0-e0-t0-reps-max', '12');
    final kind = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<ProgramSetKind> &&
          w.key.toString().contains('w0-s0-e0-t0-set-kind'),
    );
    await tap(tester, kind);
    await tester.tap(find.text('워밍업').last);
    await settle(tester);
    expect(
      persisted!
          .weeks
          .first
          .sessions
          .first
          .exercises
          .first
          .sets
          .first
          .repetitionsMax,
      '12',
    );
    expect(
      persisted!.weeks.first.sessions.first.exercises.first.sets.first.kind,
      ProgramSetKind.warmup,
    );
    await tap(tester, find.text('변경 검토'));
    await tap(tester, find.byKey(const ValueKey('review-session-session-1')));
    expect(find.textContaining('워밍업 · 8–12회'), findsOneWidget);
    await capture(tester, 'range-review-mobile');
    await tap(tester, find.text('검토한 프로그램 저장'));
    expect(
      saved!.sessions.first.exercises.first.sets.first.kind,
      ProgramSetKind.warmup,
    );
    expect(saved!.sessions.first.exercises.first.sets.first.repetitionsMax, 12);
    expect(tester.takeException(), isNull);
  });
  testWidgets('일괄 수정은 미리보기/취소/확정/한 단계 되돌리기를 연결한다', (tester) async {
    DetailedRoutineDraft? persisted;
    await pump(
      tester,
      editor(
        onDraft: (value) async {
          persisted = value.copy();
          return true;
        },
      ),
    );
    await tap(tester, find.byKey(const ValueKey('bulk-edit-w0-s0-e0')));
    await tester.enterText(find.byKey(const ValueKey('bulk-value')), '45');
    await tap(tester, find.text('변경 내용 검토'));
    expect(find.text('대상 2세트 · 변경 2세트'), findsOneWidget);
    await tap(tester, find.text('취소'));
    expect(persisted, isNull);
    await tap(tester, find.byKey(const ValueKey('bulk-edit-w0-s0-e0')));
    await dropdown(tester, 'bulk-scope', '현재 세션');
    await tester.enterText(find.byKey(const ValueKey('bulk-value')), '60');
    await tap(tester, find.text('변경 내용 검토'));
    expect(find.text('대상 4세트 · 변경 4세트'), findsOneWidget);
    await capture(tester, 'bulk-review-mobile');
    await tap(tester, find.text('초안에 일괄 적용'));
    expect(
      persisted!.weeks.first.sessions.first.exercises
          .expand((e) => e.sets)
          .every((s) => s.restSeconds == '60'),
      isTrue,
    );
    expect(
      persisted!
          .weeks
          .last
          .sessions
          .first
          .exercises
          .first
          .sets
          .first
          .restSeconds,
      '',
    );
    await tap(tester, find.byTooltip('되돌리기'));
    expect(
      persisted!.toJson(),
      DetailedRoutineDraft.fromProgram(_program()).toJson(),
    );
    await tap(tester, find.byTooltip('다시 실행'));
    expect(
      persisted!
          .weeks
          .first
          .sessions
          .first
          .exercises
          .first
          .sets
          .first
          .restSeconds,
      '60',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('잘못된 일괄 값과 미완성 반복 범위는 원문을 유지하고 오류를 보인다', (tester) async {
    DetailedRoutineDraft? persisted;
    await pump(
      tester,
      editor(
        onDraft: (value) async {
          persisted = value.copy();
          return true;
        },
      ),
    );
    await tap(tester, find.byKey(const ValueKey('bulk-edit-w0-s0-e0')));
    await tester.enterText(find.byKey(const ValueKey('bulk-value')), '3601');
    await tap(tester, find.text('변경 내용 검토'));
    expect(find.text('일괄 수정 확인 필요'), findsOneWidget);
    expect(find.text('초안에 일괄 적용'), findsNothing);
    expect(persisted, isNull);
    await capture(tester, 'bulk-error-mobile');
    await tap(tester, find.text('취소'));
    await enter(tester, 'w0-s0-e0-t0-reps-max', '12.');
    await tap(tester, find.text('변경 검토'));
    expect(find.byKey(const ValueKey('detail-message')), findsOneWidget);
    expect(
      persisted!
          .weeks
          .first
          .sessions
          .first
          .exercises
          .first
          .sets
          .first
          .repetitionsMax,
      '12.',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('보관 취소/실패 보존/재시도/복원과 실제 파일 재로딩을 연결한다', (tester) async {
    final file = File('${directory.path}/workspace.json');
    final store = AdminProgramStore(file);
    final original = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [_program()],
    );
    await tester.runAsync(() => store.save(original));
    await pump(tester, AdminScreen(store: store), width: 1200);
    await tap(
      tester,
      find.byKey(const ValueKey('catalog-archive-lc04-fixture')),
    );
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect((await tester.runAsync(store.load))!.archivedProgramIds, isEmpty);
    final backup = File('${directory.path}/original.json');
    await tester.runAsync(() async {
      await file.rename(backup.path);
      await Directory(file.path).create();
    });
    await tap(
      tester,
      find.byKey(const ValueKey('catalog-archive-lc04-fixture')),
    );
    await tester.tap(find.text('보관').last);
    await settle(
      tester,
      until: () => find.text('변경 저장 실패').evaluate().isNotEmpty,
    );
    expect(find.text('변경 저장 실패'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('catalog-archived-false')));
    expect(find.text('배포 대상 1'), findsOneWidget);
    await tester.runAsync(() async {
      await Directory(file.path).delete();
      await backup.rename(file.path);
    });
    await tap(
      tester,
      find.byKey(const ValueKey('catalog-archive-lc04-fixture')),
    );
    await tester.tap(find.text('보관').last);
    await settle(tester);
    expect((await tester.runAsync(store.load))!.archivedProgramIds, {
      'lc04-fixture',
    });
    await tap(tester, find.byKey(const ValueKey('catalog-archived-true')));
    await capture(tester, 'catalog-archived-desktop');
    await tap(
      tester,
      find.byKey(const ValueKey('catalog-archive-lc04-fixture')),
    );
    await tester.tap(find.text('복원').last);
    await settle(tester);
    expect(
      (await tester.runAsync(
        () => AdminProgramStore(file).load(),
      ))!.archivedProgramIds,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('이력에서 과거 구성을 불러와 새 버전으로 저장하고 과거 스냅샷을 보존한다', (tester) async {
    final file = File('${directory.path}/workspace.json');
    final barrier = _WriteBarrier();
    final store = AdminProgramStore(_BarrierFile(file, barrier));
    final old = _program();
    final current = _program(version: '2', title: '수정한 검증 프로그램');
    final original = AdminWorkspace(
      draft: RoutineBlueprint(),
      programs: [old],
    ).withProgram(current, null);
    await tester.runAsync(() => store.save(original));
    await pump(tester, AdminScreen(store: store), width: 1200);
    await tap(
      tester,
      find.byKey(const ValueKey('catalog-history-lc04-fixture')),
    );
    await capture(tester, 'version-history-desktop');
    barrier.hold();
    await tap(
      tester,
      find.byKey(const ValueKey('restore-version-1')),
      until: () => barrier.entered,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(DetailedRoutineScreen), findsNothing);
    expect(barrier.writes, 2);
    expect(
      jsonDecode((await tester.runAsync(file.readAsString))!),
      original.toJson(),
    );
    barrier.release();
    await settle(
      tester,
      until: () => find.byType(DetailedRoutineScreen).evaluate().isNotEmpty,
    );
    await settle(tester);
    expect(find.byType(DetailedRoutineScreen), findsOneWidget);
    final opened = (await tester.runAsync(store.load))!;
    expect(opened.detailedDraft!.version, '3');
    expect(opened.detailedDraft!.title, old.title);
    expect(opened.programs.single.title, current.title);
    await tap(tester, find.text('변경 검토'));
    barrier.hold();
    await tap(tester, find.text('검토한 프로그램 저장'), until: () => barrier.entered);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(barrier.writes, 3);
    expect(
      jsonDecode((await tester.runAsync(file.readAsString))!),
      opened.toJson(),
    );
    final saveButton = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    await tester.tap(saveButton);
    await tester.pump();
    expect(barrier.writes, 3);
    // Keep real I/O pending beyond the former 50 ms budget while settle runs.
    await tester.runAsync(() async {
      Timer(const Duration(milliseconds: 250), barrier.release);
    });
    await settle(
      tester,
      until: () => find.text('프로그램 변경 검토').evaluate().isEmpty,
    );
    await settle(tester);
    final restored = (await tester.runAsync(
      () => AdminProgramStore(store.file).load(),
    ))!;
    expect(restored.programs.single.version, '3');
    expect(restored.programs.single.title, old.title);
    expect(restored.versionsFor(old.id).first.toJson(), old.toJson());
    expect(restored.versionsFor(old.id), hasLength(3));
    expect(tester.takeException(), isNull);
  });
  for (final width in [1200.0, 375.0]) {
    testWidgets('반복 범위/일괄 ${width}px 큰 글자 렌더와 키보드 조작', (tester) async {
      final scale = width == 375 ? 1.5 : 1.0;
      await pump(tester, editor(), width: width, scale: scale);
      await enter(tester, 'w0-s0-e0-t0-reps-max', '12');
      await Scrollable.ensureVisible(
        tester.element(field('w0-s0-e0-t0-reps-max')),
        alignment: .15,
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        width == 375 ? 'range-mobile-large' : 'range-desktop',
      );
      if (width == 375) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await enter(tester, 'w0-s0-e0-t0-reps-max', '15');
        await Scrollable.ensureVisible(
          tester.element(field('w0-s0-e0-t0-reps-max')),
          alignment: .15,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'range-mobile-keyboard');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      await tap(tester, find.byKey(const ValueKey('bulk-edit-w0-s0-e0')));
      await dropdown(tester, 'bulk-scope', '전체 프로그램');
      await dropdown(tester, 'bulk-field', '세트 종류');
      await dropdown(tester, 'bulk-kind', '드롭세트');
      await tap(tester, find.text('변경 내용 검토'));
      await capture(
        tester,
        width == 375 ? 'bulk-mobile-large' : 'bulk-desktop',
      );
      await tap(tester, find.text('초안에 일괄 적용'));
      expect(find.byType(DetailedBulkScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
