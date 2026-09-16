import '../domain/live_working_max.dart';
import '../domain/postpone.dart';
import '../domain/recent_lift_record.dart';
import '../domain/recovery_block.dart';
import '../domain/routine_match.dart';
import '../domain/schedule_edit.dart';
import '../domain/training_insights.dart';
import '../domain/training_program.dart';
import 'command.dart';
import 'outcome.dart';
import 'priority.dart';
import 'version.dart';

export 'command.dart';
export 'outcome.dart';
export 'priority.dart';
export 'version.dart';

const strengthEngine = StrengthEngine();

TrainingAppState requireEngineState(EngineOutcome outcome) {
  if (outcome is EngineSuccess && outcome.state != null) return outcome.state!;
  if (outcome is EngineFailure) throw FormatException(outcome.message);
  throw const FormatException('적용하지 못했어요.');
}

/// 화면이 부르는 유일한 훈련 판단 입구. Flutter를 import하지 않는다.
final class StrengthEngine {
  const StrengthEngine();

  EngineOutcome run(EngineCommand command) {
    try {
      return switch (command) {
        MatchTemplateCommand c => _match(c),
        StartPlanCommand c => _start(c),
        ProposeWorkingMaxCommand c => _proposeWorkingMax(c),
        ApplyWorkingMaxCommand c => _applyWorkingMax(c),
        InspectTrendsCommand c => _inspect(c),
        ApplyLoadAdjustmentCommand c => _applyAdjustment(c),
        UndoLoadAdjustmentCommand c => _undoAdjustment(c),
        ReviewScheduleCommand c => _reviewSchedule(c),
        PostponeSessionCommand c => _postpone(c),
      };
    } on FormatException catch (error) {
      return EngineFailure(
        version: kEngineVersion,
        fired: const [],
        message: error.message,
      );
    } on ArgumentError catch (error) {
      return EngineFailure(
        version: kEngineVersion,
        fired: const [],
        message: error.message ?? error.toString(),
      );
    }
  }

  EngineOutcome _match(MatchTemplateCommand command) {
    final program = matchProgram(
      goal: command.goal,
      daysPerWeek: command.daysPerWeek,
      programs: command.catalog,
    );
    const fired = [
      FiredRule(
        id: 'match_template',
        reason: '목표와 주당 일수에 맞는 코치 템플릿만 고른다.',
        priority: EnginePriority.volume,
      ),
    ];
    if (program == null) {
      return EngineIdle(version: kEngineVersion, fired: fired);
    }
    return EngineSuccess(
      version: kEngineVersion,
      fired: fired,
      program: program,
    );
  }

  EngineOutcome _start(StartPlanCommand command) {
    final fired = <FiredRule>[];
    var program = command.program;
    final weeks = command.blockWeeks;
    if (weeks != null) {
      program = takeFirstWeeks(program, weeks);
      fired.add(
        const FiredRule(
          id: 'take_weeks',
          reason: '선택한 앞 주 수만 계획에 넣는다.',
          priority: EnginePriority.volume,
        ),
      );
    }
    if (command.accessoryDropCount > 0) {
      program = applyAccessorySetCap(
        program,
        dropCount: command.accessoryDropCount,
      );
      fired.add(
        const FiredRule(
          id: 'accessory_cap',
          reason: '회복을 위해 보조 필수 세트를 줄인다.',
          priority: EnginePriority.recovery,
        ),
      );
    }
    fired.add(
      const FiredRule(
        id: 'start_plan',
        reason: '원작 구성은 유지하고 시작일·요일·기준 중량만 맞춘다.',
        priority: EnginePriority.volume,
      ),
    );
    final plan = createActivePlan(
      id: command.id,
      program: program,
      startDate: command.startDate,
      weekdays: command.weekdays,
      incrementKg: command.incrementKg,
      baselines: command.baselines,
    );
    return EngineSuccess(version: kEngineVersion, fired: fired, plan: plan);
  }

