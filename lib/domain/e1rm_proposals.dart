import 'e1rm.dart';
import 'recent_lift_record.dart';
import 'training_insights.dart';
import 'training_program.dart';
import 'working_max.dart';

/// 기록에서 뽑은 e1RM 제안. 채택 전까지 working max를 바꾸지 않는다.
final class E1rmProposal {
  final MainLift lift;
  final double estimatedKg;
  final double sourceWeightKg;
  final int sourceRepetitions;
  final double? sourceRir;
  final String exerciseName;
  final String sessionId;
  final DateTime plannedDate;

  const E1rmProposal({
    required this.lift,
    required this.estimatedKg,
    required this.sourceWeightKg,
    required this.sourceRepetitions,
    required this.exerciseName,
    required this.sessionId,
    required this.plannedDate,
    this.sourceRir,
  });

  /// 채택값이 없거나, 추정값이 현재 working max보다 의미 있게 클 때만 제안.
  bool shouldOffer(WorkingMax? current, {double minGainKg = 1.0}) {
    if (current == null) return true;
    return estimatedKg >= current.kilograms + minGainKg;
  }
}

/// 계획 안 mainLift 작업 세트에서 리프트별 최고 e1RM 후보를 고른다.
List<E1rmProposal> buildE1rmProposals(
  TrainingAppState state, {
  required String planId,
  required DateTime asOf,
}) {
  if (!e1rmFeatureFlag) return const [];
  final plans = [
    ...state.planHistory,
    if (state.activePlan != null) state.activePlan!,
  ];
  final found = plans.where((plan) => plan.id == planId);
  if (found.isEmpty) return const [];
  final plan = found.single;
  final best = <MainLift, E1rmProposal>{};

  for (var s = 0; s < plan.sessions.length; s++) {
    final session = plan.sessions[s];
    if (session.date.isAfter(calendarDate(asOf))) continue;
    final authored = plan.program.orderedSessions[s];
    for (var e = 0; e < session.exercises.length; e++) {
      final exercise = authored.exercises[e];
      final lift = exercise.mainLift;
      if (lift == null) continue;
      final planned = session.exercises[e];
      for (final set in planned.sets) {
        if (set.kind != ProgramSetKind.work) continue;
        if (state.setDrafts.containsKey(set.id)) continue;
        final actual = state.setActuals[set.id];
        if (actual?.status != SetActualStatus.completed) continue;
        final reps = actual!.repetitions!;
        if (!isEligibleE1rmSet(repetitions: reps, rir: actual.rir)) continue;
        final weightKg = actualKilograms(actual);
        if (weightKg <= 0) continue;
        final estimated = roundE1rmKg(
          estimateE1rmKg(weightKg: weightKg, repetitions: reps),
        );
        final current = best[lift];
        if (current != null && estimated <= current.estimatedKg) continue;
        best[lift] = E1rmProposal(
          lift: lift,
          estimatedKg: estimated,
          sourceWeightKg: weightKg,
          sourceRepetitions: reps,
          sourceRir: actual.rir,
          exerciseName: exercise.name,
          sessionId: session.id,
          plannedDate: session.date,
        );
      }
    }
  }

  return List.unmodifiable(
    MainLift.values
        .where(best.containsKey)
        .map((lift) => best[lift]!)
        .toList(),
  );
}
