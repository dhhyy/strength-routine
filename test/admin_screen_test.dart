import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/admin_screen.dart';
import 'package:strength_routine/theme.dart';
import 'admin_routine_test.dart' show validBlueprint;

void main() {
  const renderDir = String.fromEnvironment('ADMIN_RENDER_DIR');
  late Directory directory;
  late AdminProgramStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('admin-screen-');
    store = AdminProgramStore(File('${directory.path}/workspace.json'));
  });
  tearDown(() async => directory.delete(recursive: true));
  Future<void> settle(WidgetTester tester) async {
    // Alternate real file I/O and fake-async callbacks; do not await the store
    // queue from runAsync while a queued UI callback still needs pump().
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target, double delta) =>
      tester.scrollUntilVisible(
        target,
        delta,
        scrollable: find.byType(Scrollable).first,
      );
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (renderDir.isNotEmpty) {
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
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        builder: (_, child) => RepaintBoundary(
          key: const ValueKey('admin-capture'),
          child: child!,
        ),
        home: AdminScreen(store: store, seedPrograms: () async => []),
      ),
    );
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('admin-capture')),
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

  testWidgets('관리자 생성→미리보기→저장→내보내기', (tester) async {
    await tester.runAsync(
      () => store.save(AdminWorkspace(draft: validBlueprint(), programs: [])),
    );
    await pump(tester);
    await capture(tester, 'admin-editor');
    await scrollTo(tester, find.text('생성 결과 확인'), 400);
    await tester.tap(find.text('생성 결과 확인'));
    await tester.pumpAndSettle();
    expect(find.text('생성 결과 확인'), findsOneWidget);
    expect(find.text('3주 · 주 2회 · 전체 6세션'), findsOneWidget);
    await capture(tester, 'admin-review');
    await scrollTo(tester, find.text('관리자 카탈로그에 저장'), 300);
    await tester.tap(find.text('관리자 카탈로그에 저장'));
    await settle(tester);
    final saved = await tester.runAsync(store.load);
    expect(saved!.programs.single.title, '관리자 검증');
    await scrollTo(tester, find.text('카탈로그 내보내기'), -500);
    await tester.tap(find.text('카탈로그 내보내기'));
    await settle(tester);
    expect(
      await tester.runAsync(
        () => File('${directory.path}/admin-export/programs.json').exists(),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('초안은 입력 원문을 저장하고 미완성 생성은 차단', (tester) async {
    await pump(tester);
    await scrollTo(tester, find.byKey(const ValueKey('1-title')), 250);
    await tester.enterText(find.byKey(const ValueKey('1-title')), '작성 중 루틴 ');
    await settle(tester);
    expect((await tester.runAsync(store.load))!.draft.title, '작성 중 루틴 ');
    await scrollTo(tester, find.text('생성 결과 확인'), 400);
    await tester.tap(find.text('생성 결과 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('프로그램 ID: 1~80'), findsOneWidget);
    expect(find.byType(AdminProgramReview), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('손상된 작업공간은 빈폼으로 덮어쓰지 않는다', (tester) async {
    await tester.runAsync(() => store.file.writeAsString('broken'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: AdminScreen(store: store, seedPrograms: () async => []),
      ),
    );
    await settle(tester);
    expect(find.text('불러오기 실패'), findsOneWidget);
    expect(await tester.runAsync(store.file.readAsString), 'broken');
    expect(find.text('새 루틴 생성'), findsNothing);
  });
}
