import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/backup_screen.dart';
import 'package:strength_routine/data/backup_file_gateway.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/training_backup.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';
import 'training_program_fixtures.dart';

class TestFiles implements BackupFileGateway {
  String? input, output;
  bool accepted = true;
  @override
  Future<String?> pick() async => input;
  @override
  Future<bool> save(String text, String filename) async {
    output = text;
    return accepted;
  }
}

void main() {
  const renderDir = String.fromEnvironment('BACKUP_RENDER_DIR');
  late Directory dir;
  late TrainingController controller;
  late TestFiles gateway;
  var fontsLoaded = false;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup-screen-');
    final store = LocalTrainingStore(File('${dir.path}/state.json'));
    await store.save(
      TrainingAppState(onboarded: true, activePlan: fixturePlan()),
    );
    controller = TrainingController(store: store, loadPrograms: () async => []);
    await controller.initialize();
    gateway = TestFiles();
  });
  tearDown(() async {
    controller.dispose();
    await dir.delete(recursive: true);
  });
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
            key: const ValueKey('backup-render'),
            child: child!,
          ),
        ),
        home: BackupScreen(controller: controller, gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (find.byType(Scrollable).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await flush(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('backup-render')),
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

  testWidgets(
    'export creates restorable file and cancel preserves current state',
    (tester) async {
      await pump(tester);
      final before = controller.state.toJson();
      await tap(tester, '백업 파일 저장');
      expect(TrainingBackup.parse(gateway.output!).state.toJson(), before);
      gateway.accepted = false;
      await tap(tester, '백업 파일 저장');
      expect(find.text('파일 저장을 취소했어요. 기록은 그대로예요.'), findsOneWidget);
      await tap(tester, '백업 파일 가져오기');
      expect(controller.state.toJson(), before);
    },
  );

  testWidgets(
    'review cancellation and explicit restore replace only after confirmation',
    (tester) async {
      gateway.input = TrainingBackup(
        state: TrainingAppState(onboarded: true),
        createdAt: DateTime.utc(2026, 9, 8),
      ).encode();
      await pump(tester);
      await tap(tester, '백업 파일 가져오기');
      await tap(tester, '검토한 기록으로 복원');
      await tester.tap(find.text('취소'));
      await flush(tester);
      expect(controller.state.activePlan, isNotNull);
      await tap(tester, '검토한 기록으로 복원');
      await tester.tap(find.text('기록 교체'));
      await flush(tester);
      expect(controller.state.activePlan, isNull);
      expect(
        (await tester.runAsync(
          () => LocalTrainingStore(controller.store.file).load(),
        ))!.activePlan,
        isNull,
      );
    },
  );

  testWidgets('corrupt import retains current record and supports retry', (
    tester,
  ) async {
    gateway.input = 'broken';
    await pump(tester);
    await tap(tester, '백업 파일 가져오기');
    expect(find.text('처리하지 못했어요'), findsOneWidget);
    expect(controller.state.activePlan, isNotNull);
    await capture(tester, 'backup-error');
    gateway.input = TrainingBackupService(controller).export();
    await tap(tester, '백업 파일 가져오기');
    expect(find.text('복원 전 확인'), findsOneWidget);
  });

  testWidgets('review and recovery controls fit narrow large text', (
    tester,
  ) async {
    gateway.input = TrainingBackupService(controller).export();
    await pump(tester, scale: 1.5);
    await capture(tester, 'backup-large');
    await tap(tester, '백업 파일 가져오기');
    await tester.scrollUntilVisible(
      find.text('검토한 기록으로 복원'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'backup-review-large');
    expect(tester.takeException(), isNull);
    await tap(tester, '복원 검토 취소');
    await tap(tester, '복구본 검토');
    expect(find.text('처리하지 못했어요'), findsOneWidget);
    expect(controller.state.activePlan, isNotNull);
  });
}
