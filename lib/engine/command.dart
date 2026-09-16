import '../domain/recent_lift_record.dart';
import '../domain/routine_match.dart';
import '../domain/training_program.dart';
import '../domain/working_max.dart';

sealed class EngineCommand {
  const EngineCommand();
}

final class MatchTemplateCommand extends EngineCommand {
  final RoutineGoal goal;
  final int daysPerWeek;
  final Iterable<TrainingProgram> catalog;
  const MatchTemplateCommand({
    required this.goal,
    required this.daysPerWeek,
    required this.catalog,
  });
}

final class StartPlanCommand extends EngineCommand {
  final String id;
  final TrainingProgram program;
  final DateTime startDate;
  final List<int> weekdays;
  final double incrementKg;
  final Map<MainLift, LiftBaseline> baselines;
  final int accessoryDropCount;
  final int? blockWeeks;
  const StartPlanCommand({
    required this.id,
    required this.program,
    required this.startDate,
    required this.weekdays,
    required this.incrementKg,
    this.baselines = const {},
    this.accessoryDropCount = 0,
    this.blockWeeks,
  });
}

final class ProposeWorkingMaxCommand extends EngineCommand {
  final ActiveTrainingPlan plan;
  final TrainingAppState state;
  final MainLift? lift;
  final String exerciseName;
  final String sessionId;
  final DateTime plannedDate;
  final SetActual actual;
  final WorkingMax? current;
  final ProgramSetKind setKind;
  const ProposeWorkingMaxCommand({
    required this.plan,
    required this.state,
    required this.lift,
    required this.exerciseName,
    required this.sessionId,
    required this.plannedDate,
    required this.actual,
    required this.current,
    required this.setKind,
  });
}

final class ApplyWorkingMaxCommand extends EngineCommand {
  final ActiveTrainingPlan plan;
  final MainLift lift;
  final double estimatedKg;
  final DateTime asOf;
  final Set<String> blockedSetIds;
  const ApplyWorkingMaxCommand({
    required this.plan,
    required this.lift,
    required this.estimatedKg,
    required this.asOf,
    required this.blockedSetIds,
  });
}

final class InspectTrendsCommand extends EngineCommand {
  final TrainingAppState state;
  final String planId;
  final DateTime asOf;
  const InspectTrendsCommand({
    required this.state,
    required this.planId,
    required this.asOf,
  });
}

final class ApplyLoadAdjustmentCommand extends EngineCommand {
  final TrainingAppState state;
  final TargetLoadAdjustment adjustment;
  final DateTime asOf;
  const ApplyLoadAdjustmentCommand({
    required this.state,
    required this.adjustment,
    required this.asOf,
  });
}

final class UndoLoadAdjustmentCommand extends EngineCommand {
  final TrainingAppState state;
  final String adjustmentId;
  final DateTime asOf;
  const UndoLoadAdjustmentCommand({
    required this.state,
    required this.adjustmentId,
    required this.asOf,
  });
}
