import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/program_screen.dart';
import 'package:strength_routine/theme.dart';

const schedules = {
  'strength-full-body-2d': [1, 4],
  'strength-full-body-3d': [1, 3, 5],
  'strength-upper-lower-4d': [1, 2, 4, 5],
  'strength-barbell-basics-3d': [1, 3, 5],
  'strength-dumbbell-2d': [1, 4],
};

Map<MainLift, LiftBaseline> workingBaselines(TrainingProgram program) => {
  if (program.id == 'strength-barbell-basics-3d') ...{
    MainLift.squat: LiftBaseline(
      lift: MainLift.squat,
      kilograms: 47.5,
      source: BaselineSource.userEntered,
    ),
    MainLift.benchPress: LiftBaseline(
      lift: MainLift.benchPress,
      kilograms: 32.5,
      source: BaselineSource.userEntered,
    ),
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<TrainingProgram> programs;
  setUpAll(() async => programs = await loadBundledPrograms());

  test('실제 번들 카탈로그는 독자 작성 프로그램 5개와 안정된 운동 식별자를 제공한다', () {
    expect(programs.map((p) => p.id), unorderedEquals(schedules.keys));
    expect(() => programs.clear(), throwsUnsupportedError);
    final exerciseIdentity = <String, (String, MainLift?)>{};
    for (final program in programs) {
      expect(program.trainerName, 'Strength');
      expect(program.version, '2026-09-08.1');
      expect(program.weeks, 4);
      expect(program.sessionsPerWeek, schedules[program.id]!.length);
      expect(
        program.sessions.map((s) => s.id).toSet().length,
        program.sessions.length,
      );
      for (var week = 1; week <= program.weeks; week++) {
        final sessions = program.orderedSessions.where((s) => s.week == week);
        expect(
          sessions.map((s) => s.dayOrder),
          orderedEquals(List.generate(program.sessionsPerWeek, (i) => i + 1)),
        );
        for (final session in sessions) {
          expect(session.exercises, isNotEmpty);
          for (final exercise in session.exercises) {
            final identity = (exercise.name, exercise.mainLift);
            if (exerciseIdentity.containsKey(exercise.id)) {
              expect(
                exerciseIdentity[exercise.id],
                identity,
                reason: '${program.id}/${session.id}/${exercise.id}',
              );
            } else {
              exerciseIdentity[exercise.id] = identity;
            }
            expect(exercise.sets, isNotEmpty);
            for (final set in exercise.sets) {
              expect(set.isRequired, isTrue);
              expect(set.rir, 3);
              expect(set.repetitions, inInclusiveRange(8, 12));
            }
          }
        }
      }
    }
  });

  for (final entry in schedules.entries) {
    test('${entry.key}: 모든 주차·운동·세트가 일정과 저장 스냅샷에 손실 없이 포함된다', () {
      final program = programs.singleWhere((p) => p.id == entry.key);
      final original = program.toJson();
      for (final start in [
        DateTime.utc(2026, 9, 7),
        DateTime.utc(2026, 12, 30),
      ]) {
        final plan = createActivePlan(
          id: 'catalog-check-${program.id}-${isoDate(start)}',
          program: program,
          startDate: start,
          weekdays: entry.value,
          incrementKg: 2.5,
          baselines: workingBaselines(program),
        );
        final sessionKeys = <String>{};
        final exerciseKeys = <String>{};
        final setKeys = <String>{};
        final planned = plan.sessions;
        final authored = program.orderedSessions;
        var expectedDate = start;
        for (var i = 0; i < authored.length; i++) {
          while (!entry.value.contains(expectedDate.weekday)) {
            expectedDate = expectedDate.add(const Duration(days: 1));
          }
          final session = planned[i];
          final template = authored[i];
          final sessionKey = jsonEncode([plan.id, template.id]);
          expect(session.id, sessionKey);
          expect(sessionKeys.add(session.id), isTrue);
          expect(session.date, expectedDate);
          expect(session.week, template.week);
          expect(session.dayOrder, template.dayOrder);
          expect(session.exercises.length, template.exercises.length);
          expectedDate = expectedDate.add(const Duration(days: 1));
          for (var j = 0; j < template.exercises.length; j++) {
            final exercise = session.exercises[j];
            final originalExercise = template.exercises[j];
            expect(
              exercise.id,
              jsonEncode([plan.id, template.id, originalExercise.id]),
            );
            expect(exerciseKeys.add(exercise.id), isTrue);
            expect(exercise.name, originalExercise.name);
            expect(exercise.sets.length, originalExercise.sets.length);
            for (var k = 0; k < originalExercise.sets.length; k++) {
              final set = exercise.sets[k];
              final originalSet = originalExercise.sets[k];
              expect(
                set.id,
                jsonEncode([
                  plan.id,
                  template.id,
                  originalExercise.id,
                  originalSet.id,
                ]),
              );
              expect(setKeys.add(set.id), isTrue);
              expect(set.template.toJson(), originalSet.toJson());
              expect(
                set.targetKg,
                originalSet.load.kind == LoadKind.manual
                    ? null
                    : workingBaselines(
                        program,
                      )[originalSet.load.lift]!.kilograms,
              );
            }
          }
        }
        expect(plan.sessionDates.keys, unorderedEquals(sessionKeys));
        expect(plan.targetKgBySetId.keys, unorderedEquals(setKeys));
        expect(plan.program.toJson(), original);
        final restored = ActiveTrainingPlan.fromJson(
          jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), plan.toJson());
        expect(
          restored.sessions
              .expand((s) => s.exercises)
              .expand((e) => e.sets)
              .map((s) => s.id),
          unorderedEquals(setKeys),
        );
      }
    });
  }

  test('바벨 기준은 8회 RIR 3 작업중량 100%이며 다른 네 프로그램에는 기준값이 없다', () {
    for (final program in programs) {
      final baselines = workingBaselines(program);
      final lifts = <MainLift>{};
      for (final exercise in program.sessions.expand((s) => s.exercises)) {
        for (final set in exercise.sets) {
          if (set.load.kind == LoadKind.manual) {
            expect(exercise.mainLift, isNull);
            continue;
          }
          expect(program.id, 'strength-barbell-basics-3d');
          expect(set.load.kind, LoadKind.percentOfBaseline);
          expect(set.load.value, 100);
          expect(set.repetitions, 8);
          expect(exercise.mainLift, set.load.lift);
          lifts.add(set.load.lift!);
        }
      }
      expect(lifts, unorderedEquals(baselines.keys));
      if (baselines.isNotEmpty) {
        expect(
          () => createActivePlan(
            id: 'missing-working-weight',
            program: program,
            startDate: DateTime.utc(2026, 9, 7),
            weekdays: schedules[program.id]!,
            incrementKg: 2.5,
          ),
          throwsFormatException,
        );
      }
    }
  });

  testWidgets('수동 중량 프로그램은 최근 기록 없이 설정에서 결과 확인까지 열린다', (tester) async {
    final controller = TrainingController(
      store: LocalTrainingStore(File('/private/tmp/unused-catalog-setup.json')),
      loadPrograms: () async => programs,
    )..loading = false;
    addTearDown(controller.dispose);
    for (final id in schedules.keys.where(
      (id) => id != 'strength-barbell-basics-3d',
    )) {
      final program = programs.singleWhere((p) => p.id == id);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildConsoleTheme(),
          home: ProgramSetupScreen(
            controller: controller,
            program: program,
            now: () => DateTime(2026, 9, 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('최근 기록 입력'), findsNothing);
      for (final day in schedules[id]!) {
        await tester.tap(
          find.widgetWithText(
            FilterChip,
            const ['월', '화', '수', '목', '금', '토', '일'][day - 1],
          ),
        );
      }
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '장비 최소 증량 단위 (kg)',
        ),
        '2.5',
      );
      await tester.ensureVisible(find.text('루틴 시작하기'));
      await tester.tap(find.text('루틴 시작하기'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanReviewScreen), findsOneWidget);
      final review = tester.widget<PlanReviewScreen>(
        find.byType(PlanReviewScreen),
      );
      expect(review.plan.program.id, id);
      expect(review.records, isEmpty);
      expect(controller.state.activePlan, isNull);
    }
  });
}
