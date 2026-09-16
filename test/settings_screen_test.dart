import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/settings_controller.dart';
import 'package:strength_routine/data/local_settings_store.dart';
import 'package:strength_routine/domain/app_settings.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/settings_screen.dart';
import 'package:strength_routine/subscription_screen.dart';
import 'package:strength_routine/support_screen.dart';
import 'package:strength_routine/theme.dart';

void main() {
  const renderDirectory = String.fromEnvironment('SETTINGS_RENDER_DIR');
  var fontsLoaded = false;
  late Directory directory;
  late File file;
  late SettingsController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings-screen-test-');
    file = File('${directory.path}/app-settings.json');
    controller = SettingsController(store: LocalSettingsStore(file));
  });
  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double scale = 1,
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
            key: const ValueKey('settings-render'),
            child: child!,
          ),
        ),
        home: home,
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDirectory.isEmpty) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('settings-render')),
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

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 200 && (controller.saving || controller.loading); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(controller.saving || controller.loading, isFalse);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loading, unit and suggestion preferences restore into a new controller',
    (tester) async {
      await pump(tester, SettingsScreen(controller: controller));
      expect(find.text('저장된 설정을 불러오고 있어요.'), findsOneWidget);
      expect(find.byType(SegmentedButton<WeightUnit>), findsNothing);
      await tester.runAsync(controller.initialize);
      await flush(tester);
      await capture(tester, 'settings-default');
      await tester.tap(find.text('lb'));
      await flush(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('show-load-suggestions')),
      );
      await tester.tap(find.byKey(const ValueKey('show-load-suggestions')));
      await flush(tester);
      final reopened = (await tester.runAsync(() async {
        final c = SettingsController(store: LocalSettingsStore(file));
        await c.initialize();
        return c;
      }))!;
      addTearDown(reopened.dispose);
      expect(reopened.settings.defaultWeightUnit, WeightUnit.lb);
      expect(reopened.settings.showLoadSuggestions, isFalse);
      expect(reopened.loadError, isNull);
      await pump(tester, SettingsScreen(controller: reopened));
      await tester.ensureVisible(
        find.text('기본 중량 단위', skipOffstage: false),
      );
      expect(
        tester
            .widget<SegmentedButton<WeightUnit>>(
              find.byType(
                SegmentedButton<WeightUnit>,
                skipOffstage: false,
              ),
            )
            .selected,
        {WeightUnit.lb},
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(
                const ValueKey('show-load-suggestions'),
                skipOffstage: false,
              ),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed choice stays visible but not applied until retry, including page re-entry',
    (tester) async {
      await tester.runAsync(controller.initialize);
      await pump(tester, SettingsScreen(controller: controller));
      await tester.runAsync(() => Directory(file.path).create());
      await tester.tap(find.text('lb'));
      await flush(tester);
      expect(find.text('아직 적용되지 않은 설정이 있어요'), findsOneWidget);
      expect(controller.settings.defaultWeightUnit, WeightUnit.kg);
      expect(controller.displayedSettings.defaultWeightUnit, WeightUnit.lb);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, SettingsScreen(controller: controller));
      expect(
        tester
            .widget<SegmentedButton<WeightUnit>>(
              find.byType(SegmentedButton<WeightUnit>),
            )
            .selected,
        {WeightUnit.lb},
      );
      await tester.runAsync(() => Directory(file.path).delete());
      await tester.tap(find.text('설정 저장 다시 시도'));
      await flush(tester);
      expect(find.text('아직 적용되지 않은 설정이 있어요'), findsNothing);
      expect(controller.settings.defaultWeightUnit, WeightUnit.lb);
      expect(
        (await tester.runAsync(
          () => LocalSettingsStore(file).load(),
        ))!.defaultWeightUnit,
        WeightUnit.lb,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'corrupt settings show retry without editable defaults or overwriting the file',
    (tester) async {
      await tester.runAsync(() async {
        await file.writeAsString('{broken');
        await controller.initialize();
      });
      await pump(tester, SettingsScreen(controller: controller));
      expect(find.text('설정을 불러오지 못했어요'), findsOneWidget);
      expect(find.byType(SegmentedButton<WeightUnit>), findsNothing);
      expect(await tester.runAsync(file.readAsString), '{broken');
      await tester.runAsync(
        () => LocalSettingsStore(
          file,
        ).save(const AppSettings(defaultWeightUnit: WeightUnit.lb)),
      );
      await tester.tap(find.text('다시 불러오기'));
      await flush(tester);
      expect(find.text('설정을 불러오지 못했어요'), findsNothing);
      expect(controller.settings.defaultWeightUnit, WeightUnit.lb);
    },
  );

  testWidgets('large text settings remain scrollable with reachable controls', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await pump(tester, SettingsScreen(controller: controller), scale: 2);
    await tester.ensureVisible(find.text('lb'));
    await tester.tap(find.text('lb'));
    await flush(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('show-load-suggestions')),
    );
    await tester.tap(find.byKey(const ValueKey('show-load-suggestions')));
    await flush(tester);
    expect(controller.settings.showLoadSuggestions, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom duration validation, automatic option and clearing restore',
    (tester) async {
      await tester.runAsync(controller.initialize);
      await pump(tester, SettingsScreen(controller: controller));
      final field = find.byKey(const ValueKey('default-rest-seconds'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '0');
      await tester.ensureVisible(find.text('기본 휴식 시간 저장'));
      await tester.tap(find.text('기본 휴식 시간 저장'));
      await tester.pumpAndSettle();
      expect(find.text('1~3600초의 정수를 입력하거나 비워 주세요.'), findsOneWidget);
      expect(controller.settings.defaultRestSeconds, isNull);
      await tester.enterText(field, '123');
      await tester.ensureVisible(find.text('기본 휴식 시간 저장'));
      await tester.tap(find.text('기본 휴식 시간 저장'));
      await flush(tester);
      expect(controller.settings.defaultRestSeconds, 123);
      final automatic = find.byKey(const ValueKey('auto-start-rest-timer'));
      await tester.ensureVisible(automatic);
      await tester.tap(automatic);
      await flush(tester);
      expect(controller.settings.autoStartRestTimer, isTrue);
      final autoWm = find.byKey(const ValueKey('auto-apply-working-max'));
      await tester.ensureVisible(autoWm);
      await tester.tap(autoWm);
      await flush(tester);
      expect(controller.settings.autoApplyWorkingMax, isTrue);
      expect(
        (await tester.runAsync(
          () => LocalSettingsStore(file).load(),
        ))!.defaultRestSeconds,
        123,
      );
      await capture(tester, 'rest-settings-saved');
      await tester.ensureVisible(field);
      await tester.enterText(field, '');
      await tester.ensureVisible(find.text('기본 휴식 시간 저장'));
      await tester.tap(find.text('기본 휴식 시간 저장'));
      await flush(tester);
      expect(controller.settings.defaultRestSeconds, isNull);
      expect(controller.settings.autoStartRestTimer, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text rest settings preserve readable input and switch', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await pump(tester, SettingsScreen(controller: controller), scale: 1.8);
    await tester.scrollUntilVisible(find.text('휴식 타이머'), 200);
    await tester.ensureVisible(find.text('휴식 타이머'));
    await capture(tester, 'rest-settings-large');
    await tester.ensureVisible(
      find.byKey(const ValueKey('auto-start-rest-timer')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('auto-start-rest-timer')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('auto-start-rest-timer')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('auto-start-rest-timer')));
    await flush(tester);
    expect(controller.settings.autoStartRestTimer, isTrue);
    await capture(tester, 'rest-settings-large-switch');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'subscription preparation opens truthful local FAQ without payment or request actions',
    (tester) async {
      await pump(tester, const SubscriptionScreen());
      await capture(tester, 'subscription-preparation');
      expect(find.text('구독은 준비 중이에요'), findsOneWidget);
      expect(
        find.text('현재 기기에 저장한 운동 기록과 초안은 구독 없이 열람할 수 있어요.'),
        findsOneWidget,
      );
      expect(find.text('구독 시작'), findsNothing);
      expect(find.text('구매 복원'), findsNothing);
      await tester.ensureVisible(find.text('구독·기록 도움말'));
      await tester.tap(find.text('구독·기록 도움말'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportScreen), findsOneWidget);
      await tester.tap(find.text('구독 해지와 구매 복원은 어디서 하나요?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이 화면에서는 요청을 접수하지 않아요.'), findsOneWidget);
      await capture(tester, 'support-faq');
      await tester.scrollUntilVisible(find.text('트레이너에게 질문을 보낼 수 있나요?'), 300);
      await tester.tap(find.text('트레이너에게 질문을 보낼 수 있나요?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('문의 전송이나 실시간 상담은 지원하지 않아요.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(await tester.runAsync(file.exists), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
