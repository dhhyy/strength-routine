import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/working_max_controller.dart';
import 'package:strength_routine/data/local_working_max_store.dart';
import 'package:strength_routine/domain/e1rm.dart';
import 'package:strength_routine/domain/e1rm_proposals.dart';
import 'package:strength_routine/domain/live_working_max.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/domain/working_max.dart';

import 'training_insights_fixtures.dart';

void main() {
  test('Epley: 100kg×5 ≈ 116.7, 반올림 116.5', () {
    expect(estimateE1rmKg(weightKg: 100, repetitions: 1), 100);
    expect(estimateE1rmKg(weightKg: 100, repetitions: 5), closeTo(116.666, 0.01));
    expect(roundE1rmKg(116.666), 116.5);
  });

  test('12회 초과·RIR 4 초과는 추정 후보에서 제외', () {
    expect(isEligibleE1rmSet(repetitions: 12), isTrue);
    expect(isEligibleE1rmSet(repetitions: 13), isFalse);
    expect(isEligibleE1rmSet(repetitions: 5, rir: 5), isFalse);
    expect(isEligibleE1rmSet(repetitions: 5, rir: 2), isTrue);
  });

  test('계획 기록에서 리프트별 최고 e1RM 제안을 고른다', () {
    final state = insightsState(completedSessions: 1);
    final proposals = buildE1rmProposals(
      state,
      planId: state.activePlan!.id,
      asOf: insightsToday,
    );
    expect(proposals, hasLength(1));
    expect(proposals.single.lift, MainLift.squat);
    // 100kg × 5 → 116.5
    expect(proposals.single.estimatedKg, 116.5);
    expect(proposals.single.shouldOffer(null), isTrue);
    expect(
      proposals.single.shouldOffer(
        WorkingMax(
          lift: MainLift.squat,
          kilograms: 116.5,
          adoptedAt: DateTime.utc(2026, 8, 1),
        ),
      ),
      isFalse,
    );
  });

  test('working max는 별도 JSON으로 저장·복원한다', () async {
    final dir = await Directory.systemTemp.createTemp('wm-');
    final store = LocalWorkingMaxStore(File('${dir.path}/working-max.json'));
    final controller = WorkingMaxController(store: store);
    await controller.initialize();
    expect(controller.state.byLift, isEmpty);
    await controller.adopt(
      lift: MainLift.benchPress,
      weightKg: 80,
      repetitions: 3,
      now: DateTime.utc(2026, 9, 10),
    );
    // 80 * (1 + 3/30) = 88
    expect(controller.state[MainLift.benchPress]!.kilograms, 88);
    final reloaded = WorkingMaxController(store: store);
    await reloaded.initialize();
    expect(reloaded.state[MainLift.benchPress]!.kilograms, 88);
    await dir.delete(recursive: true);
  });
  test('working max 채택은 활성 계획 baseline만 바꾸고 목표 kg는 유지한다', () {
    final state = insightsState(completedSessions: 1);
    final set = state.activePlan!.sessions.first.exercises.first.sets.first;
    final beforeTarget = state.effectiveTargetKg(set);
    final updated = state.replaceActivePlan(
      state.activePlan!.withBaseline(
        LiftBaseline(
          lift: MainLift.squat,
          kilograms: 116.5,
          source: BaselineSource.workingMax,
        ),
      ),
    );
    expect(updated.activePlan!.baselines[MainLift.squat]!.kilograms, 116.5);
    expect(updated.activePlan!.baselines[MainLift.squat]!.source,
        BaselineSource.workingMax);
    expect(updated.effectiveTargetKg(set), beforeTarget);
  });

  test('미래 % 목표는 재필하고 오늘·과거·기록 세트는 보존한다', () {
    final plan = createActivePlan(
      id: 'percent-plan',
      program: TrainingProgram(
        id: 'percent-fixture',
        version: 'test-v1',
        title: '퍼센트 검증',
        trainerName: '테스트',
        description: '합성',
        weeks: 2,
        sessions: [
          for (var week = 1; week <= 2; week++)
            ProgramSession(
              id: 'week-$week',
              week: week,
              dayOrder: 1,
              title: '$week주차',
              exercises: [
                ProgramExercise(
                  id: 'squat',
                  name: '스쿼트',
                  mainLift: MainLift.squat,
                  sets: [
                    ProgramSet(
                      id: 'work',
                      repetitions: 5,
                      rir: 2,
                      load: LoadPrescription.percentOfBaseline(
                        MainLift.squat,
                        80,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
      startDate: DateTime.utc(2026, 8, 3),
      weekdays: [1],
      incrementKg: 2.5,
      baselines: {
        MainLift.squat: LiftBaseline(
          lift: MainLift.squat,
          kilograms: 100,
          source: BaselineSource.userEntered,
        ),
      },
    );
    // 시작 2026-08-03(월) → week1=8/3, week2=8/10. asOf=8/3이면 week2만 미래.
    final week1 = plan.sessions.first.exercises.first.sets.first;
    final week2 = plan.sessions.last.exercises.first.sets.first;
    expect(week1.targetKg, 80);
    expect(week2.targetKg, 80);

    final refilled = plan.refillFuturePercentTargets(
      lift: MainLift.squat,
      baselineKg: 116.5,
      asOf: DateTime.utc(2026, 8, 3),
      blockedSetIds: {week1.id},
    );
    expect(refilled.baselines[MainLift.squat]!.kilograms, 116.5);
    expect(refilled.targetKgBySetId[week1.id], 80);
    // 116.5 * 0.8 = 93.2 → 2.5 단위 반올림 92.5
    expect(refilled.targetKgBySetId[week2.id], 92.5);
  });

  test('live 제안은 작업 세트·의미 있는 증가일 때만', () {
    final actual = SetActual.completed(
      weight: 100,
      unit: WeightUnit.kg,
      repetitions: 5,
      rir: 1,
    );
    final offered = liveWorkingMaxProposal(
      lift: MainLift.squat,
      exerciseName: '스쿼트',
      sessionId: 's1',
      plannedDate: DateTime.utc(2026, 8, 3),
      actual: actual,
      current: null,
      setKind: ProgramSetKind.work,
    );
    expect(offered?.estimatedKg, 116.5);

    expect(
      liveWorkingMaxProposal(
        lift: MainLift.squat,
        exerciseName: '스쿼트',
        sessionId: 's1',
        plannedDate: DateTime.utc(2026, 8, 3),
        actual: actual,
        current: WorkingMax(
          lift: MainLift.squat,
          kilograms: 116.5,
          adoptedAt: DateTime.utc(2026, 8, 1),
        ),
        setKind: ProgramSetKind.work,
      ),
      isNull,
    );
    expect(
      liveWorkingMaxProposal(
        lift: MainLift.squat,
        exerciseName: '스쿼트',
        sessionId: 's1',
        plannedDate: DateTime.utc(2026, 8, 3),
        actual: actual,
        current: null,
        setKind: ProgramSetKind.warmup,
      ),
      isNull,
    );
  });
}
