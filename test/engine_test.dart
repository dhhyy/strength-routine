import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/engine_stamp.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/routine_match.dart';
import 'package:strength_routine/domain/training_insights.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/engine/engine.dart';

import 'training_insights_fixtures.dart';
import 'training_program_fixtures.dart';

void main() {
  test('같은 StartPlan 입력은 createActivePlan과 같은 계획', () {
    final program = fixtureProgram();
    final baselines = {
      MainLift.squat: LiftBaseline(
        lift: MainLift.squat,
        kilograms: 120,
        source: BaselineSource.userEntered,
      ),
    };
    final direct = createActivePlan(
      id: 'plan-1',
      program: program,
      startDate: DateTime.utc(2026, 9, 9),
      weekdays: [3, 1],
      incrementKg: 2.5,
      baselines: baselines,
    );
    final outcome = strengthEngine.run(
      StartPlanCommand(
        id: 'plan-1',
        program: program,
        startDate: DateTime.utc(2026, 9, 9),
        weekdays: [3, 1],
        incrementKg: 2.5,
        baselines: baselines,
      ),
    );
    expect(outcome, isA<EngineSuccess>());
    expect((outcome as EngineSuccess).plan!.toJson(), direct.toJson());
    expect(outcome.version.id, 'engine-v1');
    expect(outcome.fired.map((r) => r.id), contains('start_plan'));
  });

  test('없는 템플릿 조합은 idle', () {
    final outcome = strengthEngine.run(
      const MatchTemplateCommand(
        goal: RoutineGoal.habit,
        daysPerWeek: 7,
        catalog: [],
      ),
    );
    expect(outcome, isA<EngineIdle>());
    expect(outcome.fired.single.id, 'match_template');
  });

  test('살아 있는 D5는 같은 리프트 working max 제안을 막는다', () {
    final original = insightsState();
    final suggestion = buildTrainingInsights(
      original,
      planId: original.activePlan!.id,
      asOf: insightsToday,
    ).first.suggestion!;
    final applied = original.withLoadAdjustment(
      suggestion,
      asOf: insightsToday,
    );
    final plan = applied.activePlan!;
    final outcome = strengthEngine.run(
      ProposeWorkingMaxCommand(
        plan: plan,
        state: applied,
        lift: MainLift.squat,
        exerciseName: '바벨 백스쿼트',
        sessionId: plan.sessions.first.id,
        plannedDate: plan.sessions.first.date,
        actual: SetActual.completed(
          weight: 100,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 1,
        ),
        current: null,
        setKind: ProgramSetKind.work,
      ),
    );
    expect(outcome, isA<EngineBlocked>());
    expect((outcome as EngineBlocked).fired.single.id, 'conflict_recovery');
  });

  test('새 계획은 engine-v1을 박제하고 옛 JSON은 legacy로 읽는다', () {
    final plan = fixturePlan();
    expect(plan.engineVersion, kEngineStampV1);
    expect(plan.toJson()['engineVersion'], kEngineStampV1);
    final json = Map<String, dynamic>.from(plan.toJson())..remove('engineVersion');
    expect(
      ActiveTrainingPlan.fromJson(json).engineVersion,
      kEngineStampLegacy,
    );
  });

  test('이월은 엔진이 다음 훈련일로 민다', () {
    final plan = fixturePlan();
    final asOf = plan.startDate;
    final first = plan.sessions.first;
    final outcome = strengthEngine.run(
      PostponeSessionCommand(
        state: TrainingAppState(onboarded: true, activePlan: plan),
        sessionId: first.id,
        asOf: asOf,
      ),
    );
    expect(outcome, isA<EngineSuccess>());
    expect(
      (outcome as EngineSuccess).state!.activePlan!.sessions.first.date
          .isAfter(first.date),
      isTrue,
    );
    expect(outcome.fired.map((r) => r.id), contains('postpone_session'));
  });
}
