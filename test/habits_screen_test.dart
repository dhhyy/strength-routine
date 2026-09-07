import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/habit_record.dart';
import 'package:strength_routine/habits_screen.dart';
import 'package:strength_routine/main.dart';
import 'package:strength_routine/theme.dart';

void main() {
  late Directory directory;
  late File file;
  late DateTime now;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('habit-screen-test-');
    file = File('${directory.path}/habits-state.json');
    now = DateTime(2026, 9, 7, 12);
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<void> flush(WidgetTester tester) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  }

  Future<void> pumpHabits(WidgetTester tester, {double scale = 1}) async {
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
          child: child!,
        ),
        home: Scaffold(
          body: HabitsScreen(store: LocalHabitStore(file), now: () => now),
        ),
      ),
    );
    await flush(tester);
  }

  Finder nameField() => find.descendant(
    of: find.byKey(const ValueKey('habit-name')),
    matching: find.byType(TextFormField),
  );

  testWidgets(
    'empty habits, validation, user addition and check survive reopening',
    (tester) async {
      await pumpHabits(tester);
      expect(find.text('등록한 습관이 없어요'), findsOneWidget);
      expect(find.text('물 2L 마시기'), findsNothing);
      expect(find.text('단백질 120g'), findsNothing);
      await tester.ensureVisible(find.text('습관 추가'));
      await tester.tap(find.text('습관 추가'));
      await tester.pumpAndSettle();
      expect(find.text('습관 이름을 입력해 주세요.'), findsOneWidget);
      await tester.enterText(nameField(), '사용자 검증 습관');
      await tester.tap(find.text('습관 추가'));
      await flush(tester);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await flush(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      final saved = await tester.runAsync(() => LocalHabitStore(file).load());
      expect(saved!.habits.single.name, '사용자 검증 습관');
      expect(saved.completedCount(now), 1);
      await tester.pumpWidget(const SizedBox());
      await pumpHabits(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date navigation and archive keep the historical check', (
    tester,
  ) async {
    final yesterday = now.subtract(const Duration(days: 1));
    final state = HabitState()
        .add(HabitDefinition(id: 'one', name: '보관 검증', createdDate: yesterday))
        .setCompleted('one', yesterday, true, asOf: now);
    await tester.runAsync(() => LocalHabitStore(file).save(state));
    await pumpHabits(tester);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await tester.tap(find.byTooltip('이전 날짜'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-06'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.byTooltip('보관 검증 보관'));
    await flush(tester);
    await tester.ensureVisible(find.text('보관한 습관'));
    await tester.tap(find.text('보관한 습관'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('보관 검증 다시 활성화'));
    await tester.tap(find.byTooltip('보관 검증 다시 활성화'));
    await flush(tester);
    final restored = await tester.runAsync(() => LocalHabitStore(file).load());
    expect(restored!.habits.single.archived, isFalse);
    expect(restored.completedCount(yesterday), 1);
    expect(restored.completedCount(now), 0);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await flush(tester);
    expect(
      (await tester.runAsync(
        () => LocalHabitStore(file).load(),
      ))!.completedCount(yesterday),
      0,
    );
  });

  testWidgets(
    'failed addition keeps the name and retries without duplication',
    (tester) async {
      await pumpHabits(tester);
      await tester.runAsync(() => Directory(file.path).create());
      await tester.enterText(nameField(), '실패 복구 검증');
      await tester.ensureVisible(find.text('습관 추가'));
      await tester.tap(find.text('습관 추가'));
      await flush(tester);
      expect(find.text('저장되지 않은 변경이 있어요'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(nameField()).controller!.text,
        '실패 복구 검증',
      );
      await tester.runAsync(() => Directory(file.path).delete());
      await tester.ensureVisible(find.text('저장 다시 시도'));
      await tester.tap(find.text('저장 다시 시도'));
      await flush(tester);
      final restored = await tester.runAsync(
        () => LocalHabitStore(file).load(),
      );
      expect(restored!.habits, hasLength(1));
      expect(
        tester.widget<TextFormField>(nameField()).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'corrupt file shows retry and cannot be replaced by an empty write',
    (tester) async {
      await tester.runAsync(() => file.writeAsString('{broken'));
      await pumpHabits(tester);
      expect(find.text('습관을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('습관 추가'), findsNothing);
      await tester.tap(find.text('다시 불러오기'));
      await flush(tester);
      expect(await tester.runAsync(file.readAsString), '{broken');
    },
  );

  testWidgets(
    'midnight without resume discards a stale check before recording today',
    (tester) async {
      final previousDay = now;
      await tester.runAsync(
        () => LocalHabitStore(file).save(
          HabitState()
              .add(
                HabitDefinition(
                  id: 'midnight',
                  name: '날짜 변경 검증',
                  createdDate: previousDay,
                ),
              )
              .setCompleted('midnight', previousDay, true, asOf: now),
        ),
      );
      await pumpHabits(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );

      now = now.add(const Duration(days: 1));
      await tester.tap(find.byType(CheckboxListTile));
      await flush(tester);
      expect(find.text('2026-09-08'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      final afterRefresh = await tester.runAsync(
        () => LocalHabitStore(file).load(),
      );
      expect(afterRefresh!.isCompleted('midnight', previousDay), isTrue);
      expect(afterRefresh.isCompleted('midnight', now), isFalse);

      await tester.tap(find.byType(CheckboxListTile));
      await flush(tester);
      final afterCheck = await tester.runAsync(
        () => LocalHabitStore(file).load(),
      );
      expect(afterCheck!.isCompleted('midnight', previousDay), isTrue);
      expect(afterCheck.isCompleted('midnight', now), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tab entry after midnight follows today and preserves a selected past day',
    (tester) async {
      final previousDay = now;
      final archivedDay = now.subtract(const Duration(days: 1));
      final original = HabitState()
          .add(
            HabitDefinition(
              id: 'active',
              name: '탭 복귀 검증',
              createdDate: archivedDay,
            ),
          )
          .add(
            HabitDefinition(
              id: 'archived',
              name: '보관 이력 검증',
              createdDate: archivedDay,
              archived: true,
            ),
          )
          .setCompleted('active', previousDay, true, asOf: now)
          .setCompleted('archived', archivedDay, true, asOf: now);
      await tester.runAsync(() => LocalHabitStore(file).save(original));
      final controller = TrainingController(
        store: LocalTrainingStore(File('${directory.path}/training.json')),
        loadPrograms: () async => [],
      )..loading = false;
      addTearDown(controller.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildConsoleTheme(),
          home: HomeShell(
            controller: controller,
            habitStore: LocalHabitStore(file),
            now: () => now,
          ),
        ),
      );
      await tester.tap(find.text('습관'));
      await flush(tester);
      expect(find.text('2026-09-07'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();

      now = now.add(const Duration(days: 1));
      await tester.tap(find.text('습관'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-08'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );

      await tester.tap(find.byTooltip('이전 날짜'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-07'), findsOneWidget);
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(days: 1));
      await tester.tap(find.text('습관'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-07'), findsOneWidget);
      expect(find.text('선택한 날 체크한 습관'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      final restored = await tester.runAsync(
        () => LocalHabitStore(file).load(),
      );
      expect(restored!.toJson(), original.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long Korean name at large text remains editable and resume follows today',
    (tester) async {
      await tester.runAsync(
        () => LocalHabitStore(file).save(
          HabitState().add(
            HabitDefinition(
              id: 'long',
              name: '검증용으로 입력한 긴 생활습관 이름을 여러 줄로 표시하고 체크하기',
              createdDate: now,
            ),
          ),
        ),
      );
      await pumpHabits(tester, scale: 1.6);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await flush(tester);
      now = now.add(const Duration(days: 1));
      for (final phase in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(phase);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('2026-09-08'));
      expect(find.text('2026-09-08'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
