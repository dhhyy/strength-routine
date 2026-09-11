import 'e1rm.dart';
import 'e1rm_proposals.dart';
import 'recent_lift_record.dart';
import 'training_insights.dart';
import 'training_program.dart';
import 'working_max.dart';

/// 방금 완료한 세트로 live working-max 제안을 만들지 결정.
E1rmProposal? liveWorkingMaxProposal({
  required MainLift? lift,
  required String exerciseName,
  required String sessionId,
  required DateTime plannedDate,
  required SetActual actual,
  required WorkingMax? current,
  required ProgramSetKind setKind,
}) {
  if (!e1rmFeatureFlag || lift == null) return null;
  if (setKind != ProgramSetKind.work) return null;
  if (actual.status != SetActualStatus.completed) return null;
  final reps = actual.repetitions;
  final weight = actual.weight;
  if (reps == null || weight == null) return null;
  if (!isEligibleE1rmSet(repetitions: reps, rir: actual.rir)) return null;
  final weightKg = actualKilograms(actual);
  if (weightKg <= 0) return null;
  final estimated = roundE1rmKg(
    estimateE1rmKg(weightKg: weightKg, repetitions: reps),
  );
  final proposal = E1rmProposal(
    lift: lift,
    estimatedKg: estimated,
    sourceWeightKg: weightKg,
    sourceRepetitions: reps,
    sourceRir: actual.rir,
    exerciseName: exerciseName,
    sessionId: sessionId,
    plannedDate: plannedDate,
  );
  return proposal.shouldOffer(current) ? proposal : null;
}

MainLift? mainLiftForExercise(
  ActiveTrainingPlan plan,
  PlannedExercise exercise,
) {
  for (var s = 0; s < plan.sessions.length; s++) {
    final session = plan.sessions[s];
    for (var e = 0; e < session.exercises.length; e++) {
      if (session.exercises[e].id == exercise.id) {
        return plan.program.orderedSessions[s].exercises[e].mainLift;
      }
    }
  }
  return null;
}

/// 채택 시 WM 기준 kg로 baseline + 미래 % 목표를 갱신한다.
ActiveTrainingPlan applyLiveWorkingMax(
  ActiveTrainingPlan plan, {
  required MainLift lift,
  required double estimatedKg,
  required DateTime asOf,
  required Set<String> blockedSetIds,
}) => plan.refillFuturePercentTargets(
  lift: lift,
  baselineKg: roundE1rmKg(estimatedKg),
  asOf: asOf,
  blockedSetIds: blockedSetIds,
);
