import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/data/local_settings_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/main.dart';
import 'package:strength_routine/program_screen.dart';
import 'package:strength_routine/settings_screen.dart';
import 'package:strength_routine/subscription_screen.dart';
import 'package:strength_routine/support_screen.dart';
import 'package:strength_routine/workout_screen.dart';
import 'training_program_fixtures.dart';

void main() {
  late Directory directory;
  late File trainingFile;
  late TrainingController controller;
  late LocalHabitStore habitStore;
  late ActiveTrainingPlan plan;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings-integration-');
    trainingFile = File('${directory.path}/training.json');
    controller = TrainingController(
      store: LocalTrainingStore(trainingFile),
      loadPrograms: () async => [fixtureProgram()],
    );
    habitStore = LocalHabitStore(File('${directory.path}/habits.json'));
    plan = fixturePlan();
  });

  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump();
      if (!controller.loading &&
          !controller.catalogLoading &&
          !controller.saving &&
          find
              .byType(LinearProgressIndicator, skipOffstage: false)
              .evaluate()
              .isEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(
      controller.loading || controller.catalogLoading || controller.saving,
      isFalse,
    );
    expect(
      find.byType(LinearProgressIndicator, skipOffstage: false),
      findsNothing,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester, TrainingAppState state) async {
    await tester.runAsync(() async {
      await controller.store.save(state);
      await controller.initialize();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      StrengthApp(
        controller: controller,
        habitStore: habitStore,
        now: () => plan.sessions.first.date,
      ),
    );
    await flush(tester);
    expect(find.byType(HomeShell), findsOneWidget);
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseLbInProfile(WidgetTester tester) async {
    await tab(tester, '프로필');
    await tester.ensureVisible(find.text('앱 설정'));
    await tester.tap(find.text('앱 설정'));
    await tester.pumpAndSettle();
    final settings = tester
        .widget<SettingsScreen>(find.byType(SettingsScreen))
        .controller;
    expect(settings.settings.defaultWeightUnit, WeightUnit.kg);
    await tester.tap(find.text('lb'));
    await flush(tester);
    expect(settings.settings.defaultWeightUnit, WeightUnit.lb);
    final restored = await tester.runAsync(
      () => LocalSettingsStore(settings.store.file).load(),
    );
    expect(restored!.defaultWeightUnit, WeightUnit.lb);
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> openTodayWorkout(WidgetTester tester) async {
    await tab(tester, '오늘');
    await tester.ensureVisible(find.text('운동 기록하기'));
    await tester.tap(find.text('운동 기록하기'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutScreen), findsOneWidget);
  }

  Future<void> openSet(WidgetTester tester, int index) async {
    final row = find.byType(WorkoutSetRow).at(index);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(SetEditor), findsOneWidget);
  }

  Finder setField(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Finder labeledField(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  testWidgets('프로필 설정·도움말·구독을 실제로 열고 저장한 lb로 새 세트를 기록한다', (tester) async {
    await openApp(tester, TrainingAppState(onboarded: true, activePlan: plan));
    await chooseLbInProfile(tester);
    await tester.ensureVisible(find.text('도움말·자주 묻는 질문'));
    await tester.tap(find.text('도움말·자주 묻는 질문'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('구독 안내'));
    await tester.tap(find.text('구독 안내'));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(find.text('구독은 준비 중이에요'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openTodayWorkout(tester);
    await openSet(tester, 0);
    expect(find.text('실제 중량 (lb)'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(setField('set-weight')).controller!.text,
      isEmpty,
    );
    await tester.enterText(setField('set-weight'), '80');
    await tester.enterText(setField('set-repetitions'), '5');
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.tap(find.text('세트 완료'));
    await flush(tester);
    expect(find.byType(SetEditor), findsNothing);
    final set = plan.sessions.first.exercises.single.sets.first;
    final restored = await tester.runAsync(
      () => LocalTrainingStore(trainingFile).load(),
    );
    expect(restored!.setActuals[set.id]!.unit, WeightUnit.lb);
    expect(restored.setActuals[set.id]!.weight, 80);
    expect(restored.activePlan!.targetKgBySetId, plan.targetKgBySetId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로필 기본값을 lb로 바꿔도 기존 kg 초안과 실제 기록의 단위·숫자를 유지한다', (tester) async {
    final sets = plan.sessions.first.exercises.single.sets;
    final state = TrainingAppState(onboarded: true, activePlan: plan)
        .withSetDraft(sets[0].id, {
          'weight': '87.',
          'repetitions': '4',
          'rir': '0',
          'unit': 'kg',
          'note': '기존 초안',
        })
        .withSetActual(
          sets[1].id,
          SetActual.completed(
            weight: 92.5,
            unit: WeightUnit.kg,
            repetitions: 3,
            rir: 0,
            note: '기존 실제 기록',
          ),
        );
    await openApp(tester, state);
    await chooseLbInProfile(tester);
    await openTodayWorkout(tester);
    await openSet(tester, 0);
    expect(find.text('실제 중량 (kg)'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(setField('set-weight')).controller!.text,
      '87.',
    );
    expect(
      tester.widget<TextFormField>(setField('set-rir')).controller!.text,
      '0',
    );
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await flush(tester);
    await openSet(tester, 1);
    expect(find.text('실제 중량 (kg)'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(setField('set-weight')).controller!.text,
      '92.5',
    );
    expect(
      tester.widget<TextFormField>(setField('set-rir')).controller!.text,
      '0',
    );
    await tester.tap(find.byTooltip('기록 초안 저장하고 닫기'));
    await flush(tester);
    expect(controller.state.toJson(), state.toJson());
    expect(
      (await tester.runAsync(
        () => LocalTrainingStore(trainingFile).load(),
      ))!.toJson(),
      state.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로필에서 바꾼 단위를 프로그램 선택·상세·설정 경로의 새 최근 기록에도 적용한다', (tester) async {
    await openApp(tester, TrainingAppState(onboarded: true));
    await chooseLbInProfile(tester);
    await tester.ensureVisible(find.text('프로그램 선택'));
    await tester.tap(find.text('프로그램 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramScreen), findsOneWidget);
    await tester.tap(find.text('프로그램 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDetailScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('이 프로그램으로 시작'), 300);
    await tester.tap(find.text('이 프로그램으로 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('최근 기록 입력'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ProgramSetupScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('최근 기록 입력'));
    await tester.pumpAndSettle();
    expect(find.byType(RecentRecordEditor), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<WeightUnit>>(
            find.byType(SegmentedButton<WeightUnit>),
          )
          .selected,
      {WeightUnit.lb},
    );
    expect(
      tester.widget<TextField>(labeledField('실제 중량')).controller!.text,
      isEmpty,
    );
    await tester.enterText(labeledField('실제 중량'), '100');
    await tester.enterText(labeledField('반복 횟수'), '5');
    await tester.ensureVisible(find.text('기록 확인'));
    await tester.tap(find.text('기록 확인'));
    await flush(tester);
    expect(find.byType(RecentRecordEditor), findsNothing);
    expect(find.text('100 lb · 5회'), findsOneWidget);
    final restored = await tester.runAsync(
      () => LocalTrainingStore(trainingFile).load(),
    );
    expect(restored!.recentRecords.single.unit, WeightUnit.lb);
    expect(restored.recentRecords.single.weight, 100);
    expect(restored.activePlan, isNull);
    expect(tester.takeException(), isNull);
  });
}
