import '../domain/e1rm_proposals.dart';
import '../domain/training_insights.dart';
import '../domain/training_program.dart';
import 'priority.dart';
import 'version.dart';

sealed class EngineOutcome {
  final EngineVersion version;
  final List<FiredRule> fired;
  const EngineOutcome({required this.version, required this.fired});
}

final class EngineSuccess extends EngineOutcome {
  final TrainingProgram? program;
  final ActiveTrainingPlan? plan;
  final TrainingAppState? state;
  final E1rmProposal? workingMaxProposal;
  final List<ExerciseTrend>? trends;
  const EngineSuccess({
    required super.version,
    required super.fired,
    this.program,
    this.plan,
    this.state,
    this.workingMaxProposal,
    this.trends,
  });
}

final class EngineIdle extends EngineOutcome {
  const EngineIdle({required super.version, required super.fired});
}

final class EngineBlocked extends EngineOutcome {
  final String message;
  const EngineBlocked({
    required super.version,
    required super.fired,
    required this.message,
  });
}

final class EngineFailure extends EngineOutcome {
  final String message;
  const EngineFailure({
    required super.version,
    required super.fired,
    required this.message,
  });
}