  EngineOutcome _proposeWorkingMax(ProposeWorkingMaxCommand command) {
    if (_hasActiveDeloadForLift(command.plan, command.state, command.lift)) {
      return const EngineBlocked(
        version: kEngineVersion,
        fired: [
          FiredRule(
            id: 'conflict_recovery',
            reason: '같은 리프트에 D5 감량이 살아 있어 working max 제안을 막는다.',
            priority: EnginePriority.recovery,
          ),
        ],
        message: '회복 감량이 적용 중이에요.',
      );
    }
    final proposal = liveWorkingMaxProposal(
      lift: command.lift,
      exerciseName: command.exerciseName,
      sessionId: command.sessionId,
      plannedDate: command.plannedDate,
      actual: command.actual,
      current: command.current,
      setKind: command.setKind,
    );
    const fired = [
      FiredRule(
        id: 'live_working_max',
        reason: '작업 세트 e1RM이 현재 working max보다 크면 제안한다.',
        priority: EnginePriority.intensity,
      ),
    ];
    if (proposal == null) {
      return const EngineIdle(version: kEngineVersion, fired: fired);
    }
    return EngineSuccess(
      version: kEngineVersion,
      fired: fired,
      workingMaxProposal: proposal,
    );
  }

  EngineOutcome _applyWorkingMax(ApplyWorkingMaxCommand command) {
    final plan = applyLiveWorkingMax(
      command.plan,
      lift: command.lift,
      estimatedKg: command.estimatedKg,
      asOf: command.asOf,
      blockedSetIds: command.blockedSetIds,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'apply_working_max',
          reason: '수락한 추정으로 미래 비율 목표만 갱신한다.',
          priority: EnginePriority.intensity,
        ),
      ],
      plan: plan,
    );
  }

  EngineOutcome _inspect(InspectTrendsCommand command) {
    final trends = buildTrainingInsights(
      command.state,
      planId: command.planId,
      asOf: command.asOf,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'd5_inspect',
          reason: '계획일순 최근 3회 RIR 차이로 감량 제안을 만든다.',
          priority: EnginePriority.recovery,
        ),
      ],
      trends: trends,
    );
  }

  EngineOutcome _applyAdjustment(ApplyLoadAdjustmentCommand command) {
    final state = command.state.withLoadAdjustment(
      command.adjustment,
      asOf: command.asOf,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'd5_apply',
          reason: '미래 미기록 작업 세트 목표 kg만 감량한다.',
          priority: EnginePriority.recovery,
        ),
      ],
      state: state,
    );
  }

  EngineOutcome _undoAdjustment(UndoLoadAdjustmentCommand command) {
    final state = command.state.undoLoadAdjustment(
      command.adjustmentId,
      asOf: command.asOf,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'd5_undo',
          reason: '아직 보호되지 않은 감량을 되돌린다.',
          priority: EnginePriority.recovery,
        ),
      ],
      state: state,
    );
  }

  EngineOutcome _reviewSchedule(ReviewScheduleCommand command) {
    final state = command.state.withReviewedSchedule(
      command.changes,
      asOf: command.asOf,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'review_schedule',
          reason: '오늘·과거·기록이 있는 세션은 두고 미래 날짜만 옮긴다.',
          priority: EnginePriority.volume,
        ),
      ],
      state: state,
    );
  }

  EngineOutcome _postpone(PostponeSessionCommand command) {
    final state = command.state.withPostponedSession(
      command.sessionId,
      asOf: command.asOf,
    );
    return EngineSuccess(
      version: kEngineVersion,
      fired: const [
        FiredRule(
          id: 'postpone_session',
          reason: '기록 없는 세션을 다음 훈련 요일로 민다.',
          priority: EnginePriority.recovery,
        ),
      ],
      state: state,
    );
  }
}

bool _hasActiveDeloadForLift(
  ActiveTrainingPlan plan,
  TrainingAppState state,
  MainLift? lift,
) {
  if (lift == null) return false;
  return state.loadAdjustments.any((adjustment) {
    if (adjustment.isUndone || adjustment.planId != plan.id) return false;
    return adjustment.afterKg.keys.any((setId) {
      for (final session in plan.sessions) {
        for (final exercise in session.exercises) {
          for (final set in exercise.sets) {
            if (set.id == setId) {
              return mainLiftForExercise(plan, exercise) == lift;
            }
          }
        }
      }
      return false;
    });
  });
}
